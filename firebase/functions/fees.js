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
  };
}

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
    return getFeeConfig();
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
    const next = {
      isEnabled: body.isEnabled === true,
      managementFeePctAnnual: clampPct(body.managementFeePctAnnual),
      performanceFeePct: clampPct(body.performanceFeePct),
      referralFeePct: clampPct(body.referralFeePct),
      frontEndLoadPct: clampPct(body.frontEndLoadPct),
      frontEndLoadFirstDepositOnly:
        body.frontEndLoadFirstDepositOnly === true,
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

// Used by wallet_ledger.js
module.exports.getFeeConfig_internal = getFeeConfig;
module.exports.applyDepositFees = applyDepositFees;
module.exports.bookMonthEndFeesAndProfit = bookMonthEndFeesAndProfit;
module.exports.bumpCompanyEarnings = bumpCompanyEarnings;
module.exports.writeFeeStatement = writeFeeStatement;
module.exports.ymKey = ymKey;
