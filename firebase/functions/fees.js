/**
 * Fee Management module — server-side source of truth.
 *
 * Configurable fees:
 *   - frontEndLoadPct   (one-time, every approved deposit OR first-deposit-only)
 *   - referralFeePct    (one-time, ONLY on first approved deposit per investor)
 *   - managementFeePctAnnual (1%/12 of principal posted monthly at month-end)
 *   - performanceFeePct (% of monthly gross profit; deducted before crediting profit)
 *
 * All deductions are written as `transactions/*` rows with a fee `type` so the
 * existing wallet recalculator (see wallet_helpers.js) treats them as
 * negative-balance contributors. Company-side income is mirrored into the
 * denormalized `company_earnings/{periodKey}` doc for the Earnings dashboard.
 */

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const { logger } = require("firebase-functions");
const { recalculateWallet, appendAudit } = require("./wallet_helpers");

const db = () => admin.firestore();

const FEE_CONFIG_DOC = "settings/fee_config";

const DEFAULT_FEE_CONFIG = Object.freeze({
  isEnabled: false,
  managementFeePctAnnual: 0,
  performanceFeePct: 0,
  referralFeePct: 0,
  frontEndLoadPct: 0,
  frontEndLoadFirstDepositOnly: false,
});

function clampPct(v) {
  const n = Number(v);
  if (!Number.isFinite(n)) return 0;
  return Math.max(0, Math.min(100, n));
}

function ymKey(d) {
  const y = d.getUTCFullYear();
  const m = String(d.getUTCMonth() + 1).padStart(2, "0");
  return `${y}-${m}`;
}

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

async function getFeeConfig() {
  const snap = await db().doc(FEE_CONFIG_DOC).get();
  const data = snap.data() || {};
  return {
    isEnabled: data.isEnabled === true,
    managementFeePctAnnual: clampPct(data.managementFeePctAnnual),
    performanceFeePct: clampPct(data.performanceFeePct),
    referralFeePct: clampPct(data.referralFeePct),
    frontEndLoadPct: clampPct(data.frontEndLoadPct),
    frontEndLoadFirstDepositOnly: data.frontEndLoadFirstDepositOnly === true,
    exists: snap.exists,
    defaultFeeVersion: data.defaultFeeVersion || "v1",
    frontEndLoadAllDeposits: data.frontEndLoadAllDeposits === true,
    managementFeeAnnualPct: clampPct(data.managementFeeAnnualPct ?? 1.5),
    performanceFeeHwmPct: clampPct(data.performanceFeeHwmPct ?? 15.0),
    financialYearStartMonth: Number(data.financialYearStartMonth ?? 7),
    referralEnabled: data.referralEnabled !== false,
  };
}

const REGION = "us-central1";

/**
 * Increment company_earnings/{periodKey} totals atomically.
 * @param {string} periodKey YYYY-MM
 * @param {{ frontEndLoad?: number, referral?: number, management?: number, performance?: number }} delta
 */
