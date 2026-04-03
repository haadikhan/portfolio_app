/**
 * In-app notifications + FCM (Admin SDK). Used by broadcastAnnouncement callable.
 */

const crypto = require("crypto");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const { logger } = require("firebase-functions");

const db = () => admin.firestore();

async function assertAdmin(uid) {
  const authUser = await admin.auth().getUser(uid);
  const claimAdmin =
    authUser.customClaims?.admin === true ||
    authUser.customClaims?.role === "admin";
  if (claimAdmin) return;

  const u = await db().collection("users").doc(uid).get();
  const role = (u.data()?.role || "").toLowerCase();
  if (role !== "admin") {
    throw new HttpsError("permission-denied", "Admin only.");
  }
}

/**
 * Best-effort FCM; never throws (logs only). Inbox rows are the source of truth.
 */
async function sendPushToUser(userId, n) {
  let userSnap;
  try {
    userSnap = await db().collection("users").doc(userId).get();
  } catch (e) {
    logger.warn("sendPushToUser_load_failed", { userId, error: String(e) });
    return;
  }
  const raw = userSnap.data()?.fcmTokens;
  const tokens = Array.isArray(raw)
    ? raw.filter((t) => typeof t === "string" && t.length > 20)
    : [];
  if (tokens.length === 0) return;

  const data = {
    type: String(n.type || ""),
    category: String(n.category || ""),
    action: String(n.action || "none"),
    refId: String(n.refId || ""),
    notificationId: String(n.id || ""),
  };

  const chunkSize = 500;
  for (let i = 0; i < tokens.length; i += chunkSize) {
    const slice = tokens.slice(i, i + chunkSize);
    try {
      const res = await admin.messaging().sendEachForMulticast({
        tokens: slice,
        notification: {
          title: n.title,
          body: n.body,
        },
        data,
      });
      if (res.failureCount > 0) {
        res.responses.forEach((r, idx) => {
          if (!r.success) {
            logger.warn("fcm_send_failed", {
              userId,
              err: r.error?.message,
            });
          }
        });
      }
    } catch (e) {
      logger.warn("fcm_multicast_error", { userId, error: String(e) });
    }
  }
}

/**
 * Writes one inbox row under users/{userId}/notifications and best-effort push.
 * @param {string} userId
 * @param {{ title: string, body: string, type?: string, category?: string, action?: string, refId?: string|null, amount?: number|null, currency?: string }} payload
 * @returns {Promise<string>} notification doc id
 */
async function createUserNotification(userId, payload) {
  const id = crypto.randomBytes(16).toString("hex");
  const ref = db()
    .collection("users")
    .doc(userId)
    .collection("notifications")
    .doc(id);
  const doc = {
    title: String(payload.title || "").slice(0, 200),
    body: String(payload.body || "").slice(0, 2000),
    type: String(payload.type || "system"),
    category: String(payload.category || "system"),
    read: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    action: String(payload.action || "none"),
    refId: payload.refId != null ? String(payload.refId) : null,
    amount: payload.amount != null ? Number(payload.amount) : null,
    currency: String(payload.currency || "PKR"),
  };
  await ref.set(doc);
  await sendPushToUser(userId, {
    id,
    title: doc.title,
    body: doc.body,
    type: doc.type,
    category: doc.category,
    action: doc.action,
    refId: doc.refId || "",
  });
  return id;
}

/** Notify every user doc with role "admin" (same inbox model). */
async function notifyAllAdmins(payload) {
  const snap = await db().collection("users").where("role", "==", "admin").get();
  for (const d of snap.docs) {
    try {
      await createUserNotification(d.id, payload);
    } catch (e) {
      logger.warn("notifyAllAdmins_user_failed", { uid: d.id, error: String(e) });
    }
  }
}

// invoker: "public" — Cloud Run must allow unauthenticated HTTP so browsers can
// complete CORS preflight; auth is still enforced via Firebase ID token in the callable body.
exports.broadcastAnnouncement = onCall(
  { region: "us-central1", cors: true, invoker: "public" },
  async (request) => {
  try {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Sign in required.");
    }
    await assertAdmin(request.auth.uid);

    const title = String(request.data?.title || "").trim();
    const body = String(request.data?.body || "").trim();
    if (title.length < 2) {
      throw new HttpsError("invalid-argument", "title required.");
    }
    if (body.length < 2) {
      throw new HttpsError("invalid-argument", "body required.");
    }

    const annId = crypto.randomBytes(16).toString("hex");

    const usersSnap = await db().collection("users").get();
    let written = 0;
    let batch = db().batch();
    let ops = 0;

    for (const userDoc of usersSnap.docs) {
      const uid = userDoc.id;
      const ref = db()
        .collection("users")
        .doc(uid)
        .collection("notifications")
        .doc(annId);
      batch.set(ref, {
        title: title.slice(0, 200),
        body: body.slice(0, 2000),
        type: "announcement",
        category: "announcement",
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        action: "none",
        refId: null,
        amount: null,
        currency: "PKR",
      });
      ops += 1;
      written += 1;
      if (ops >= 450) {
        await batch.commit();
        batch = db().batch();
        ops = 0;
      }
    }
    if (ops > 0) {
      await batch.commit();
    }

    const payload = {
      id: annId,
      title: title.slice(0, 200),
      body: body.slice(0, 2000),
      type: "announcement",
      category: "announcement",
      action: "none",
      refId: "",
    };

    for (const userDoc of usersSnap.docs) {
      try {
        await sendPushToUser(userDoc.id, payload);
      } catch (e) {
        logger.warn("broadcast_push_user_failed", {
          uid: userDoc.id,
          error: String(e),
        });
      }
    }

    return { ok: true, userCount: written };
  } catch (e) {
    logger.error("broadcastAnnouncement_error", {
      message: e?.message,
      stack: e?.stack,
    });
    if (e instanceof HttpsError) throw e;
    throw new HttpsError(
      "internal",
      e?.message || "Broadcast failed. Check Functions logs."
    );
  }
  }
);

exports.createUserNotification = createUserNotification;
exports.notifyAllAdmins = notifyAllAdmins;
