"use strict";

const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const logger = require("firebase-functions/logger");
const { recalculateWallet } = require("./wallet_helpers");
const {
  bumpCompanyEarnings,
  writeCompanyFeeLedger,
  getFeeConfig_internal: getFeeConfig,
} = require("./fees");

function db() {
  return admin.firestore();
}

const REGION = "us-central1";

// ── Financial Year Helpers ──────────────────────────────────────

/**
 * Returns yyyy-MM-dd string for current date in Asia/Karachi.
 * Mirrors getPktDateString from five_market_daily.js.
 */
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

/**
 * Returns number of days in the current financial year.
 * Financial year: 1 July → 30 June (Pakistan standard).
 * Leap-year aware.
 */
function daysInCurrentFinancialYear() {
  const pktNow = new Date(
    new Date().toLocaleString("en-US", { timeZone: "Asia/Karachi" }),
  );
  const month = pktNow.getMonth() + 1;
  const year = pktNow.getFullYear();

  const fyStartYear = month >= 7 ? year : year - 1;
  const fyStart = new Date(Date.UTC(fyStartYear, 6, 1));
  const fyEnd = new Date(Date.UTC(fyStartYear + 1, 6, 1));

  return Math.round((fyEnd - fyStart) / (1000 * 60 * 60 * 24));
}

/**
 * Returns the current financial year label e.g. "2025-26".
 */
function currentFinancialYearLabel() {
  const pktNow = new Date(
    new Date().toLocaleString("en-US", { timeZone: "Asia/Karachi" }),
  );
  const month = pktNow.getMonth() + 1;
  const year = pktNow.getFullYear();
  const fyStartYear = month >= 7 ? year : year - 1;
  return `${fyStartYear}-${String(fyStartYear + 1).slice(2)}`;
}

// ── Fee Version Resolution ──────────────────────────────────────

/**
 * Resolves effective fee version for an investor.
 * Reads users/{uid}.feeVersion, falls back to cfg.defaultFeeVersion.
 * Returns "v1" or "v2".
 */
async function resolveInvestorFeeVersion(uid, cfg) {
  try {
    const snap = await db().collection("users").doc(uid).get();
    const userVersion = snap.exists
      ? snap.data().feeVersion || null
      : null;
    return userVersion || cfg.defaultFeeVersion || "v1";
  } catch (e) {
    logger.warn("mgmtFee_resolveVersion_failed", {
      uid,
      error: String(e),
    });
    return "v1";
  }
}

// ── Allocation Base ─────────────────────────────────────────────

/**
 * Gets the investor's allocation base from their wallet.
 * Base = totalDeposited + totalProfit + totalAdjustments
 *        - totalWithdrawn - totalFees
 * Returns 0 if wallet missing or base is negative.
 */
async function getAllocationBase(uid) {
  try {
    const snap = await db().collection("wallets").doc(uid).get();
    if (!snap.exists) return 0;
    const w = snap.data();
    const base =
      (Number(w.totalDeposited) || 0) +
      (Number(w.totalProfit) || 0) +
      (Number(w.totalAdjustments) || 0) -
      (Number(w.totalWithdrawn) || 0) -
      (Number(w.totalFees) || 0);
    return Math.max(0, parseFloat(base.toFixed(2)));
  } catch (e) {
    logger.warn("mgmtFee_getAllocationBase_failed", {
      uid,
      error: String(e),
    });
    return 0;
  }
}

// ── Core Daily Fee Writer ───────────────────────────────────────

/**
 * Applies daily management fee for one v2 investor.
 * Idempotent: skips if management_fee_daily/{date} already exists.
 */