async function bumpCompanyEarnings(periodKey, delta) {
  const ref = db().collection("company_earnings").doc(periodKey);
  const inc = admin.firestore.FieldValue.increment;
  const front = Number(delta.frontEndLoad || 0);
  const ref2 = Number(delta.referral || 0);
  const mgmt = Number(delta.management || 0);
  const perf = Number(delta.performance || 0);
  const total = front + ref2 + mgmt + perf;
  if (total <= 0) return;
  await ref.set(
    {
      periodKey,
      frontEndLoadTotal: inc(front),
      referralTotal: inc(ref2),
      managementTotal: inc(mgmt),
      performanceTotal: inc(perf),
      total: inc(total),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
}

/**
 * Returns true if the user has no other approved deposit (excluding the
 * deposit txId currently being approved).
 */
async function isFirstApprovedDeposit(uid, currentTxId) {
  const snap = await db()
    .collection("transactions")
    .where("userId", "==", uid)
    .where("type", "==", "deposit")
    .where("status", "==", "approved")
    .get();
  for (const d of snap.docs) {
    if (d.id !== currentTxId) return false;
  }
  return true;
}

/**
 * Sum of all fully-realized "principal" the investor has invested:
 *   approved deposits MINUS one-time fees (front_end_load, referral)
 *   MINUS settled withdrawals.
 * Used as the base for the monthly management fee.
 */
async function getInvestorPrincipalBase(uid) {
  const snap = await db()
    .collection("transactions")
    .where("userId", "==", uid)
    .get();
  let deposits = 0;
  let oneTimeFees = 0;
  let withdrawn = 0;
  snap.forEach((doc) => {
    const d = doc.data();
    const amt = Math.abs(Number(d.amount) || 0);
    const st = (d.status || "").toLowerCase();
    const ty = (d.type || "").toLowerCase();
    if (ty === "deposit" && st === "approved") deposits += amt;
    else if (ty === "withdrawal" && st === "completed") withdrawn += amt;
    else if (
      (ty === "front_end_load_fee" || ty === "referral_fee") &&
      (st === "approved" || st === "completed")
    ) {
      oneTimeFees += amt;
    }
  });
  return Math.max(0, deposits - oneTimeFees - withdrawn);
}

/**
 * Resolves effective fee version for an investor.
 * Checks users/{uid}.feeVersion first, falls back to
 * fee_config.defaultFeeVersion, then "v1" as final default.
 * Cached cfg object passed in to avoid extra Firestore read.
 */
async function resolveInvestorFeeVersion(uid, cfg) {
  try {
    const userSnap = await db().collection("users").doc(uid).get();
    const userVersion = userSnap.exists
      ? userSnap.data().feeVersion || null
      : null;
    return userVersion || cfg.defaultFeeVersion || "v1";
  } catch (e) {
    logger.warn("resolveInvestorFeeVersion_failed", {
      uid,
      error: String(e),
    });
    return cfg.defaultFeeVersion || "v1";
  }
}

/**
 * Reads referrals/{investorUid} document.
 * Returns the referral data object or null if no referral assigned.
 */
async function getOrCreateReferralRecord(investorUid) {
  try {
    const snap = await db().collection("referrals").doc(investorUid).get();
    if (!snap.exists) return null;
    return { id: snap.id, ...snap.data() };
  } catch (e) {
    logger.warn("getOrCreateReferralRecord_failed", {
      investorUid,
      error: String(e),
    });
    return null;
  }
}

/**
 * Calculates referral commission using halving sequence.
 * depositCount = number of deposits already processed (0-based).
 *
 * Sequence (as % of frontEndLoadAmount):
 *   depositCount 0 → 50%  of frontEndLoad
 *   depositCount 1 → 25%  of frontEndLoad
 *   depositCount 2 → 12.5% of frontEndLoad
 *   depositCount n → 50% / 2^n of frontEndLoad
 *
 * Minimum commission: 0.01 PKR (stops when rounds to 0)
 */
function computeReferralCommission(frontEndLoadAmount, depositCount) {
  if (frontEndLoadAmount <= 0) return 0;
  const pct = 0.5 / Math.pow(2, depositCount);
  const commission = +(frontEndLoadAmount * pct).toFixed(2);
  return commission > 0 ? commission : 0;
}

/**
 * Writes one entry to company_fee_ledger collection.
 * Used for admin company earnings visibility.
 * Never throws — fee ledger write failure must not block
 * the deposit approval flow.
 */
async function writeCompanyFeeLedger({
  investorUid,
  feeType,
  grossFeePkr,
  referralSharePkr = 0,
  referrerName = null,
  depositRequestId = null,
  transactionId = null,
  periodKey,
  now,
}) {
  try {
    const netToCompanyPkr = +(grossFeePkr - referralSharePkr).toFixed(2);
    const ref = db().collection("company_fee_ledger").doc();
    const pktDate = new Date();
    pktDate.setUTCHours(pktDate.getUTCHours() + 5);
    const date = pktDate.toISOString().slice(0, 10);

    await ref.set({
      date,
      investorUid,
      feeType,
      grossFeePkr,
      referralSharePkr,
      netToCompanyPkr,
      referrerName,
      depositRequestId,
      transactionId,
      periodKey,
      createdAt: now,
    });
  } catch (e) {
    logger.warn("writeCompanyFeeLedger_failed", {
      investorUid,
      feeType,
      error: String(e),
    });
  }
}

/**
 * Book one-time fees triggered on an approved deposit.
 * Idempotent: skips if a fee row with the same `relatedTxId` + `feeKind`
 * already exists.
 */
async function applyDepositFees({
  uid,
  depositTxId,
  depositAmount,
  approverUid,
  now = admin.firestore.FieldValue.serverTimestamp(),
}) {
  const cfg = await getFeeConfig();
  if (!cfg.isEnabled) return { applied: [], cfg };

  const feeVersion = await resolveInvestorFeeVersion(uid, cfg);
  if (feeVersion === "v2") {
    return applyDepositFeesV2({
      uid,
      depositTxId,
      depositAmount,
      approverUid,
      now,
    });
  }

  const periodKey = ymKey(new Date());
  const applied = [];
  let frontEndLoadDelta = 0;
  let referralDelta = 0;

  const chargeFrontLoad =
    cfg.frontEndLoadPct > 0 &&
    (!cfg.frontEndLoadFirstDepositOnly ||
      (await isFirstApprovedDeposit(uid, depositTxId)));

  if (chargeFrontLoad) {
    const fee = +(depositAmount * cfg.frontEndLoadPct / 100).toFixed(2);
    if (fee > 0) {
      const exists = await db()
        .collection("transactions")
        .where("userId", "==", uid)
        .where("type", "==", "front_end_load_fee")
        .where("relatedTxId", "==", depositTxId)
        .limit(1)
        .get();
      if (exists.empty) {
        const ref = db().collection("transactions").doc();
        await ref.set({
          id: ref.id,
          userId: uid,
          type: "front_end_load_fee",
          feeKind: "front_end_load",
          amount: fee,
          status: "approved",
          feePct: cfg.frontEndLoadPct,
          feeBaseAmount: depositAmount,
          relatedTxId: depositTxId,
          periodKey,
          createdAt: now,
          updatedAt: now,
          approvedBy: approverUid,
          notes: `Front-end load (${cfg.frontEndLoadPct}%) on deposit ${depositTxId}`,
        });
        frontEndLoadDelta += fee;
        applied.push({ kind: "front_end_load", amount: fee });
      }
    }
  }

  if (
    cfg.referralEnabled !== false &&
    cfg.referralFeePct > 0 &&
    (await isFirstApprovedDeposit(uid, depositTxId))
  ) {
    const fee = +(depositAmount * cfg.referralFeePct / 100).toFixed(2);
    if (fee > 0) {
      const exists = await db()
        .collection("transactions")
        .where("userId", "==", uid)
        .where("type", "==", "referral_fee")
        .limit(1)
        .get();
      if (exists.empty) {
        const ref = db().collection("transactions").doc();
        await ref.set({
          id: ref.id,
          userId: uid,
          type: "referral_fee",
          feeKind: "referral",
          amount: fee,
          status: "approved",
          feePct: cfg.referralFeePct,
          feeBaseAmount: depositAmount,
          relatedTxId: depositTxId,
          periodKey,
          createdAt: now,
          updatedAt: now,
          approvedBy: approverUid,
          notes: `Referral / employee commission (${cfg.referralFeePct}%) on first deposit`,
        });
        referralDelta += fee;
        applied.push({ kind: "referral", amount: fee });
      }
    }
  }

  if (frontEndLoadDelta > 0 || referralDelta > 0) {
    await recalculateWallet(uid);
    await bumpCompanyEarnings(periodKey, {
      frontEndLoad: frontEndLoadDelta,
      referral: referralDelta,
    });
  }

  return { applied, cfg };
}

/**
 * v2 deposit fee handler.
 * Differences from v1:
 * 1. Front-end load charged on EVERY deposit (not first-only)
 * 2. Referral commission uses halving sequence from referrals/{uid}
 * 3. Referral comes FROM company's front-end load (not separate fee)
 * 4. Writes to company_fee_ledger for admin visibility
 * 5. Updates referrals/{uid}.depositCount after each deposit
 */
async function applyDepositFeesV2({
  uid,
  depositTxId,
  depositAmount,
  approverUid,
  now = admin.firestore.FieldValue.serverTimestamp(),
}) {
  const cfg = await getFeeConfig();
  if (!cfg.isEnabled) return { applied: [], cfg };

  const periodKey = ymKey(new Date());
  const applied = [];
  let frontEndLoadDelta = 0;
  let referralDelta = 0;

  const frontEndPct = cfg.frontEndLoadPct || 0;
  if (frontEndPct > 0) {
    const fee = +(depositAmount * frontEndPct / 100).toFixed(2);
    if (fee > 0) {
      const exists = await db()
        .collection("transactions")
        .where("userId", "==", uid)
        .where("type", "==", "front_end_load_fee")
        .where("relatedTxId", "==", depositTxId)
        .limit(1)
        .get();

      if (exists.empty) {
        const ref = db().collection("transactions").doc();
        await ref.set({
          id: ref.id,
          userId: uid,
          type: "front_end_load_fee",
          feeKind: "front_end_load",
          amount: fee,
          status: "approved",
          feePct: frontEndPct,
          feeBaseAmount: depositAmount,
          relatedTxId: depositTxId,
          periodKey,
          feeVersion: "v2",
          createdAt: now,
          updatedAt: now,
          approvedBy: approverUid,
          notes:
            `Front-end load (${frontEndPct}%) on deposit `
            + `${depositTxId} [v2]`,
        });

        frontEndLoadDelta = fee;
        applied.push({ kind: "front_end_load", amount: fee });

        const referral = cfg.referralEnabled !== false
          ? await getOrCreateReferralRecord(uid)
          : null;

        if (referral) {
          const depositCount = Number(referral.depositCount || 0);
          const commission = computeReferralCommission(fee, depositCount);

          if (commission > 0) {
            await writeCompanyFeeLedger({
              investorUid: uid,
              feeType: "referral_commission",
              grossFeePkr: fee,
              referralSharePkr: commission,
              referrerName: referral.referrerName || null,
              depositRequestId: null,
              transactionId: ref.id,
              periodKey,
              now,
            });

            referralDelta = commission;
            applied.push({
              kind: "referral_commission",
              amount: commission,
              referrerName: referral.referrerName,
              depositNumber: depositCount + 1,
            });

            await db()
              .collection("referrals")
              .doc(uid)
              .set(
                {
                  depositCount: admin.firestore.FieldValue.increment(1),
                  totalCommissionPkr: admin.firestore.FieldValue.increment(
                    commission,
                  ),
                  updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                },
                { merge: true },
              );
          }
        }

        await writeCompanyFeeLedger({
          investorUid: uid,
          feeType: "front_end_load",
          grossFeePkr: fee,
          referralSharePkr: referralDelta,
          referrerName:
            referralDelta > 0
              ? (await getOrCreateReferralRecord(uid))?.referrerName
              : null,
          depositRequestId: null,
          transactionId: ref.id,
          periodKey,
          now,
        });
      }
    }
  }

  if (frontEndLoadDelta > 0) {
    await recalculateWallet(uid);
    await bumpCompanyEarnings(periodKey, {
      frontEndLoad: frontEndLoadDelta,
      referral: 0,
      management: 0,
      performance: 0,
    });
  }

  return { applied, cfg };
}

/**
 * Per-investor monthly fee + profit credit booked atomically.
 * Pure function over Firestore — uses an external batch so the caller can
 * compose with portfolio updates / returnHistory writes.
 *
 * Order intentionally booked into the batch:
 *   1. profit_entry (NET profit, after performance fee deduction)
 *   2. performance_fee
 *   3. management_fee
 */
async function bookMonthEndFeesAndProfit({
  uid,
  grossProfit,
  monthlyPct,
  annualRatePct,
  periodKey,
  approverUid,
  batch,
  now,
  feeConfig,
}) {
  const cfg = feeConfig || (await getFeeConfig());
  const perfPct = cfg.isEnabled ? cfg.performanceFeePct : 0;
  const mgmtPctAnnual = cfg.isEnabled ? cfg.managementFeePctAnnual : 0;

  const performanceFee =
    grossProfit > 0 && perfPct > 0
      ? +(grossProfit * perfPct / 100).toFixed(2)
      : 0;
  const netProfit = +(grossProfit - performanceFee).toFixed(2);

  const principalBase =
    mgmtPctAnnual > 0 ? await getInvestorPrincipalBase(uid) : 0;
  const monthlyMgmtPct = mgmtPctAnnual / 12;
  const managementFee =
    principalBase > 0 && monthlyMgmtPct > 0
      ? +(principalBase * monthlyMgmtPct / 100).toFixed(2)
      : 0;

  const profitTxRef = db().collection("transactions").doc();
  batch.set(profitTxRef, {
    id: profitTxRef.id,
    userId: uid,
    type: "profit_entry",
    amount: netProfit,
    status: "approved",
    createdAt: now,
    updatedAt: now,
    notes: `Month-end profit credit (${periodKey}) — net of fees. Gross ${grossProfit.toFixed(2)}, perf fee ${performanceFee.toFixed(2)}.`,
    approvedBy: approverUid,
    periodKey,
    grossProfit,
    performanceFeeDeducted: performanceFee,
    managementFeeDeducted: managementFee,
    monthlyPct,
    annualRatePct,
  });

  if (performanceFee > 0) {
    const ref = db().collection("transactions").doc();
    batch.set(ref, {
      id: ref.id,
      userId: uid,
      type: "performance_fee",
      feeKind: "performance",
      amount: performanceFee,
      status: "approved",
      feePct: perfPct,
      feeBaseAmount: grossProfit,
      relatedTxId: profitTxRef.id,
      periodKey,
      createdAt: now,
      updatedAt: now,
      approvedBy: approverUid,
      notes: `Performance fee (${perfPct}%) on monthly profit ${grossProfit.toFixed(2)}`,
    });
  }

  if (managementFee > 0) {
    const ref = db().collection("transactions").doc();
    batch.set(ref, {
      id: ref.id,
      userId: uid,
      type: "management_fee",
      feeKind: "management",
      amount: managementFee,
      status: "approved",
      feePct: mgmtPctAnnual,
      monthlyPct: monthlyMgmtPct,
      feeBaseAmount: principalBase,
      relatedTxId: profitTxRef.id,
      periodKey,
      createdAt: now,
      updatedAt: now,
      approvedBy: approverUid,
      notes: `Management fee (${mgmtPctAnnual}%/yr → ${monthlyMgmtPct.toFixed(4)}%/mo) on principal ${principalBase.toFixed(2)}`,
    });
  }

  return {
    grossProfit,
    netProfit,
    performanceFee,
    managementFee,
    principalBase,
    profitTxId: profitTxRef.id,
  };
}

/**
 * Build/refresh the investor-facing fee statement for a given period.
 * Aggregates all transactions in the month into a denormalized doc.
 */
async function writeFeeStatement(uid, periodKey, { extra } = {}) {
  // Period bounds (UTC)
  const [y, m] = periodKey.split("-").map(Number);
  const start = new Date(Date.UTC(y, m - 1, 1));
  const endExclusive = new Date(Date.UTC(y, m, 1));

  const snap = await db()
    .collection("transactions")
    .where("userId", "==", uid)
    .get();

  let principalAtStart = 0;
  let depositsThisMonth = 0;
  let frontEndLoadFee = 0;
  let referralFee = 0;
  let managementFee = 0;
  let performanceFee = 0;
  let grossProfit = 0;
  let netProfit = 0;
  let withdrawalsThisMonth = 0;

  for (const doc of snap.docs) {
    const d = doc.data();
    const ty = (d.type || "").toLowerCase();
    const st = (d.status || "").toLowerCase();
    const amt = Math.abs(Number(d.amount) || 0);
    const created = d.createdAt && d.createdAt.toDate
      ? d.createdAt.toDate()
      : null;
    const inMonth =
      created &&
      created.getTime() >= start.getTime() &&
      created.getTime() < endExclusive.getTime();

    // Principal at start = deposits approved BEFORE this month
    //                    minus one-time fees BEFORE this month
    //                    minus completed withdrawals BEFORE this month
    if (created && created.getTime() < start.getTime()) {
      if (ty === "deposit" && st === "approved") principalAtStart += amt;
      else if (
        (ty === "front_end_load_fee" || ty === "referral_fee") &&
        (st === "approved" || st === "completed")
      ) {
        principalAtStart -= amt;
      } else if (ty === "withdrawal" && st === "completed") {
        principalAtStart -= amt;
      }
    }

    if (!inMonth) continue;

    if (ty === "deposit" && st === "approved") depositsThisMonth += amt;
    else if (ty === "withdrawal" && st === "completed")
      withdrawalsThisMonth += amt;
    else if (
      (ty === "profit_entry" || ty === "profit") &&
      (st === "approved" || st === "completed")
    ) {
      netProfit += amt;
      const g = Number(d.grossProfit);
      if (Number.isFinite(g) && g > 0) {
        grossProfit += g;
      } else {
        grossProfit += amt;
      }
    } else if (ty === "front_end_load_fee" && (st === "approved" || st === "completed")) {
      frontEndLoadFee += amt;
    } else if (ty === "referral_fee" && (st === "approved" || st === "completed")) {
      referralFee += amt;
    } else if (ty === "management_fee" && (st === "approved" || st === "completed")) {
      managementFee += amt;
    } else if (ty === "performance_fee" && (st === "approved" || st === "completed")) {
      performanceFee += amt;
    }
  }

  if (principalAtStart < 0) principalAtStart = 0;
  const totalFees = frontEndLoadFee + referralFee + managementFee + performanceFee;
  const effectiveFeeRatePct =
    grossProfit > 0
      ? +(((performanceFee + managementFee) / grossProfit) * 100).toFixed(2)
      : 0;

  const ref = db()
    .collection("users")
    .doc(uid)
    .collection("fee_statements")
    .doc(periodKey);

  await ref.set(
    {
      periodKey,
      uid,
      principalAtStart,
      depositsThisMonth,
      withdrawalsThisMonth,
      grossProfit,
      netProfit,
      managementFee,
      performanceFee,
      frontEndLoadFee,
      referralFee,
      totalFees,
      effectiveFeeRatePct,
      generatedAt: admin.firestore.FieldValue.serverTimestamp(),
      ...(extra || {}),
    },
    { merge: true },
  );

  return {
    periodKey,
    principalAtStart,
    grossProfit,
    netProfit,
    managementFee,
    performanceFee,
    frontEndLoadFee,
    referralFee,
    totalFees,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Callables
// ─────────────────────────────────────────────────────────────────────────────

exports.getFeeConfig = onCall(
  { region: "us-central1" },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Sign in required.");
    }
    const cfg = await getFeeConfig();
    return {
      ...cfg,
      defaultFeeVersion: cfg.defaultFeeVersion || "v1",
      frontEndLoadAllDeposits: cfg.frontEndLoadAllDeposits === true,
      managementFeeAnnualPct: cfg.managementFeeAnnualPct ?? 1.5,
      performanceFeeHwmPct: cfg.performanceFeeHwmPct ?? 15.0,
      financialYearStartMonth: cfg.financialYearStartMonth ?? 7,
      referralEnabled: cfg.referralEnabled !== false,
    };
  },
);

exports.saveFeeConfig = onCall(
  { region: "us-central1" },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Sign in required.");
    }
    await assertAdmin(request.auth.uid);

    const body = request.data || {};
    const fyMonth = Number(body.financialYearStartMonth ?? 7);
    const next = {
      isEnabled: body.isEnabled === true,
      managementFeePctAnnual: clampPct(body.managementFeePctAnnual),
      performanceFeePct: clampPct(body.performanceFeePct),
      referralFeePct: clampPct(body.referralFeePct),
      frontEndLoadPct: clampPct(body.frontEndLoadPct),
      frontEndLoadFirstDepositOnly:
        body.frontEndLoadFirstDepositOnly === true,
      defaultFeeVersion: body.defaultFeeVersion === "v2" ? "v2" : "v1",
      frontEndLoadAllDeposits: body.frontEndLoadAllDeposits === true,
      managementFeeAnnualPct: clampPct(body.managementFeeAnnualPct ?? 1.5),
      performanceFeeHwmPct: clampPct(body.performanceFeeHwmPct ?? 15.0),
      financialYearStartMonth: Number.isFinite(fyMonth)
        ? Math.max(1, Math.min(12, Math.round(fyMonth)))
        : 7,
      referralEnabled: body.referralEnabled !== false,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedBy: request.auth.uid,
    };

    const beforeSnap = await db().doc(FEE_CONFIG_DOC).get();
    await db().doc(FEE_CONFIG_DOC).set(next, { merge: true });

    try {
      await appendAudit(
        request.auth.uid,
        "admin",
        "saveFeeConfig",
        "settings",
        "fee_config",
        beforeSnap.data() || null,
        next,
      );
    } catch (e) {
      logger.warn("saveFeeConfig_audit_failed", { error: String(e) });
    }

    return { ok: true };
  },
);

