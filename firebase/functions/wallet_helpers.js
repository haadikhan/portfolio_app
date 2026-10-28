const admin = require("firebase-admin");
const { FieldValue } = require("firebase-admin/firestore");
const { logger } = require("firebase-functions");
const {
  moneyMarketFromTransactions,
  inspectMoneyAllocation,
} = require("./moneyMarketFromTransactions");

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
    createdAt: FieldValue.serverTimestamp(),
  });
}

/**
 * Reads settings/five_market_calc allocations.money once per cache object
 * (pass the same `cache` within a Cloud Function invocation / batch).
 * Returns Number(allocations.money) if finite and >= 0, else 5.
 * If allocations do not sum to ~100, still uses allocations.money as-is
 * and logs a warning — no resplit.
 */
async function loadFiveMarketMoneyAllocationPercent(cache) {
  if (cache && cache._loaded === true) {
    return cache.percent;
  }
  let percent = 5;
  try {
    const snap = await db().collection("settings").doc("five_market_calc").get();
    const allocations = snap.exists ? snap.data()?.allocations : undefined;
    const inspected = inspectMoneyAllocation(allocations);
    percent = inspected.percent;
    if (inspected.sumWarning) {
      logger.warn("five_market_allocations_sum_not_100", {
        sum: inspected.sum,
        money: percent,
        allocations: allocations || null,
      });
    }
  } catch (e) {
    logger.warn("loadFiveMarketMoneyAllocationPercent_failed", {
      error: String(e),
    });
    percent = 5;
  }
  if (cache && typeof cache === "object") {
    cache._loaded = true;
    cache.percent = percent;
  }
  return percent;
}

async function recalculateWallet(userId, options = {}) {
  const explicit = options.moneyAllocationPercent;
  const moneyAllocationPercent =
    Number.isFinite(Number(explicit)) && Number(explicit) >= 0
      ? Number(explicit)
      : await loadFiveMarketMoneyAllocationPercent(options.allocCache);

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

  snap.forEach((doc) => {
    const d = doc.data();
    const amt = Number(d.amount) || 0;
    const st = (d.status || "").toLowerCase();
    const ty = (d.type || "").toLowerCase();

    if (ty === "deposit" && st === "approved") {
      totalDeposited += amt;
    } else if (ty === "withdrawal") {
      // Canonical withdrawal lifecycle used across wallet projections:
      // pending  -> reserved only
      // approved -> reserved only (awaiting settlement)
      // completed -> counted as withdrawn (settled)
      if (st === "pending" || st === "approved") {
        reservedAmount += amt;
      }
      if (st === "completed") {
        totalWithdrawn += amt;
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

  // MM cash is deposits×rate + non-MM P/L×rate − full withdrawals.
  // Fees already reduce availableBalance / NAV; they are not deducted again
  // from the MM cash bucket (no existing canonical rule that fees also cut MM).
  const {
    moneyMarketCreditedTotal,
    moneyMarketWithdrawnTotal,
    moneyMarketReserved,
    moneyMarketBalance,
    moneyMarketAvailable,
  } = moneyMarketFromTransactions(snap.docs, { moneyAllocationPercent });

  const availableBalance =
    totalDeposited +
    totalProfit +
    totalAdjustments -
    totalWithdrawn -
    reservedAmount -
    totalFees;

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
        lastRecalculatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
}

module.exports = {
  recalculateWallet,
  appendAudit,
  loadFiveMarketMoneyAllocationPercent,
  FEE_TX_TYPES,
  isFeeType,
};