async function applyDailyManagementFee({
  uid,
  datePkt,
  annualRatePct,
  daysInFY,
  fyLabel,
  now,
}) {
  const dailyRef = db()
    .collection("portfolios")
    .doc(uid)
    .collection("management_fee_daily")
    .doc(datePkt);

  const existing = await dailyRef.get();
  if (existing.exists) {
    logger.info("mgmtFee_already_processed", { uid, datePkt });
    return { skipped: true, reason: "already_processed" };
  }

  const basePkr = await getAllocationBase(uid);
  if (basePkr <= 0) {
    logger.info("mgmtFee_zero_base", { uid, datePkt });
    return { skipped: true, reason: "zero_base" };
  }

  const dailyFeePkr = parseFloat(
    (basePkr * annualRatePct / 100 / daysInFY).toFixed(2),
  );

  if (dailyFeePkr <= 0) {
    logger.info("mgmtFee_zero_fee", { uid, datePkt, basePkr });
    return { skipped: true, reason: "zero_fee" };
  }

  const periodKey = datePkt.slice(0, 7);

  const txRef = db().collection("transactions").doc();
  await txRef.set({
    id: txRef.id,
    userId: uid,
    type: "management_fee",
    feeKind: "management",
    amount: dailyFeePkr,
    status: "approved",
    feePct: annualRatePct,
    feeBaseAmount: basePkr,
    periodKey,
    datePkt,
    fyLabel,
    daysInFY,
    silentFee: true,
    feeVersion: "v2",
    createdAt: now,
    updatedAt: now,
    approvedBy: "system_daily_mgmt_fee",
    notes:
      `Daily management fee (${annualRatePct}%/yr ÷ `
      + `${daysInFY} days) on base PKR ${basePkr} `
      + `[FY ${fyLabel}] [v2-silent]`,
  });

  const portfolioSnap = await db().collection("portfolios").doc(uid).get();
  const currentYtd = portfolioSnap.exists
    ? Number(portfolioSnap.data().ytdManagementFee) || 0
    : 0;
  const newYtdTotal = parseFloat((currentYtd + dailyFeePkr).toFixed(2));

  await dailyRef.set({
    date: datePkt,
    basePkr,
    annualRatePct,
    dailyFeePkr,
    daysInFY,
    fyLabel,
    walletTxId: txRef.id,
    ytdTotal: newYtdTotal,
    deductedAt: now,
  });

  await db()
    .collection("portfolios")
    .doc(uid)
    .set(
      {
        ytdManagementFee: admin.firestore.FieldValue.increment(dailyFeePkr),
        lastMgmtFeeAt: now,
      },
      { merge: true },
    );

  await recalculateWallet(uid);

  await bumpCompanyEarnings(periodKey, {
    frontEndLoad: 0,
    referral: 0,
    management: dailyFeePkr,
    performance: 0,
  });

  await writeCompanyFeeLedger({
    investorUid: uid,
    feeType: "management_daily",
    grossFeePkr: dailyFeePkr,
    referralSharePkr: 0,
    periodKey,
    now,
  });

  logger.info("mgmtFee_applied", {
    uid,
    datePkt,
    basePkr,
    dailyFeePkr,
    newYtdTotal,
  });

  return {
    skipped: false,
    uid,
    dailyFeePkr,
    basePkr,
    newYtdTotal,
  };
}

// ── Financial Year Reset ────────────────────────────────────────

exports.resetYtdManagementFee = onSchedule(
  {
    schedule: "1 0 1 7 *",
    timeZone: "Asia/Karachi",
    region: REGION,
    memory: "256MiB",
    timeoutSeconds: 300,
  },
  async () => {
    logger.info("resetYtdManagementFee_start");

    const cfg = await getFeeConfig();
    const portfoliosSnap = await db().collection("portfolios").get();

    let reset = 0;
    let skipped = 0;
    const BATCH_SIZE = 400;
    let batch = db().batch();
    let batchCount = 0;

    for (const doc of portfoliosSnap.docs) {
      const uid = doc.id;
      const feeVersion = await resolveInvestorFeeVersion(uid, cfg);

      if (feeVersion !== "v2") {
        skipped++;
        continue;
      }

      batch.set(doc.ref, { ytdManagementFee: 0 }, { merge: true });
      batchCount++;
      reset++;

      if (batchCount >= BATCH_SIZE) {
        await batch.commit();
        batch = db().batch();
        batchCount = 0;
      }
    }

    if (batchCount > 0) await batch.commit();

    logger.info("resetYtdManagementFee_complete", { reset, skipped });
  },
);

// ── Main Scheduled Job ──────────────────────────────────────────

exports.applyDailyManagementFeeJob = onSchedule(
  {
    schedule: "5 0 * * *",
    timeZone: "Asia/Karachi",
    region: REGION,
    memory: "512MiB",
    timeoutSeconds: 540,
  },
  async () => {
    const datePkt = getPktDateString(-1);
    logger.info("applyDailyManagementFeeJob_start", { datePkt });

    const cfg = await getFeeConfig();
    if (!cfg.isEnabled) {
      logger.info("applyDailyManagementFeeJob_disabled");
      return;
    }

    const annualRatePct = cfg.managementFeeAnnualPct || 1.5;
    const daysInFY = daysInCurrentFinancialYear();
    const fyLabel = currentFinancialYearLabel();
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

        const result = await applyDailyManagementFee({
          uid,
          datePkt,
          annualRatePct,
          daysInFY,
          fyLabel,
          now,
        });

        if (result.skipped) {
          results.skipped++;
        } else {
          results.success++;
        }
      } catch (e) {
        results.failed++;
        logger.error("applyDailyManagementFeeJob_user_failed", {
          uid,
          datePkt,
          error: String(e),
        });
      }
    }

    logger.info("applyDailyManagementFeeJob_complete", {
      datePkt,
      results,
    });
  },
);