/**
 * Admin callable: set feeVersion on users/{uid} and
 * portfolios/{uid} atomically.
 */
exports.setInvestorFeeVersion = onCall(
  { region: "us-central1" },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Sign in required.");
    }
    await assertAdmin(request.auth.uid);

    const { userId, feeVersion } = request.data || {};
    if (!userId) {
      throw new HttpsError("invalid-argument", "userId required.");
    }
    if (feeVersion !== "v1" && feeVersion !== "v2") {
      throw new HttpsError(
        "invalid-argument",
        "feeVersion must be 'v1' or 'v2'.",
      );
    }

    const userRef = db().collection("users").doc(userId);
    const beforeSnap = await userRef.get();
    const beforeVersion =
      (beforeSnap.data() || {}).feeVersion || "v1";

    const now = admin.firestore.FieldValue.serverTimestamp();
    const batch = db().batch();

    batch.set(
      userRef,
      {
        feeVersion,
        feeVersionUpdatedAt: now,
        feeVersionUpdatedBy: request.auth.uid,
      },
      { merge: true },
    );
    batch.set(
      db().collection("portfolios").doc(userId),
      { feeVersion, feeVersionUpdatedAt: now },
      { merge: true },
    );

    await batch.commit();

    try {
      await appendAudit(
        request.auth.uid,
        "admin",
        "setInvestorFeeVersion",
        "users",
        userId,
        { feeVersion: beforeVersion },
        { feeVersion },
      );
    } catch (e) {
      logger.warn("setInvestorFeeVersion_audit_failed", {
        error: String(e),
      });
    }

    return { ok: true };
  },
);

