"use strict";

const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const logger = require("firebase-functions/logger");
const { recalculateWallet } = require("./wallet_helpers");
const {
  bumpCompanyEarnings,
  getFeeConfig_internal: getFeeConfig,
} = require("./fees");

function db() {
  return admin.firestore();
}

const REGION = "us-central1";

// ── PKT Date Helper (mirrors five_market_daily.js) ─────────────

function getPktDateString(offsetDays = 0) {
  const cur = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Karachi",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(new Date());
  if (!offsetDays) return cur;
  const [y, mo, da] = cur.split("-").map(Number);
  const t = Date.UTC(y, mo - 1, da + offsetDays, 12, 0, 0);
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Karachi",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(new Date(t));
}

// ── Fee Version Resolution ──────────────────────────────────────

async function resolveInvestorFeeVersion(uid, cfg) {
  try {
    const snap = await db().collection("users").doc(uid).get();
    const userVersion = snap.exists
      ? snap.data().feeVersion || null
      : null;
    return userVersion || cfg.defaultFeeVersion || "v1";
  } catch (e) {
    logger.warn("perfFee_resolveVersion_failed", {
      uid,
      error: String(e),
    });
    return "v1";
  }
}

// ── Adjusted Equity from Wallet ─────────────────────────────────

/**
 * Reads wallet and computes:
 *   netDeposits    = totalDeposited - totalWithdrawn
 *   adjustedEquity = availableBalance - netDeposits
 */
async function getAdjustedEquity(uid) {
  try {
    const snap = await db().collection("wallets").doc(uid).get();
    if (!snap.exists) return null;
    const w = snap.data();

    const totalDeposited = Number(w.totalDeposited || 0);
    const totalWithdrawn = Number(w.totalWithdrawn || 0);
    const availableBalance = Number(w.availableBalance || 0);

    const netDeposits = parseFloat(
      (totalDeposited - totalWithdrawn).toFixed(2),
    );
    const adjustedEquity = parseFloat(
      (availableBalance - netDeposits).toFixed(2),
    );

    return { adjustedEquity, netDeposits, availableBalance };
  } catch (e) {
    logger.warn("perfFee_getAdjustedEquity_failed", {
      uid,
      error: String(e),
    });
    return null;
  }
}

// ── Atomic HWM Read-Compare-Write ──────────────────────────────

/**
 * Atomically updates portfolios/{uid}.performanceHwm to newHwm
 * ONLY if newHwm > current value (never decreases).
 */
