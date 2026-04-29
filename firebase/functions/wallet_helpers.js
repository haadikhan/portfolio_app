const admin = require("firebase-admin");

const db = () => admin.firestore();

/** Canonical fee transaction `type` values. Each is a positive amount that
 * SUBTRACTS from the investor's wallet balance (mirrors withdrawals).
 */
const FEE_TX_TYPES = Object.freeze([
  "front_end_load_fee",
  "referral_fee",
  "management_fee",
  "performance_fee",
]);

function isFeeType(ty) {
  return FEE_TX_TYPES.includes(String(ty || "").toLowerCase());
}

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
  let totalFees = 0;
  let frontEndLoadFees = 0;
  let referralFees = 0;
  let managementFees = 0;
  let performanceFees = 0;
  let reservedAmount = 0;
  let moneyMarketCreditedTotal = 0;
  let moneyMarketWithdrawnTotal = 0;
  let moneyMarketReserved = 0;

  snap.forEach((doc) => {
    const d = doc.data();
    const amt = Number(d.amount) || 0;
    const st = (d.status || "").toLowerCase();
    const ty = (d.type || "").toLowerCase();

    if (ty === "deposit" && st === "approved") {
      totalDeposited += amt;
      moneyMarketCreditedTotal += amt * 0.05;
    } else if (ty === "withdrawal") {
      // Canonical withdrawal lifecycle used across wallet projections:
      // pending  -> reserved only
      // approved -> reserved only (awaiting settlement)
      // completed -> counted as withdrawn (settled)
      if (st === "pending" || st === "approved") {
        reservedAmount += amt;
        moneyMarketReserved += amt;
      }
      if (st === "completed") {
        totalWithdrawn += amt;
        moneyMarketWithdrawnTotal += amt;
      }
    } else if (
      (ty === "profit" || ty === "profit_entry") &&
      (st === "approved" || st === "completed")
    ) {
      totalProfit += amt;
    } else if (ty === "adjustment" && (st === "approved" || st === "completed")) {
      totalAdjustments += amt;
    } else if (
      isFeeType(ty) &&
      (st === "approved" || st === "completed")
    ) {
      const positive = Math.abs(amt);
      totalFees += positive;
      if (ty === "front_end_load_fee") frontEndLoadFees += positive;
      else if (ty === "referral_fee") referralFees += positive;
      else if (ty === "management_fee") managementFees += positive;
      else if (ty === "performance_fee") performanceFees += positive;
    }
  });

  const availableBalance =
    totalDeposited +
    totalProfit +
    totalAdjustments -
    totalWithdrawn -
    reservedAmount -
    totalFees;
  const moneyMarketBalance = Math.max(
    0,
    moneyMarketCreditedTotal - moneyMarketWithdrawnTotal,
  );
  const moneyMarketAvailable = Math.max(0, moneyMarketBalance - moneyMarketReserved);

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
        totalFees,
        frontEndLoadFees,
        referralFees,
        managementFees,
        performanceFees,
        reservedAmount,
        moneyMarketCreditedTotal,
        moneyMarketWithdrawnTotal,
        moneyMarketReserved,
        moneyMarketBalance,
        moneyMarketAvailable,
        availableBalance,
        currentBalance: availableBalance,
        lastRecalculatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
}

module.exports = {
  recalculateWallet,
  appendAudit,
  FEE_TX_TYPES,
  isFeeType,
};