/**
 * Admin callable: create or update referrals/{investorUid}
 * document with v2 referral details.
 */
exports.saveReferralV2 = onCall(
  { region: "us-central1" },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Sign in required.");
    }
    await assertAdmin(request.auth.uid);

    const {
      investorUid,
      referrerName,
      referrerCnic,
      referrerAddress,
      referrerFaName,
      notes,
    } = request.data || {};

    if (!investorUid) {
      throw new HttpsError("invalid-argument", "investorUid required.");
    }
    if (!referrerName || !referrerName.trim()) {
      throw new HttpsError("invalid-argument", "referrerName required.");
    }

    const now = admin.firestore.FieldValue.serverTimestamp();
    const existing = await db()
      .collection("referrals")
      .doc(investorUid)
      .get();

    await db()
      .collection("referrals")
      .doc(investorUid)
      .set(
        {
          investorUid,
          referrerName: referrerName.trim(),
          referrerCnic: (referrerCnic || "").trim(),
          referrerAddress: (referrerAddress || "").trim(),
          referrerFaName: (referrerFaName || "").trim(),
          notes: (notes || "").trim(),
          ...(existing.exists
            ? {}
            : {
                depositCount: 0,
                totalCommissionPkr: 0,
                assignedAt: now,
              }),
          assignedBy: request.auth.uid,
          updatedAt: now,
        },
        { merge: true },
      );

    return { ok: true };
  },
);