async function atomicUpdateHwm(uid, newHwm) {
  const portfolioRef = db().collection("portfolios").doc(uid);

  let hwmBefore = 0;
  let hwmAfter = 0;
  let updated = false;

  await db().runTransaction(async (txn) => {
    const snap = await txn.get(portfolioRef);
    hwmBefore = snap.exists
      ? Number(snap.data().performanceHwm) || 0
      : 0;

    if (newHwm > hwmBefore) {
      hwmAfter = parseFloat(newHwm.toFixed(2));
      txn.set(
        portfolioRef,
        {
          performanceHwm: hwmAfter,
          lastHwmUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      updated = true;
    } else {
      hwmAfter = hwmBefore;
    }
  });

  return { hwmBefore, hwmAfter, updated };
}

// ── Core Per-Investor Performance Fee ──────────────────────────

/**
 * Applies daily HWM-based performance fee for one v2 investor.
 * Idempotent via performance_fee_daily/{datePkt}.
 */
async function applyDailyPerformanceFee({
  uid,
  datePkt,
  performanceFeePct,
  now,
}) {
  const dailyRef = db()
    .collection("portfolios")
    .doc(uid)
    .collection("performance_fee_daily")
    .doc(datePkt);

  const existing = await dailyRef.get();
  if (existing.exists) {
    logger.info("perfFee_already_processed", { uid, datePkt });
    return { skipped: true, reason: "already_processed" };
  }

  const portfolioSnap = await db().collection("portfolios").doc(uid).get();
  const currentHwm = portfolioSnap.exists
    ? Number(portfolioSnap.data().performanceHwm) || 0
    : 0;

  const aeData = await getAdjustedEquity(uid);
  if (!aeData) {
    logger.warn("perfFee_no_wallet", { uid, datePkt });
    return { skipped: true, reason: "no_wallet" };
  }

  const { adjustedEquity, netDeposits, availableBalance } = aeData;

  const snapshotBase = {
    date: datePkt,
    adjustedEquity,
    netDeposits,
    availableBalance,
    hwmBefore: currentHwm,
    hwmAfter: currentHwm,
    profit: 0,
    feePct: performanceFeePct,
    feePkr: 0,
    netProfit: 0,
    feeCharged: false,
    walletTxId: null,
    recordedAt: now,
    feeVersion: "v2",
  };

  if (adjustedEquity <= currentHwm) {
    await dailyRef.set({
      ...snapshotBase,
      skippedReason:
        adjustedEquity < currentHwm ? "below_hwm" : "at_hwm",
    });
    logger.info("perfFee_no_profit_above_hwm", {
      uid,
      datePkt,
      adjustedEquity,
      currentHwm,
    });
    return { skipped: true, reason: "no_profit_above_hwm" };
  }

  const profit = parseFloat((adjustedEquity - currentHwm).toFixed(2));
  const fee = parseFloat((profit * performanceFeePct / 100).toFixed(2));
  const netProfit = parseFloat((profit - fee).toFixed(2));
  const newHwm = parseFloat((currentHwm + netProfit).toFixed(2));

  if (fee <= 0) {
    const { hwmAfter } = await atomicUpdateHwm(uid, newHwm);
    await dailyRef.set({
      ...snapshotBase,
      profit,
      netProfit,
      hwmAfter,
      skippedReason: "fee_rounds_to_zero",
    });
    return { skipped: true, reason: "fee_rounds_to_zero" };
  }

  const periodKey = datePkt.slice(0, 7);

  const txRef = db().collection("transactions").doc();
  await txRef.set({
    id: txRef.id,
    userId: uid,
    type: "performance_fee",
    feeKind: "performance",
    amount: fee,
    status: "approved",
    feePct: performanceFeePct,
    feeBaseAmount: profit,
    adjustedEquity,
    hwmBefore: currentHwm,
    hwmAfter: newHwm,
    netDeposits,
    periodKey,
    datePkt,
    silentFee: false,
    feeVersion: "v2",
    createdAt: now,
    updatedAt: now,
    approvedBy: "system_daily_perf_fee",
    notes:
      `Performance fee (${performanceFeePct}%) on `
      + `AE gain PKR ${profit.toFixed(2)} `
      + `above HWM PKR ${currentHwm.toFixed(2)} [v2]`,
  });

  const { hwmBefore, hwmAfter, updated: hwmUpdated } =
    await atomicUpdateHwm(uid, newHwm);

  await dailyRef.set({
    ...snapshotBase,
    profit,
    feePkr: fee,
    fee,
    netProfit,
    hwmAfter,
    hwmUpdated,
    feeCharged: true,
    walletTxId: txRef.id,
  });

  await recalculateWallet(uid);

  await bumpCompanyEarnings(periodKey, {
    frontEndLoad: 0,
    referral: 0,
    management: 0,
    performance: fee,
  });

  logger.info("perfFee_applied", {
    uid,
    datePkt,
    adjustedEquity,
    hwmBefore,
    hwmAfter,
    profit,
    fee,
    netProfit,
  });

  return {
    skipped: false,
    uid,
    profit,
    fee,
    netProfit,
    hwmBefore,
    hwmAfter,
  };
}

// ── Main Scheduled Job ──────────────────────────────────────────

exports.applyDailyPerformanceFeeJob = onSchedule(
  {
    schedule: "10 0 * * *",
    timeZone: "Asia/Karachi",
    region: REGION,
    memory: "512MiB",
    timeoutSeconds: 540,
  },
  async () => {
    const datePkt = getPktDateString(-1);
    logger.info("applyDailyPerformanceFeeJob_start", { datePkt });

    const cfg = await getFeeConfig();
    if (!cfg.isEnabled) {
      logger.info("applyDailyPerformanceFeeJob_fees_disabled");
      return;
    }

    const performanceFeePct = cfg.performanceFeeHwmPct || 15.0;
    const now = admin.firestore.FieldValue.serverTimestamp();

    const walletsSnap = await db().collection("wallets").get();

    const results = { success: 0, skipped: 0, failed: 0 };

    for (const walletDoc of walletsSnap.docs) {
      const uid = walletDoc.id;
      try {
        const feeVersion = await resolveInvestorFeeVersion(uid, cfg);
        if (feeVersion !== "v2") {
          results.skipped++;
          continue;
        }

        const result = await applyDailyPerformanceFee({
          uid,
          datePkt,
          performanceFeePct,
          now,
        });

        if (result.skipped) {
          results.skipped++;
        } else {
          results.success++;
        }
      } catch (e) {
        results.failed++;
        logger.error("applyDailyPerformanceFeeJob_user_failed", {
          uid,
          datePkt,
          error: String(e),
        });
      }
    }

    logger.info("applyDailyPerformanceFeeJob_complete", {
      datePkt,
      results,
    });
  },
);
