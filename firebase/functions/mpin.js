/**
 * Withdrawal MPIN: 4-digit numeric PIN gating sensitive actions
 * (currently only `createWithdrawalRequest`, but `verifyMpinOrThrow`
 * is reusable for any future sensitive callable).
 *
 * Backwards-compatible: a user without `users/{uid}.mpinHash` has no MPIN
 * and `verifyMpinOrThrow` returns silently. Existing flows are unaffected
 * until the user explicitly opts in via the Profile screen.
 */

const crypto = require("crypto");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const { logger } = require("firebase-functions");

const db = () => admin.firestore();

const PIN_REGEX = /^\d{4}$/;
const PBKDF2_ITERATIONS = 120000;
const PBKDF2_KEY_LEN = 32;
const PBKDF2_DIGEST = "sha256";
const SALT_BYTES = 16;
const MAX_FAILED_ATTEMPTS = 5;
const LOCKOUT_MS = 15 * 60 * 1000;
// Authentication freshness required to bypass `currentPin` (e.g. for
// the "Forgot MPIN" reauth flow). 5 minutes matches Firebase Auth's
// default sensitive-action freshness window.
const REAUTH_FRESHNESS_MS = 5 * 60 * 1000;

function assertValidPin(pin) {
  if (typeof pin !== "string" || !PIN_REGEX.test(pin)) {
    throw new HttpsError("invalid-argument", "MPIN_INVALID_FORMAT");
  }
}

function hashMpin(pin, saltBuf) {
  return crypto.pbkdf2Sync(
    String(pin),
    saltBuf,
    PBKDF2_ITERATIONS,
    PBKDF2_KEY_LEN,
    PBKDF2_DIGEST,
  );
}

function freshAuthToken(authToken) {
  if (!authToken || typeof authToken !== "object") return false;
  const authTimeSec = Number(authToken.auth_time);
  if (!Number.isFinite(authTimeSec)) return false;
  const ageMs = Date.now() - authTimeSec * 1000;
  return ageMs >= 0 && ageMs <= REAUTH_FRESHNESS_MS;
}

/**
 * Throws an HttpsError if the user has an enabled MPIN and the supplied
 * `pin` is missing/wrong/locked. Returns silently when no MPIN is set or
 * the user has disabled the requirement.
 *
 * Side effects: increments `mpinFailedAttempts`; on the 5th wrong attempt
 * sets `mpinLockedUntil` 15 minutes in the future and resets the counter.
 * Resets both fields on a correct PIN.
 */
async function verifyMpinOrThrow(uid, pin) {
  const ref = db().collection("users").doc(uid);
  const snap = await ref.get();
  const u = snap.data() || {};

  if (!u.mpinHash || !u.mpinSalt) return;
  if (u.mpinEnabled !== true) return;

  const lockedUntilMs = u.mpinLockedUntil?.toMillis?.() || 0;
  if (lockedUntilMs > Date.now()) {
    throw new HttpsError("failed-precondition", "MPIN_LOCKED");
  }

  assertValidPin(pin);

  const salt = Buffer.from(u.mpinSalt, "base64");
  const expected = Buffer.from(u.mpinHash, "base64");
  const got = hashMpin(pin, salt);
  const sameLength = expected.length === got.length;
  const ok = sameLength && crypto.timingSafeEqual(expected, got);

  if (ok) {
    if (
      (Number(u.mpinFailedAttempts) || 0) > 0 ||
      u.mpinLockedUntil != null
    ) {
      await ref.update({
        mpinFailedAttempts: 0,
        mpinLockedUntil: admin.firestore.FieldValue.delete(),
      });
    }
    return;
  }

  const attempts = (Number(u.mpinFailedAttempts) || 0) + 1;
  if (attempts >= MAX_FAILED_ATTEMPTS) {
    await ref.update({
      mpinFailedAttempts: 0,
      mpinLockedUntil: admin.firestore.Timestamp.fromMillis(
        Date.now() + LOCKOUT_MS,
      ),
    });
    throw new HttpsError("permission-denied", "MPIN_LOCKED");
  }
  await ref.update({ mpinFailedAttempts: attempts });
  throw new HttpsError("permission-denied", "MPIN_WRONG");
}

async function readUserOrEmpty(uid) {
  const snap = await db().collection("users").doc(uid).get();
  return snap.data() || {};
}

/**
 * Set or change the MPIN.
 *  - If user already has an MPIN: requires either `currentPin` matching, OR
 *    a recent Firebase Auth re-authentication (auth_time within 5 minutes).
 *  - If user has no MPIN: sets the new one and turns the requirement on.
 */