/**
 * Admin: build/refresh fee statements for all investors who had any
 * fee/profit activity in `periodKey`. Sends a notification to each.
 */
exports.sendMonthlyFeeStatements = onCall(
  { region: "us-central1" },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Sign in required.");
    }
    await assertAdmin(request.auth.uid);

    const dryRun = request.data?.dryRun === true;
    const periodKey = String(request.data?.periodKey || ymKey(new Date())).trim();
    if (!/^\d{4}-\d{2}$/.test(periodKey)) {
      throw new HttpsError("invalid-argument", "periodKey must be YYYY-MM.");
    }

    const [y, m] = periodKey.split("-").map(Number);
    const start = admin.firestore.Timestamp.fromDate(
      new Date(Date.UTC(y, m - 1, 1)),
    );
    const endExclusive = admin.firestore.Timestamp.fromDate(
      new Date(Date.UTC(y, m, 1)),
    );

    const snap = await db()
      .collection("transactions")
      .where("createdAt", ">=", start)
      .where("createdAt", "<", endExclusive)
      .get();

    const uids = new Set();
    for (const doc of snap.docs) {
      const d = doc.data();
      const ty = (d.type || "").toLowerCase();
      const st = (d.status || "").toLowerCase();
      if (st !== "approved" && st !== "completed") continue;
      if (
        ty === "profit_entry" ||
        ty === "profit" ||
        ty === "front_end_load_fee" ||
        ty === "referral_fee" ||
        ty === "management_fee" ||
        ty === "performance_fee"
      ) {
        if (d.userId) uids.add(d.userId);
      }
    }

    let written = 0;
    let errors = 0;
    const generatedFor = [];

    for (const uid of uids) {
      try {
        if (!dryRun) {
          const stmt = await writeFeeStatement(uid, periodKey, {
            generatedBy: request.auth.uid,
          });
          await db()
            .collection("users")
            .doc(uid)
            .collection("notifications")
            .add({
              title: `Your ${periodKey} fee statement is ready`,
              body: `Net profit credited: PKR ${stmt.netProfit.toFixed(0)}. Total fees deducted: PKR ${stmt.totalFees.toFixed(0)}.`,
              type: "fee_statement",
              category: "wallet",
              action: "open_fee_statement",
              refId: periodKey,
              read: false,
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
              currency: "PKR",
              amount: stmt.totalFees,
            });
        }
        written++;
        generatedFor.push(uid);
      } catch (e) {
        errors++;
        logger.error("sendMonthlyFeeStatements_user_failed", {
          uid,
          error: String(e),
        });
      }
    }

    try {
      await appendAudit(
        request.auth.uid,
        "admin",
        dryRun ? "sendMonthlyFeeStatementsDryRun" : "sendMonthlyFeeStatements",
        "fee_statements",
        periodKey,
        null,
        { investors: uids.size, written, errors },
      );
    } catch (e) {
      logger.warn("sendMonthlyFeeStatements_audit_failed", { error: String(e) });
    }

    return {
      ok: true,
      dryRun,
      periodKey,
      investors: uids.size,
      written,
      errors,
      generatedFor,
    };
  },
);

