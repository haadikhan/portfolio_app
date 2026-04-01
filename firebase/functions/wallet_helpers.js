const admin = require("firebase-admin");

const db = () => admin.firestore();

async function appendAudit(actorId, actorRole, action, entityType, entityId, before, after) {
  await db().collection("audit_logs").add({
    actorId,
    actorRole,
    action,
    entityType,
    entityId,
    before: before || null,
    after: after || null,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

async function recalculateWallet(userId) {
  const snap = await db().collection("transactions").where("userId", "==", userId).get();
  let totalDeposited = 0;
  let totalWithdrawn = 0;
  let totalProfit = 0;
  let totalAdjustments = 0;
  let reservedAmount = 0;

  snap.forEach((doc) => {
    const d = doc.data();
    const amt = Number(d.amount) || 0;
    const st = (d.status || "").toLowerCase();
    const ty = (d.type || "").toLowerCase();

    if (ty === "deposit" && st === "approved") {
      totalDeposited += amt;
    } else if (ty === "withdrawal") {
      if (st === "pending" || st === "approved") {
        reservedAmount += amt;
      }
      if (st === "completed") {
        totalWithdrawn += amt;
      }
    } else if (ty === "profit" && (st === "approved" || st === "completed")) {
      totalProfit += amt;
    } else if (ty === "adjustment" && (st === "approved" || st === "completed")) {
      totalAdjustments += amt;
    }
  });

  const availableBalance =
    totalDeposited + totalProfit + totalAdjustments - totalWithdrawn - reservedAmount;

  await db()
    .collection("wallets")
    .doc(userId)
    .set(
      {
        userId,
        totalDeposited,
        totalWithdrawn,
        totalProfit,
        totalAdjustments,
        reservedAmount,
        availableBalance,
        currentBalance: availableBalance,
        lastRecalculatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
}

module.exports = { recalculateWallet, appendAudit };