exports.setMpin = onCall({ region: "us-central1" }, async (request) => {
  const auth = request.auth;
  if (!auth?.uid) throw new HttpsError("unauthenticated", "Sign in required.");
  const uid = auth.uid;

  const newPin = request.data?.newPin;
  const currentPin = request.data?.currentPin;
  assertValidPin(newPin);

  const u = await readUserOrEmpty(uid);
  const hasExisting = !!u.mpinHash && !!u.mpinSalt;

  if (hasExisting) {
    const isFresh = freshAuthToken(auth.token);
    if (!isFresh) {
      // Must verify currentPin. We reuse verifyMpinOrThrow's lockout
      // semantics, but only when MPIN is *enabled*. If a user disabled
      // their MPIN they can still change it by providing currentPin —
      // we run the comparison directly so disabled MPINs still validate.
      if (u.mpinEnabled === true) {
        await verifyMpinOrThrow(uid, currentPin);
      } else {
        if (typeof currentPin !== "string" || !PIN_REGEX.test(currentPin)) {
          throw new HttpsError("invalid-argument", "MPIN_NEEDS_CURRENT");
        }
        const salt = Buffer.from(u.mpinSalt, "base64");
        const expected = Buffer.from(u.mpinHash, "base64");
        const got = hashMpin(currentPin, salt);
        const ok =
          expected.length === got.length &&
          crypto.timingSafeEqual(expected, got);
        if (!ok) throw new HttpsError("permission-denied", "MPIN_WRONG");
      }
    }
  }

  const salt = crypto.randomBytes(SALT_BYTES);
  const hash = hashMpin(newPin, salt);
  await db()
    .collection("users")
    .doc(uid)
    .set(
      {
        mpinHash: hash.toString("base64"),
        mpinSalt: salt.toString("base64"),
        mpinEnabled: true,
        mpinFailedAttempts: 0,
        mpinLockedUntil: admin.firestore.FieldValue.delete(),
        mpinUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

  logger.info("mpin_set", { uid, hadPrevious: hasExisting });
  return { ok: true };
});

/** Remove the MPIN entirely; requires correct currentPin. */
exports.clearMpin = onCall({ region: "us-central1" }, async (request) => {
  const auth = request.auth;
  if (!auth?.uid) throw new HttpsError("unauthenticated", "Sign in required.");
  const uid = auth.uid;
  const currentPin = request.data?.currentPin;

  const u = await readUserOrEmpty(uid);
  if (!u.mpinHash || !u.mpinSalt) {
    return { ok: true, alreadyCleared: true };
  }

  // Always require currentPin proof; even disabled MPINs need it to clear.
  assertValidPin(currentPin);
  const salt = Buffer.from(u.mpinSalt, "base64");
  const expected = Buffer.from(u.mpinHash, "base64");
  const got = hashMpin(currentPin, salt);
  const ok =
    expected.length === got.length && crypto.timingSafeEqual(expected, got);
  if (!ok) throw new HttpsError("permission-denied", "MPIN_WRONG");

  await db()
    .collection("users")
    .doc(uid)
    .set(
      {
        mpinHash: admin.firestore.FieldValue.delete(),
        mpinSalt: admin.firestore.FieldValue.delete(),
        mpinEnabled: false,
        mpinFailedAttempts: 0,
        mpinLockedUntil: admin.firestore.FieldValue.delete(),
        mpinUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

  logger.info("mpin_cleared", { uid });
  return { ok: true };
});

/** Toggle the "require MPIN for withdrawals" switch; requires currentPin. */
exports.setMpinEnabled = onCall(
  { region: "us-central1" },
  async (request) => {
    const auth = request.auth;
    if (!auth?.uid) throw new HttpsError("unauthenticated", "Sign in required.");
    const uid = auth.uid;
    const enabled = request.data?.enabled === true;
    const currentPin = request.data?.currentPin;

    const u = await readUserOrEmpty(uid);
    if (!u.mpinHash || !u.mpinSalt) {
      throw new HttpsError("failed-precondition", "MPIN_NOT_SET");
    }

    assertValidPin(currentPin);
    const salt = Buffer.from(u.mpinSalt, "base64");
    const expected = Buffer.from(u.mpinHash, "base64");
    const got = hashMpin(currentPin, salt);
    const ok =
      expected.length === got.length && crypto.timingSafeEqual(expected, got);
    if (!ok) throw new HttpsError("permission-denied", "MPIN_WRONG");

    await db()
      .collection("users")
      .doc(uid)
      .set(
        {
          mpinEnabled: enabled,
          mpinUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

    logger.info("mpin_enabled_toggled", { uid, enabled });
    return { ok: true, enabled };
  },
);

/**
 * Read-only status echo. The user doc itself is also readable by the
 * client, but this callable shapes the public view (no salt/hash leak).
 */
exports.getMpinStatus = onCall({ region: "us-central1" }, async (request) => {
  const auth = request.auth;
  if (!auth?.uid) throw new HttpsError("unauthenticated", "Sign in required.");
  const u = await readUserOrEmpty(auth.uid);
  const lockedUntilMs = u.mpinLockedUntil?.toMillis?.() || 0;
  return {
    hasMpin: !!u.mpinHash && !!u.mpinSalt,
    enabled: u.mpinEnabled === true,
    lockedUntil: lockedUntilMs > Date.now() ? lockedUntilMs : null,
  };
});

module.exports.verifyMpinOrThrow = verifyMpinOrThrow;
module.exports.hashMpin = hashMpin;
module.exports.PIN_REGEX = PIN_REGEX;