/**
 * Scheduled: month-end fee statement generation. Runs every day at 00:30 UTC,
 * but only does work on the FIRST day of the new month so it picks up the
 * just-closed previous month after `applyMonthEndProfitCredits` has run.
 */
exports.applyMonthEndFeeStatements = onSchedule(
  "30 0 * * *",
  async () => {
    const now = new Date();
    if (now.getUTCDate() !== 1) {
      return;
    }
    // Previous month
    const prev = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() - 1, 1));
    const periodKey = ymKey(prev);
    const start = admin.firestore.Timestamp.fromDate(prev);
    const endExclusive = admin.firestore.Timestamp.fromDate(
      new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1)),
    );

    const snap = await db()
      .collection("transactions")
      .where("createdAt", ">=", start)
      .where("createdAt", "<", endExclusive)
      .get();

    const uids = new Set();
    for (const doc of snap.docs) {
      const d = doc.data();
      const ty = (d.type || "").toLowerCase();
      const st = (d.status || "").toLowerCase();
      if (st !== "approved" && st !== "completed") continue;
      if (
        ty === "profit_entry" ||
        ty === "profit" ||
        ty === "front_end_load_fee" ||
        ty === "referral_fee" ||
        ty === "management_fee" ||
        ty === "performance_fee"
      ) {
        if (d.userId) uids.add(d.userId);
      }
    }

    let written = 0;
    for (const uid of uids) {
      try {
        const stmt = await writeFeeStatement(uid, periodKey, {
          generatedBy: "system_scheduler",
        });
        await db()
          .collection("users")
          .doc(uid)
          .collection("notifications")
          .add({
            title: `Your ${periodKey} fee statement is ready`,
            body: `Net profit credited: PKR ${stmt.netProfit.toFixed(0)}. Total fees deducted: PKR ${stmt.totalFees.toFixed(0)}.`,
            type: "fee_statement",
            category: "wallet",
            action: "open_fee_statement",
            refId: periodKey,
            read: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            currency: "PKR",
            amount: stmt.totalFees,
          });
        written++;
      } catch (e) {
        logger.error("applyMonthEndFeeStatements_user_failed", {
          uid,
          error: String(e),
        });
      }
    }

    logger.info("applyMonthEndFeeStatements_done", {
      periodKey,
      investors: uids.size,
      written,
    });
  },
);

