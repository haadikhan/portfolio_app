const admin = require("firebase-admin");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { requireMpinVerifiedOrThrow, verifyMpinOrThrow } = require("./mpin");

const db = () => admin.firestore();

function requireAuth(request) {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  return uid;
}

function cleanString(v, max = 200) {
  const s = String(v || "").trim();
  if (!s) return "";
  return s.length > max ? s.slice(0, max) : s;
}

function requireDeviceHash(data) {
  const deviceHash = cleanString(data?.deviceHash, 128);
  if (!/^[a-f0-9]{64}$/i.test(deviceHash)) {
    throw new HttpsError("invalid-argument", "Valid deviceHash is required.");
  }
  return deviceHash.toLowerCase();
}

function trustedDeviceRef(uid, deviceHash) {
  return db()
    .collection("users")
    .doc(uid)
    .collection("trustedDevices")
    .doc(deviceHash);
}

async function extractLinkedPhone(uid) {
  const authUser = await admin.auth().getUser(uid);
  const phoneProvider = (authUser.providerData || []).find(
    (p) => p.providerId === "phone",
  );
  const linkedPhone = cleanString(phoneProvider?.phoneNumber, 32);
  if (!linkedPhone) {
    throw new HttpsError(
      "failed-precondition",
      "No verified phone provider is linked for this session.",
    );
  }
  return linkedPhone;
}

/**
 * Equality for Firebase Auth vs Firestore `security.verifiedPhone`:
 * trims and compares digit-only strings so "+92 300 1234567" matches "+923001234567".
 */
function phonesMatchForTrust(linked, expected) {
  const digitsOnly = (s) => String(s || "").replace(/\D/g, "");
  const dl = digitsOnly(linked);
  const de = digitsOnly(expected);
  if (!dl || !de) return false;
  return dl === de;
}

async function upsertTrustedDevice(uid, data) {
  const deviceHash = requireDeviceHash(data);
  const now = admin.firestore.FieldValue.serverTimestamp();
  const payload = {
    deviceHash,
    deviceName: cleanString(data?.deviceName, 120),
    platform: cleanString(data?.platform, 20),
    appVersion: cleanString(data?.appVersion, 40),
    lastSeenAt: now,
    revoked: false,
    revokedAt: admin.firestore.FieldValue.delete(),
  };
  const ref = trustedDeviceRef(uid, deviceHash);
  const snap = await ref.get();
  if (!snap.exists) payload.firstSeenAt = now;
  await ref.set(payload, { merge: true });
  return deviceHash;
}

exports.verifyPhoneAndTrustCurrentDevice = onCall(
  { region: "us-central1" },
  async (request) => {
    const uid = requireAuth(request);
    const userSnap = await db().collection("users").doc(uid).get();
    const existingPhone = cleanString(
      userSnap.data()?.security?.verifiedPhone,
      32,
    );
    const linkedPhone = await extractLinkedPhone(uid);
    if (
      existingPhone &&
      !phonesMatchForTrust(linkedPhone, existingPhone)
    ) {
      throw new HttpsError("failed-precondition", "USE_CHANGE_PHONE_FLOW");
    }
    const deviceHash = await upsertTrustedDevice(uid, request.data || {});

    await db()
      .collection("users")
      .doc(uid)
      .set(
        {
          security: {
            verifiedPhone: linkedPhone,
            verifiedPhoneAt: admin.firestore.FieldValue.serverTimestamp(),
          },
        },
        { merge: true },
      );

    return { ok: true, deviceHash };
  },
);

exports.markDeviceTrusted = onCall(
  { region: "us-central1" },
  async (request) => {
    const uid = requireAuth(request);
    const userSnap = await db().collection("users").doc(uid).get();
    const expectedPhone = cleanString(userSnap.data()?.security?.verifiedPhone, 32);
    if (!expectedPhone) {
      throw new HttpsError(
        "failed-precondition",
        "No verified phone is configured for this user.",
      );
    }
    const linkedPhone = await extractLinkedPhone(uid);
    if (!phonesMatchForTrust(linkedPhone, expectedPhone)) {
      throw new HttpsError(
        "permission-denied",
        "Linked phone does not match the verified phone.",
      );
    }
    const deviceHash = await upsertTrustedDevice(uid, request.data || {});
    return { ok: true, deviceHash };
  },
);

exports.removeTrustedDevice = onCall(
  { region: "us-central1" },
  async (request) => {
    const uid = requireAuth(request);
    const data = request.data || {};
    const deviceHash = requireDeviceHash(data);
    const mpin = data.mpin;

    const userSnap = await db().collection("users").doc(uid).get();
    const userData = userSnap.data() || {};
    const hasMpin =
      typeof userData.mpinHash === "string" &&
      userData.mpinHash.length > 0 &&
      typeof userData.mpinSalt === "string" &&
      userData.mpinSalt.length > 0 &&
      userData.mpinEnabled === true;

    if (hasMpin) {
      if (typeof mpin !== "string" || !/^\d{4}$/.test(mpin)) {
        throw new HttpsError("invalid-argument", "MPIN_REQUIRED");
      }
      await verifyMpinOrThrow(uid, mpin);
    }

    const ref = trustedDeviceRef(uid, deviceHash);
    const snap = await ref.get();
    if (!snap.exists) {
      throw new HttpsError("not-found", "Device not found.");
    }

    await ref.update({
      revoked: true,
      revokedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { ok: true };
  },
);

exports.changeVerifiedPhone = onCall(
  { region: "us-central1" },
  async (request) => {
    const uid = requireAuth(request);
    const data = request.data || {};
    await requireMpinVerifiedOrThrow(uid, data.mpin);

    const userSnap = await db().collection("users").doc(uid).get();
    const existingPhone = cleanString(
      userSnap.data()?.security?.verifiedPhone,
      32,
    );
    if (!existingPhone) {
      throw new HttpsError("failed-precondition", "NO_VERIFIED_PHONE");
    }

    const linkedPhone = await extractLinkedPhone(uid);
    const trustedRef = db().collection("users").doc(uid).collection("trustedDevices");
    const trustedSnap = await trustedRef.get();
    let batch = db().batch();
    let ops = 0;
    for (const d of trustedSnap.docs) {
      batch.delete(d.ref);
      ops += 1;
      if (ops >= 400) {
        await batch.commit();
        batch = db().batch();
        ops = 0;
      }
    }
    if (ops > 0) await batch.commit();

    const deviceHash = await upsertTrustedDevice(uid, data);
    await db()
      .collection("users")
      .doc(uid)
      .set(
        {
          security: {
            verifiedPhone: linkedPhone,
            verifiedPhoneAt: admin.firestore.FieldValue.serverTimestamp(),
          },
        },
        { merge: true },
      );
    return { ok: true, deviceHash };
  },
);