/**
 * Scheduled year-end management fee statement generator.
 * Fires 30 June 23:59 PKT.
 */
exports.generateYearEndFeeStatements = onSchedule(
  {
    schedule: "59 23 30 6 *",
    timeZone: "Asia/Karachi",
    region: REGION,
    memory: "1GiB",
    timeoutSeconds: 540,
  },
  async () => {
    const { PDFDocument, rgb, StandardFonts } = require("pdf-lib");

    const nowPkt = new Date(
      new Date().toLocaleString("en-US", { timeZone: "Asia/Karachi" }),
    );
    const fyYear = nowPkt.getFullYear() - 1;
    const fyLabel = `${fyYear}-${String(fyYear + 1).slice(2)}`;
    const fyStart = `${fyYear}-07-01`;
    const fyEnd = `${fyYear + 1}-06-30`;

    logger.info("generateYearEndFeeStatements_start", { fyLabel });

    const cfg = await getFeeConfig();
    const annualRatePct = cfg.managementFeeAnnualPct ?? 1.5;

    const portfoliosSnap = await db().collection("portfolios").get();

    let success = 0;
    let skipped = 0;
    let failed = 0;

    for (const portfolioDoc of portfoliosSnap.docs) {
      const uid = portfolioDoc.id;
      try {
        const portfolio = portfolioDoc.data();

        const userSnap = await db().collection("users").doc(uid).get();
        if (!userSnap.exists) {
          skipped++;
          continue;
        }
        const userData = userSnap.data();
        const feeVersion =
          userData.feeVersion || portfolio.feeVersion || "v1";
        if (feeVersion !== "v2") {
          skipped++;
          continue;
        }

        const ytdFee = Number(portfolio.ytdManagementFee || 0);
        const investorName = (
          userData.name ||
          userData.fullName ||
          "Investor"
        ).trim();

        const dailySnap = await db()
          .collection("portfolios")
          .doc(uid)
          .collection("management_fee_daily")
          .where("date", ">=", fyStart)
          .where("date", "<=", fyEnd)
          .orderBy("date")
          .get();

        const pdfDoc = await PDFDocument.create();
        const page = pdfDoc.addPage([595, 842]);
        const font = await pdfDoc.embedFont(StandardFonts.Helvetica);
        const bold = await pdfDoc.embedFont(StandardFonts.HelveticaBold);
        const { width, height } = page.getSize();

        page.drawText("ISC-WAI", {
          x: 50,
          y: height - 60,
          size: 22,
          font: bold,
          color: rgb(0.1, 0.3, 0.6),
        });
        page.drawText("Annual Management Fee Statement", {
          x: 50,
          y: height - 85,
          size: 14,
          font,
          color: rgb(0.3, 0.3, 0.3),
        });

        page.drawLine({
          start: { x: 50, y: height - 95 },
          end: { x: width - 50, y: height - 95 },
          thickness: 1,
          color: rgb(0.8, 0.8, 0.8),
        });

        let y = height - 130;
        const row = (label, value) => {
          page.drawText(label, {
            x: 50,
            y,
            size: 10,
            font: bold,
            color: rgb(0.4, 0.4, 0.4),
          });
          page.drawText(String(value), {
            x: 200,
            y,
            size: 10,
            font,
            color: rgb(0.1, 0.1, 0.1),
          });
          y -= 20;
        };

        row("Investor Name:", investorName);
        row("Account ID:", uid.slice(-8).toUpperCase());
        row(
          "Financial Year:",
          `1 July ${fyYear} – 30 June ${fyYear + 1}`,
        );
        row("Fee Rate:", `${annualRatePct}% per annum`);
        row("Deduction Method:", "Daily accrual (silent)");
        row("Total Fee Paid:", `PKR ${ytdFee.toFixed(2)}`);

        // Portfolio value as at 30 June (from live wallet)
        try {
          const walletSnap = await db().collection("wallets").doc(uid).get();
          const portfolioValueAfterFees = walletSnap.exists
            ? Number(walletSnap.data().availableBalance || 0)
            : 0;
          row(
            "Portfolio Value (30 June):",
            `PKR ${portfolioValueAfterFees.toFixed(2)}`,
          );
        } catch (_) {
          // non-fatal — skip if wallet unavailable
        }

        y -= 20;

        if (dailySnap.docs.length > 0) {
          page.drawText("Daily Deduction Summary", {
            x: 50,
            y,
            size: 12,
            font: bold,
            color: rgb(0.1, 0.3, 0.6),
          });
          y -= 25;

          const cols = [50, 140, 260, 380, 480];
          ["Date", "Base (PKR)", "Rate", "Fee (PKR)", "YTD (PKR)"].forEach(
            (h, i) => {
              page.drawText(h, {
                x: cols[i],
                y,
                size: 9,
                font: bold,
                color: rgb(0.3, 0.3, 0.3),
              });
            },
          );
          y -= 15;

          const maxRows = Math.min(dailySnap.docs.length, 50);
          for (let i = 0; i < maxRows; i++) {
            const d = dailySnap.docs[i].data();
            if (y < 80) break;
            [
              d.date || "",
              (d.basePkr || 0).toFixed(2),
              `${(d.annualRatePct || annualRatePct).toFixed(2)}%`,
              (d.dailyFeePkr || 0).toFixed(2),
              (d.ytdTotal || 0).toFixed(2),
            ].forEach((v, col) => {
              page.drawText(String(v), {
                x: cols[col],
                y,
                size: 8,
                font,
                color: rgb(0.2, 0.2, 0.2),
              });
            });
            y -= 13;
          }

          if (dailySnap.docs.length > 50) {
            page.drawText(
              `(Showing first 50 of ${dailySnap.docs.length} records)`,
              {
                x: 50,
                y: y - 5,
                size: 8,
                font,
                color: rgb(0.5, 0.5, 0.5),
              },
            );
          }
        }

        page.drawText(
          "This statement is auto-generated by ISC-WAI. "
            + "Management fee is deducted daily and shown "
            + "annually for transparency.",
          {
            x: 50,
            y: 50,
            size: 7,
            font,
            color: rgb(0.5, 0.5, 0.5),
          },
        );

        const pdfBytes = await pdfDoc.save();

        const bucket = admin.storage().bucket();
        const storagePath = `fee_statements/${uid}/FY_${fyLabel}.pdf`;
        const file = bucket.file(storagePath);
        await file.save(Buffer.from(pdfBytes), {
          metadata: { contentType: "application/pdf" },
          resumable: false,
        });

        let fileUrl = "";
        try {
          const [signed] = await file.getSignedUrl({
            action: "read",
            expires: "03-01-2099",
          });
          fileUrl = signed;
        } catch (signErr) {
          logger.warn("yearEndStatement_signedUrl_failed", {
            uid,
            error: String(signErr),
          });
        }

        await db()
          .collection("users")
          .doc(uid)
          .collection("fee_statements")
          .doc(fyLabel)
          .set(
            {
              periodKey: fyLabel,
              fyStart,
              fyEnd,
              feeType: "management_annual",
              totalFeePkr: ytdFee,
              totalFees: ytdFee,
              annualRatePct,
              daysCount: dailySnap.docs.length,
              storagePath,
              fileUrl,
              generatedAt: admin.firestore.FieldValue.serverTimestamp(),
              generatedBy: "system_year_end",
            },
            { merge: true },
          );

        await db()
          .collection("users")
          .doc(uid)
          .collection("notifications")
          .add({
            title: "Annual Fee Statement Available",
            body: `Your FY ${fyLabel} management fee statement is ready in Reports.`,
            type: "fee_statement",
            category: "wallet",
            action: "open_fee_statement",
            refId: fyLabel,
            read: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });

        success++;
        logger.info("yearEndStatement_generated", { uid, fyLabel, ytdFee });
      } catch (e) {
        failed++;
        logger.error("yearEndStatement_failed", { uid, error: String(e) });
      }
    }

    logger.info("generateYearEndFeeStatements_complete", {
      fyLabel,
      success,
      skipped,
      failed,
    });
  },
);

/**
 * Admin callable: estimate fees for a prospective deposit before approval.
 * Returns { feeVersion, frontEndPct, grossFee, referralCommission,
 *           netToCompany, netInvested, referrerName }.
 */
exports.estimateDepositFee = onCall(
  { region: "us-central1" },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Sign in required.");
    }
    await assertAdmin(request.auth.uid);

    const { userId, amount } = request.data || {};
    if (!userId) {
      throw new HttpsError("invalid-argument", "userId required.");
    }
    const amt = Number(amount || 0);
    if (amt <= 0) {
      throw new HttpsError("invalid-argument", "amount must be > 0.");
    }

    const cfg = await getFeeConfig();
    const feeVersion = await resolveInvestorFeeVersion(userId, cfg);
    const frontEndPct = cfg.frontEndLoadPct || 0;
    const grossFee = parseFloat((amt * frontEndPct / 100).toFixed(2));

    let referralCommission = 0;
    let referrerName = null;

    if (cfg.referralEnabled !== false) {
      if (feeVersion === "v2") {
        const refDoc = await db()
          .collection("referrals")
          .doc(userId)
          .get();
        if (refDoc.exists) {
          const dc = Number(refDoc.data().depositCount || 0);
          referralCommission = computeReferralCommission(grossFee, dc);
          referrerName = refDoc.data().referrerName || null;
        }
      } else {
        // v1: referral fee on first deposit only
        const isFirst = await isFirstApprovedDeposit(userId, "__estimate__");
        if (isFirst && cfg.referralFeePct > 0) {
          referralCommission = parseFloat(
            (amt * cfg.referralFeePct / 100).toFixed(2),
          );
        }
      }
    }

    return {
      feeVersion,
      frontEndPct,
      grossFee,
      referralCommission,
      netToCompany: parseFloat((grossFee - referralCommission).toFixed(2)),
      netInvested: parseFloat((amt - grossFee).toFixed(2)),
      referrerName,
    };
  },
);

// Used by wallet_ledger.js and daily fee modules
module.exports.getFeeConfig_internal = getFeeConfig;
module.exports.computeReferralCommission = computeReferralCommission;
module.exports.resolveInvestorFeeVersion_internal = resolveInvestorFeeVersion;
module.exports.applyDepositFees = applyDepositFees;
module.exports.bookMonthEndFeesAndProfit = bookMonthEndFeesAndProfit;
module.exports.bumpCompanyEarnings = bumpCompanyEarnings;
module.exports.writeFeeStatement = writeFeeStatement;
module.exports.writeCompanyFeeLedger = writeCompanyFeeLedger;
module.exports.ymKey = ymKey;
