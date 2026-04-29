/**
 * Wallet & ledger: server-side source of truth.
 * All mutations go through these callables + Admin SDK.
 */

const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const { logger } = require("firebase-functions");
const { recalculateWallet, appendAudit } = require("./wallet_helpers");
const {
  notifyAllAdmins,
  sendCustomerTransactionAlerts,
} = require("./notifications");
const { verifyMpinOrThrow } = require("./mpin");
const {
  applyDepositFees,
  bookMonthEndFeesAndProfit,
  getFeeConfig_internal: getFeeConfigInternal,
} = require("./fees");

const db = () => admin.firestore();

async function safeNotify(fn) {
  try {
    await fn();
  } catch (e) {
    logger.warn("notification_failed", { error: String(e) });
  }
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

async function assertKycApproved(uid) {
  const k = await db().collection("kyc").doc(uid).get();
  const kyc = (k.data()?.status || "pending").toLowerCase();
  if (kyc !== "approved") {
    throw new HttpsError("failed-precondition", "KYC must be approved.");
  }
}

function readRequestBodyBuffer(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on("data", (chunk) => chunks.push(chunk));
    req.on("end", () => resolve(Buffer.concat(chunks)));
    req.on("error", reject);
  });
}

/** Prefer Cloud Functions rawBody when present (binary PDF). */
async function getPdfBuffer(req) {
  if (req.rawBody && req.rawBody.length) {
    return Buffer.isBuffer(req.rawBody)
      ? req.rawBody
      : Buffer.from(req.rawBody);
  }
  return readRequestBodyBuffer(req);
}

/** Prefer Cloud Functions rawBody when present (binary APK). */
async function getBinaryBuffer(req) {
  if (req.rawBody && req.rawBody.length) {
    return Buffer.isBuffer(req.rawBody)
      ? req.rawBody
      : Buffer.from(req.rawBody);
  }
  return readRequestBodyBuffer(req);
}

function txId() {
  const y = new Date().getFullYear();
  const rand = Math.random().toString(36).slice(2, 10).toUpperCase();
  return `TXN-${y}-${rand}`;
}

async function getAvailableBalance(userId) {
  const w = await db().collection("wallets").doc(userId).get();
  if (!w.exists) {
    await recalculateWallet(userId);
    const w2 = await db().collection("wallets").doc(userId).get();
    return Number(w2.data()?.availableBalance) || 0;
  }
  return Number(w.data()?.availableBalance) || 0;
}

function deriveWalletFromTransactions(docs) {
  let totalDeposited = 0;
  let totalWithdrawn = 0;
  let totalProfit = 0;
  let totalAdjustments = 0;
  let reservedAmount = 0;
  let moneyMarketCreditedTotal = 0;
  let moneyMarketWithdrawnTotal = 0;
  let moneyMarketReserved = 0;

  for (const doc of docs) {
    const d = doc.data ? doc.data() : doc;
    const amt = Number(d.amount) || 0;
    const st = (d.status || "").toLowerCase();
    const ty = (d.type || "").toLowerCase();

    if (ty === "deposit" && st === "approved") {
      totalDeposited += amt;
      moneyMarketCreditedTotal += amt * 0.05;
    }
    if (ty === "withdrawal") {
      // Canonical withdrawal lifecycle used across wallet projections:
      // pending  -> reserved only
      // approved -> reserved only (awaiting settlement)
      // completed -> counted as withdrawn (settled)
      if (st === "pending" || st === "approved") {
        reservedAmount += amt;
        moneyMarketReserved += amt;
      } else if (st === "completed") {
        totalWithdrawn += amt;
        moneyMarketWithdrawnTotal += amt;
      }
    }
    if (
      (ty === "profit" || ty === "profit_entry") &&
      (st === "approved" || st === "completed")
    )
      totalProfit += amt;
    if (ty === "adjustment" && (st === "approved" || st === "completed"))
      totalAdjustments += amt;
  }

  const availableBalance =
    totalDeposited +
    totalProfit +
    totalAdjustments -
    totalWithdrawn -
    reservedAmount;
  const moneyMarketBalance = Math.max(
    0,
    moneyMarketCreditedTotal - moneyMarketWithdrawnTotal,
  );
  const moneyMarketAvailable = Math.max(0, moneyMarketBalance - moneyMarketReserved);
  return {
    availableBalance,
    moneyMarketCreditedTotal,
    moneyMarketWithdrawnTotal,
    moneyMarketReserved,
    moneyMarketBalance,
    moneyMarketAvailable,
  };
}

async function safeAppendAudit(...args) {
  try {
    await appendAudit(...args);
  } catch (e) {
    logger.error("audit_log_failed", { error: String(e), args });
  }
}

function toMonthKey(date) {
  const y = date.getUTCFullYear();
  const m = String(date.getUTCMonth() + 1).padStart(2, "0");
  return `${y}-${m}`;
}

function isCalendarMonthEnd(date) {
  const utc = new Date(
    Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()),
  );
  const tomorrow = new Date(utc);
  tomorrow.setUTCDate(tomorrow.getUTCDate() + 1);
  return tomorrow.getUTCMonth() !== utc.getUTCMonth();
}

function normalizeRate(n) {
  const v = Number(n);
  if (!Number.isFinite(v)) return 0;
  return Math.max(0, Math.min(100, v));
}

function readAnnualRate(data) {
  if (!data || typeof data !== "object") return 0;
  const candidates = [
    data.globalAnnualRatePct,
    data.annualRatePct,
    data.annualRate,
    data.yearlyRatePct,
  ];
  for (const raw of candidates) {
    if (typeof raw === "string") {
      const parsed = Number(raw.replace("%", "").trim());
      if (Number.isFinite(parsed)) return normalizeRate(parsed);
    } else if (Number.isFinite(Number(raw))) {
      return normalizeRate(raw);
    }
  }
  return 0;
}

async function getGlobalAnnualRatePct() {
  const snap = await db().collection("settings").doc("returns_projection").get();
  return readAnnualRate(snap.data());
}

async function runMonthEndProfitCredit({
  dryRun = false,
  requestedBy = "system_scheduler",
  now = new Date(),
  forceMonthKey,
}) {
  const annualRatePct = await getGlobalAnnualRatePct();
  const monthlyPct = annualRatePct / 12;
  const monthKey = forceMonthKey || toMonthKey(now);
  const jobDocId = `monthly_profit_credit_${monthKey}`;
  const jobRef = db()
    .collection("settings")
    .doc("system_jobs")
    .collection("runs")
    .doc(jobDocId);
  const nowTs = admin.firestore.FieldValue.serverTimestamp();

  if (!dryRun) {
    const lock = await db().runTransaction(async (tx) => {
      const snap = await tx.get(jobRef);
      const data = snap.data() || {};
      if (snap.exists && data.status === "completed") {
        return { shouldRun: false, reason: "already_completed" };
      }
      tx.set(
        jobRef,
        {
          kind: "monthly_profit_credit",
          monthKey,
          status: "running",
          requestedBy,
          annualRatePct,
          monthlyPct,
          startedAt: nowTs,
          updatedAt: nowTs,
        },
        { merge: true },
      );
      return { shouldRun: true, reason: "running" };
    });
    if (!lock.shouldRun) {
      return {
        ok: true,
        skipped: true,
        reason: lock.reason,
        monthKey,
        annualRatePct,
        monthlyPct,
      };
    }
  }

  const feeConfig = await getFeeConfigInternal();
  const portfoliosSnap = await db().collection("portfolios").get();
  let successCount = 0;
  let failCount = 0;
  let totalGrossProfit = 0;
  let totalNetProfit = 0;
  let totalManagementFee = 0;
  let totalPerformanceFee = 0;
  const errors = [];

  for (const portfolioDoc of portfoliosSnap.docs) {
    const uid = portfolioDoc.id;
    try {
      const data = portfolioDoc.data();
      const previousValue = Number(data.currentValue) || 0;
      if (previousValue <= 0 || monthlyPct <= 0) continue;

      const grossProfit = previousValue * (monthlyPct / 100);
      // Portfolio currentValue follows GROSS profit so the displayed return
      // tracks the underlying market performance. Fees come out of the wallet
      // ledger, not the portfolio NAV (consistent with the existing model).
      const newValue = previousValue + grossProfit;

      if (!dryRun) {
        const batch = db().batch();
        batch.update(portfolioDoc.ref, {
          currentValue: newValue,
          lastMonthlyReturnPct: monthlyPct,
          lastUpdated: nowTs,
        });
        const histRef = db()
          .collection("portfolios")
          .doc(uid)
          .collection("returnHistory")
          .doc();
        batch.set(histRef, {
          returnPct: monthlyPct,
          profitAmount: grossProfit,
          previousValue,
          newValue,
          appliedAt: nowTs,
          appliedBy: requestedBy,
          mode: "month_end_annual_converted",
          periodKey: monthKey,
        });

        const result = await bookMonthEndFeesAndProfit({
          uid,
          grossProfit,
          monthlyPct,
          annualRatePct,
          periodKey: monthKey,
          approverUid: requestedBy,
          batch,
          now: nowTs,
          feeConfig,
        });

        await batch.commit();
        await recalculateWallet(uid);

        totalGrossProfit += result.grossProfit;
        totalNetProfit += result.netProfit;
        totalManagementFee += result.managementFee;
        totalPerformanceFee += result.performanceFee;
      } else {
        totalGrossProfit += grossProfit;
        totalNetProfit += grossProfit;
      }

      successCount++;
    } catch (e) {
      failCount++;
      errors.push(`${uid}: ${String(e)}`);
      logger.error("runMonthEndProfitCredit_user_failed", {
        uid,
        error: String(e),
      });
    }
  }

  if (!dryRun && (totalManagementFee > 0 || totalPerformanceFee > 0)) {
    try {
      const { bumpCompanyEarnings } = require("./fees");
      await bumpCompanyEarnings(monthKey, {
        management: totalManagementFee,
        performance: totalPerformanceFee,
      });
    } catch (e) {
      logger.warn("runMonthEndProfitCredit_bumpCompanyEarnings_failed", {
        error: String(e),
      });
    }
  }

  if (!dryRun) {
    await jobRef.set(
      {
        status: "completed",
        successCount,
        failCount,
        totalProfit: totalNetProfit,
        totalGrossProfit,
        totalManagementFee,
        totalPerformanceFee,
        errors: errors.slice(0, 50),
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  }

  await safeAppendAudit(
    requestedBy,
    requestedBy === "system_scheduler" ? "system" : "admin",
    dryRun ? "monthEndProfitCreditDryRun" : "monthEndProfitCredit",
    "portfolios",
    "all",
    null,
    {
      monthKey,
      annualRatePct,
      monthlyPct,
      successCount,
      failCount,
      totalGrossProfit,
      totalNetProfit,
      totalManagementFee,
      totalPerformanceFee,
      dryRun,
    },
  );

  return {
    ok: true,
    skipped: false,
    dryRun,
    monthKey,
    annualRatePct,
    monthlyPct,
    successCount,
    failCount,
    totalProfit: totalNetProfit,
    totalGrossProfit,
    totalManagementFee,
    totalPerformanceFee,
    errors,
  };
}

/** Investor: create deposit request + pending transaction */
exports.createDepositRequest = onCall(
  { region: "us-central1" },
  async (request) => {
    if (!request.auth?.uid)
      throw new HttpsError("unauthenticated", "Sign in required.");
    const uid = request.auth.uid;
    const { amount, paymentMethod, proofUrl } = request.data || {};
    const amt = Number(amount);
    if (!amt || amt <= 0)
      throw new HttpsError("invalid-argument", "Invalid amount.");
    if (!paymentMethod || String(paymentMethod).trim().length === 0) {
      throw new HttpsError("invalid-argument", "paymentMethod required.");
    }
    await assertKycApproved(uid);

    const reqRef = db().collection("deposit_requests").doc();
    const tid = txId();
    const tRef = db().collection("transactions").doc(tid);
    const now = admin.firestore.FieldValue.serverTimestamp();

    const batch = db().batch();
    batch.set(reqRef, {
      userId: uid,
      amount: amt,
      paymentMethod: String(paymentMethod).trim(),
      proofUrl: proofUrl ? String(proofUrl).trim() : null,
      status: "pending",
      transactionId: tid,
      createdAt: now,
      updatedAt: now,
    });
    batch.set(tRef, {
      id: tid,
      userId: uid,
      type: "deposit",
      amount: amt,
      status: "pending",
      transactionId: tid,
      createdAt: now,
      updatedAt: now,
      requestId: reqRef.id,
      proofUrl: proofUrl ? String(proofUrl).trim() : null,
      paymentMethod: String(paymentMethod).trim(),
      notes: null,
    });
    await batch.commit();
    await recalculateWallet(uid);
    await safeAppendAudit(
      uid,
      "investor",
      "createDepositRequest",
      "deposit_request",
      reqRef.id,
      null,
      {
        amount: amt,
        transactionId: tid,
      },
    );

    await safeNotify(() =>
      notifyAllAdmins({
        title: "New deposit request",
        body: `PKR ${amt.toFixed(0)} — ${String(paymentMethod).trim()}`,
        type: "deposit_request",
        category: "admin",
        action: "open_deposits",
        refId: reqRef.id,
        amount: amt,
        currency: "PKR",
      }),
    );
    await safeNotify(() =>
      sendCustomerTransactionAlerts(uid, {
        title: "Deposit request submitted",
        body: `Your deposit request of PKR ${amt.toFixed(0)} is pending review.`,
        type: "deposit",
        category: "wallet",
        action: "open_wallet",
        refId: reqRef.id,
        amount: amt,
        currency: "PKR",
      }),
    );

    return { requestId: reqRef.id, transactionId: tid };
  },
);

/** Investor: withdrawal request + pending transaction */
exports.createWithdrawalRequest = onCall(
  { region: "us-central1" },
  async (request) => {
    if (!request.auth?.uid)
      throw new HttpsError("unauthenticated", "Sign in required.");
    const uid = request.auth.uid;
    const amt = Number(request.data?.amount);
    if (!amt || amt <= 0)
      throw new HttpsError("invalid-argument", "Invalid amount.");
    await assertKycApproved(uid);
    // Gate sensitive action on MPIN if user has enabled it. No-op otherwise.
    await verifyMpinOrThrow(uid, request.data?.mpin);
    const reqRef = db().collection("withdrawal_requests").doc();
    const tid = txId();
    const tRef = db().collection("transactions").doc(tid);
    const now = admin.firestore.FieldValue.serverTimestamp();

    await db().runTransaction(async (tx) => {
      const txsSnap = await tx.get(
        db().collection("transactions").where("userId", "==", uid),
      );
      const wallet = deriveWalletFromTransactions(txsSnap.docs);
      if (wallet.availableBalance < amt) {
        throw new HttpsError(
          "failed-precondition",
          "Insufficient available balance.",
        );
      }
      if (wallet.moneyMarketAvailable < amt) {
        throw new HttpsError(
          "failed-precondition",
          "Insufficient money market withdrawable balance.",
        );
      }

      tx.set(reqRef, {
        userId: uid,
        amount: amt,
        status: "pending",
        transactionId: tid,
        createdAt: now,
        updatedAt: now,
      });
      tx.set(tRef, {
        id: tid,
        userId: uid,
        type: "withdrawal",
        amount: amt,
        status: "pending",
        createdAt: now,
        updatedAt: now,
        requestId: reqRef.id,
        notes: null,
      });
    });
    await recalculateWallet(uid);
    await safeAppendAudit(
      uid,
      "investor",
      "createWithdrawalRequest",
      "withdrawal_request",
      reqRef.id,
      null,
      {
        amount: amt,
        transactionId: tid,
      },
    );

    await safeNotify(() =>
      notifyAllAdmins({
        title: "New withdrawal request",
        body: `PKR ${amt.toFixed(0)} requested`,
        type: "withdrawal_request",
        category: "admin",
        action: "open_withdrawals",
        refId: reqRef.id,
        amount: amt,
        currency: "PKR",
      }),
    );
    await safeNotify(() =>
      sendCustomerTransactionAlerts(uid, {
        title: "Withdrawal request submitted",
        body: `Your withdrawal request of PKR ${amt.toFixed(0)} is pending review.`,
        type: "withdrawal",
        category: "wallet",
        action: "open_wallet",
        refId: reqRef.id,
        amount: amt,
        currency: "PKR",
      }),
    );

    return { requestId: reqRef.id, transactionId: tid };
  },
);

/** Admin: approve deposit */
exports.approveDeposit = onCall({ region: "us-central1" }, async (request) => {
  if (!request.auth?.uid)
    throw new HttpsError("unauthenticated", "Sign in required.");
  await assertAdmin(request.auth.uid);
  const { requestId, note } = request.data || {};
  if (!requestId)
    throw new HttpsError("invalid-argument", "requestId required.");

  const reqSnap = await db()
    .collection("deposit_requests")
    .doc(requestId)
    .get();
  if (!reqSnap.exists) throw new HttpsError("not-found", "Request not found.");
  const req = reqSnap.data();
  if (req.status !== "pending") {
    throw new HttpsError("failed-precondition", "Request not pending.");
  }
  const tid = req.transactionId;
  const tRef = db().collection("transactions").doc(tid);
  const now = admin.firestore.FieldValue.serverTimestamp();

  const batch = db().batch();
  batch.update(reqSnap.ref, {
    status: "approved",
    updatedAt: now,
    adminNote: note || null,
  });
  batch.update(tRef, {
    status: "approved",
    updatedAt: now,
    notes: note || null,
    approvedBy: request.auth.uid,
  });
  await batch.commit();
  await recalculateWallet(req.userId);

  const amt = Number(req.amount) || 0;
  let feesApplied = [];
  try {
    const result = await applyDepositFees({
      uid: req.userId,
      depositTxId: tid,
      depositAmount: amt,
      approverUid: request.auth.uid,
    });
    feesApplied = result.applied || [];
  } catch (e) {
    logger.warn("approveDeposit_applyDepositFees_failed", {
      uid: req.userId,
      tid,
      error: String(e),
    });
  }

  await safeAppendAudit(
    request.auth.uid,
    "admin",
    "approveDeposit",
    "deposit_request",
    requestId,
    { status: "pending" },
    {
      status: "approved",
      transactionId: tid,
      feesApplied,
    },
  );

  await safeNotify(() =>
    sendCustomerTransactionAlerts(req.userId, {
      title: "Deposit approved",
      body: `Your deposit of PKR ${amt.toFixed(0)} has been approved.`,
      type: "deposit",
      category: "wallet",
      action: "open_wallet",
      refId: requestId,
      amount: amt,
      currency: "PKR",
    }),
  );

  return { ok: true, feesApplied };
});

/** Admin: reject deposit */
exports.rejectDeposit = onCall({ region: "us-central1" }, async (request) => {
  if (!request.auth?.uid)
    throw new HttpsError("unauthenticated", "Sign in required.");
  await assertAdmin(request.auth.uid);
  const { requestId, reason } = request.data || {};
  if (!requestId)
    throw new HttpsError("invalid-argument", "requestId required.");

  const reqSnap = await db()
    .collection("deposit_requests")
    .doc(requestId)
    .get();
  if (!reqSnap.exists) throw new HttpsError("not-found", "Request not found.");
  const req = reqSnap.data();
  if (req.status !== "pending") {
    throw new HttpsError("failed-precondition", "Request not pending.");
  }
  const tid = req.transactionId;
  const tRef = db().collection("transactions").doc(tid);
  const now = admin.firestore.FieldValue.serverTimestamp();

  const batch = db().batch();
  batch.update(reqSnap.ref, {
    status: "rejected",
    updatedAt: now,
    rejectReason: reason || "",
  });
  batch.update(tRef, {
    status: "rejected",
    updatedAt: now,
    notes: reason || "rejected",
  });
  await batch.commit();
  await recalculateWallet(req.userId);
  await safeAppendAudit(
    request.auth.uid,
    "admin",
    "rejectDeposit",
    "deposit_request",
    requestId,
    null,
    {
      reason,
    },
  );

  const rejAmt = Number(req.amount) || 0;
  const rejReason = reason ? String(reason).trim() : "";
  await safeNotify(() =>
    sendCustomerTransactionAlerts(req.userId, {
      title: "Deposit rejected",
      body: rejReason.length
        ? `Your deposit of PKR ${rejAmt.toFixed(0)} was rejected. ${rejReason}`
        : `Your deposit of PKR ${rejAmt.toFixed(0)} was rejected.`,
      type: "deposit",
      category: "wallet",
      action: "open_wallet",
      refId: requestId,
      amount: rejAmt,
      currency: "PKR",
    }),
  );

  return { ok: true };
});

/** Admin: approve withdrawal (pending -> approved) */
exports.approveWithdrawal = onCall(
  { region: "us-central1" },
  async (request) => {
    if (!request.auth?.uid)
      throw new HttpsError("unauthenticated", "Sign in required.");
    await assertAdmin(request.auth.uid);
    const { requestId, note } = request.data || {};
    if (!requestId)
      throw new HttpsError("invalid-argument", "requestId required.");

    const reqSnap = await db()
      .collection("withdrawal_requests")
      .doc(requestId)
      .get();
    if (!reqSnap.exists)
      throw new HttpsError("not-found", "Request not found.");
    const req = reqSnap.data();
    if (req.status !== "pending") {
      throw new HttpsError("failed-precondition", "Request not pending.");
    }
    const tid = req.transactionId;
    const tRef = db().collection("transactions").doc(tid);
    const now = admin.firestore.FieldValue.serverTimestamp();

    const batch = db().batch();
    batch.update(reqSnap.ref, {
      status: "approved",
      updatedAt: now,
      adminNote: note || null,
    });
    batch.update(tRef, {
      status: "approved",
      updatedAt: now,
      notes: note || null,
      approvedBy: request.auth.uid,
    });
    await batch.commit();
    await recalculateWallet(req.userId);
    await safeAppendAudit(
      request.auth.uid,
      "admin",
      "approveWithdrawal",
      "withdrawal_request",
      requestId,
      null,
      {
        status: "approved",
      },
    );

    const wAmt = Number(req.amount) || 0;
    await safeNotify(() =>
      sendCustomerTransactionAlerts(req.userId, {
        title: "Withdrawal approved",
        body: `Your withdrawal of PKR ${wAmt.toFixed(0)} has been approved.`,
        type: "withdrawal",
        category: "wallet",
        action: "open_wallet",
        refId: requestId,
        amount: wAmt,
        currency: "PKR",
      }),
    );

    return { ok: true };
  },
);

/** Admin: complete withdrawal (approved -> completed) */
exports.completeWithdrawal = onCall(
  { region: "us-central1" },
  async (request) => {
    if (!request.auth?.uid)
      throw new HttpsError("unauthenticated", "Sign in required.");
    await assertAdmin(request.auth.uid);
    const { requestId, settlementRef } = request.data || {};
    if (!requestId)
      throw new HttpsError("invalid-argument", "requestId required.");

    const reqSnap = await db()
      .collection("withdrawal_requests")
      .doc(requestId)
      .get();
    if (!reqSnap.exists)
      throw new HttpsError("not-found", "Request not found.");
    const req = reqSnap.data();
    if (req.status !== "approved") {
      throw new HttpsError(
        "failed-precondition",
        "Request must be approved first.",
      );
    }
    const tid = req.transactionId;
    const tRef = db().collection("transactions").doc(tid);
    const now = admin.firestore.FieldValue.serverTimestamp();

    const batch = db().batch();
    batch.update(reqSnap.ref, {
      status: "completed",
      updatedAt: now,
      settlementRef: settlementRef || null,
    });
    batch.update(tRef, {
      status: "completed",
      updatedAt: now,
      notes: settlementRef ? `settlement:${settlementRef}` : "completed",
      completedBy: request.auth.uid,
    });
    await batch.commit();
    await recalculateWallet(req.userId);
    await safeAppendAudit(
      request.auth.uid,
      "admin",
      "completeWithdrawal",
      "withdrawal_request",
      requestId,
      null,
      {
        status: "completed",
      },
    );

    const cAmt = Number(req.amount) || 0;
    await safeNotify(() =>
      sendCustomerTransactionAlerts(req.userId, {
        title: "Withdrawal completed",
        body: `Your withdrawal of PKR ${cAmt.toFixed(0)} has been completed.`,
        type: "withdrawal",
        category: "wallet",
        action: "open_wallet",
        refId: requestId,
        amount: cAmt,
        currency: "PKR",
      }),
    );

    return { ok: true };
  },
);

/** Admin: reject/cancel withdrawal from pending */
exports.rejectWithdrawal = onCall(
  { region: "us-central1" },
  async (request) => {
    if (!request.auth?.uid)
      throw new HttpsError("unauthenticated", "Sign in required.");
    await assertAdmin(request.auth.uid);
    const { requestId, reason } = request.data || {};
    if (!requestId)
      throw new HttpsError("invalid-argument", "requestId required.");

    const reqSnap = await db()
      .collection("withdrawal_requests")
      .doc(requestId)
      .get();
    if (!reqSnap.exists)
      throw new HttpsError("not-found", "Request not found.");
    const req = reqSnap.data();
    if (req.status !== "pending" && req.status !== "approved") {
      throw new HttpsError(
        "failed-precondition",
        "Request cannot be cancelled.",
      );
    }
    const tid = req.transactionId;
    const tRef = db().collection("transactions").doc(tid);
    const now = admin.firestore.FieldValue.serverTimestamp();

    const batch = db().batch();
    batch.update(reqSnap.ref, {
      status: "cancelled",
      updatedAt: now,
      adminNote: reason || null,
    });
    batch.update(tRef, {
      status: "cancelled",
      updatedAt: now,
      notes: reason || "cancelled",
    });
    await batch.commit();
    await recalculateWallet(req.userId);
    await safeAppendAudit(
      request.auth.uid,
      "admin",
      "rejectWithdrawal",
      "withdrawal_request",
      requestId,
      null,
      {
        reason,
      },
    );

    const rAmt = Number(req.amount) || 0;
    const rNote = reason ? String(reason).trim() : "";
    await safeNotify(() =>
      sendCustomerTransactionAlerts(req.userId, {
        title: "Withdrawal cancelled",
        body: rNote.length
          ? `Your withdrawal of PKR ${rAmt.toFixed(0)} was cancelled. ${rNote}`
          : `Your withdrawal of PKR ${rAmt.toFixed(0)} was cancelled.`,
        type: "withdrawal",
        category: "wallet",
        action: "open_wallet",
        refId: requestId,
        amount: rAmt,
        currency: "PKR",
      }),
    );

    return { ok: true };
  },
);

/** Admin: profit entry */
exports.addProfitEntry = onCall({ region: "us-central1" }, async (request) => {
  if (!request.auth?.uid)
    throw new HttpsError("unauthenticated", "Sign in required.");
  await assertAdmin(request.auth.uid);
  const { userId, amount, note } = request.data || {};
  if (!userId) throw new HttpsError("invalid-argument", "userId required.");
  const amt = Number(amount);
  if (!amt || amt <= 0)
    throw new HttpsError("invalid-argument", "Invalid amount.");

  const tid = txId();
  const tRef = db().collection("transactions").doc(tid);
  const now = admin.firestore.FieldValue.serverTimestamp();
  await tRef.set({
    id: tid,
    userId,
    type: "profit",
    amount: amt,
    status: "approved",
    createdAt: now,
    updatedAt: now,
    notes: note || "profit",
    approvedBy: request.auth.uid,
  });
  await recalculateWallet(userId);
  await safeAppendAudit(
    request.auth.uid,
    "admin",
    "addProfitEntry",
    "transaction",
    tid,
    null,
    { userId, amount: amt },
  );

  await safeNotify(() =>
    sendCustomerTransactionAlerts(userId, {
      title: "Profit credited",
      body: `PKR ${amt.toFixed(0)} has been added to your wallet.`,
      type: "profit",
      category: "wallet",
      action: "open_wallet",
      refId: tid,
      amount: amt,
      currency: "PKR",
    }),
  );

  return { transactionId: tid };
});

/** Admin: adjustment entry (signed amount) */
exports.addAdjustmentEntry = onCall(
  {
    region: "us-central1",
    // Lower CPU to stay under Cloud Run regional vCPU quota (Gen2 = Cloud Run).
    memory: "256MiB",
    cpu: 0.08,
  },
  async (request) => {
    if (!request.auth?.uid)
      throw new HttpsError("unauthenticated", "Sign in required.");
    await assertAdmin(request.auth.uid);
    const { userId, amount, note } = request.data || {};
    if (!userId) throw new HttpsError("invalid-argument", "userId required.");
    const amt = Number(amount);
    if (Number.isNaN(amt) || amt === 0)
      throw new HttpsError("invalid-argument", "Invalid adjustment amount.");
    if (!note || String(note).trim().length < 3) {
      throw new HttpsError(
        "invalid-argument",
        "Note required for adjustments.",
      );
    }

    const tid = txId();
    const tRef = db().collection("transactions").doc(tid);
    const now = admin.firestore.FieldValue.serverTimestamp();
    await tRef.set({
      id: tid,
      userId,
      type: "adjustment",
      amount: Math.abs(amt) * (amt < 0 ? -1 : 1),
      status: "approved",
      createdAt: now,
      updatedAt: now,
      notes: note.trim(),
      approvedBy: request.auth.uid,
    });
    await recalculateWallet(userId);
    await safeAppendAudit(
      request.auth.uid,
      "admin",
      "addAdjustmentEntry",
      "transaction",
      tid,
      null,
      {
        userId,
        amount: amt,
      },
    );

    await safeNotify(() =>
      sendCustomerTransactionAlerts(userId, {
        title: "Wallet adjustment applied",
        body: `An adjustment of PKR ${Math.abs(amt).toFixed(0)} has been applied to your wallet.`,
        type: "adjustment",
        category: "wallet",
        action: "open_wallet",
        refId: tid,
        amount: amt,
        currency: "PKR",
      }),
    );

    return { transactionId: tid };
  },
);

/** Admin: recompute wallet for a user (repair) */
exports.recalculateWalletForUser = onCall(
  { region: "us-central1" },
  async (request) => {
    if (!request.auth?.uid)
      throw new HttpsError("unauthenticated", "Sign in required.");
    await assertAdmin(request.auth.uid);
    const userId = request.data?.userId;
    if (!userId) throw new HttpsError("invalid-argument", "userId required.");
    await recalculateWallet(userId);
    return { ok: true };
  },
);

/** Admin: approve a transaction (deposit or withdrawal).
 * Legacy queue compatibility:
 * - deposits: pending -> approved
 * - withdrawals: pending -> completed (legacy queue has no separate settle step)
 */
exports.adminApproveTransaction = onCall(
  {
    region: "us-central1",
    // Lower CPU to stay under per-region Cloud Run CPU quota on deploy.
    cpu: 0.5,
    memory: "256MiB",
    concurrency: 1,
  },
  async (request) => {
    if (!request.auth?.uid)
      throw new HttpsError("unauthenticated", "Sign in required.");
    await assertAdmin(request.auth.uid);

    const { txnId } = request.data || {};
    if (!txnId) throw new HttpsError("invalid-argument", "txnId required.");

    const txRef = db().collection("transactions").doc(txnId);
    const txSnap = await txRef.get();
    if (!txSnap.exists)
      throw new HttpsError("not-found", "Transaction not found.");

    const txData = txSnap.data();
    const status = (txData.status || "").toLowerCase();
    if (status !== "pending") {
      throw new HttpsError(
        "failed-precondition",
        `Transaction is already ${status}.`,
      );
    }

    const userId = txData.userId;
    const amount = Number(txData.amount) || 0;
    const type = (txData.type || "").toLowerCase();
    const now = admin.firestore.FieldValue.serverTimestamp();
    const adminUid = request.auth.uid;

    const batch = db().batch();

    // Legacy behavior is type-specific:
    // deposit -> approved, withdrawal -> completed.
    const nextStatus = type === "withdrawal" ? "completed" : "approved";
    batch.update(txRef, {
      status: nextStatus,
      approvedAt: now,
      approvedBy: adminUid,
      ...(type === "withdrawal"
        ? {
            completedAt: now,
            completedBy: adminUid,
            notes: "completed_via_legacy_admin_approve",
          }
        : {}),
    });

    const userRef = db().collection("users").doc(userId);

    if (type === "deposit") {
      batch.set(
        userRef,
        {
          balance: admin.firestore.FieldValue.increment(amount),
          totalDeposited: admin.firestore.FieldValue.increment(amount),
        },
        { merge: true },
      );
    } else if (type === "withdrawal") {
      // Check balance first
      const userSnap = await userRef.get();
      const currentBalance = Number(userSnap.data()?.balance) || 0;
      if (currentBalance < amount) {
        throw new HttpsError(
          "failed-precondition",
          `Insufficient balance. Current: PKR ${currentBalance.toFixed(0)}, withdrawal: PKR ${amount.toFixed(0)}`,
        );
      }
      batch.set(
        userRef,
        {
          balance: admin.firestore.FieldValue.increment(-amount),
          totalWithdrawn: admin.firestore.FieldValue.increment(amount),
        },
        { merge: true },
      );
    }

    await batch.commit();
    await recalculateWallet(userId);

    let feesApplied = [];
    if (type === "deposit") {
      try {
        const result = await applyDepositFees({
          uid: userId,
          depositTxId: txnId,
          depositAmount: amount,
          approverUid: adminUid,
        });
        feesApplied = result.applied || [];
      } catch (e) {
        logger.warn("adminApproveTransaction_applyDepositFees_failed", {
          uid: userId,
          txnId,
          error: String(e),
        });
      }
    }

    await safeAppendAudit(
      adminUid,
      "admin",
      "adminApproveTransaction",
      "transaction",
      txnId,
      { status: "pending" },
      { status: nextStatus, type, amount, feesApplied },
    );

    const label =
      type === "deposit"
        ? "Deposit approved"
        : type === "withdrawal"
          ? "Withdrawal completed"
          : "Transaction approved";
    const body =
      type === "deposit"
        ? `Your deposit of PKR ${amount.toFixed(0)} has been approved.`
        : type === "withdrawal"
          ? `Your withdrawal of PKR ${amount.toFixed(0)} has been completed.`
          : `A transaction of PKR ${amount.toFixed(0)} was approved.`;
    await safeNotify(() =>
      sendCustomerTransactionAlerts(userId, {
        title: label,
        body,
        type: type || "transaction",
        category: "wallet",
        action: "open_wallet",
        refId: txnId,
        amount,
        currency: "PKR",
      }),
    );

    return { ok: true };
  },
);

/** Admin: repair legacy approved-withdrawal records that should be completed. */
exports.repairApprovedWithdrawals = onCall(
  { region: "us-central1" },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Sign in required.");
    }
    await assertAdmin(request.auth.uid);

    const dryRun = request.data?.dryRun !== false;
    const maxCandidatesRaw = Number(request.data?.maxCandidates);
    const maxCandidates =
      Number.isFinite(maxCandidatesRaw) && maxCandidatesRaw > 0
        ? Math.min(Math.floor(maxCandidatesRaw), 2000)
        : 500;

    const txSnap = await db()
      .collection("transactions")
      .where("type", "==", "withdrawal")
      .where("status", "==", "approved")
      .limit(maxCandidates)
      .get();

    const candidates = txSnap.docs.filter((doc) => {
      const d = doc.data() || {};
      // Skip records that already look explicitly settled.
      return !d.settlementRef && !d.completedAt && !d.completedBy;
    });

    const affectedUsers = new Set();
    for (const doc of candidates) {
      const uid = String(doc.data()?.userId || "").trim();
      if (uid) affectedUsers.add(uid);
    }

    if (dryRun) {
      await safeAppendAudit(
        request.auth.uid,
        "admin",
        "repairApprovedWithdrawalsDryRun",
        "transaction",
        "bulk",
        null,
        {
          scanned: txSnap.size,
          candidates: candidates.length,
          affectedUsers: affectedUsers.size,
        },
      );
      return {
        ok: true,
        dryRun: true,
        scanned: txSnap.size,
        candidates: candidates.length,
        candidateTxnIds: candidates.map((d) => d.id),
        affectedUsers: [...affectedUsers],
      };
    }

    let updatedCount = 0;
    for (const doc of candidates) {
      await doc.ref.update({
        status: "completed",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
        completedBy: request.auth.uid,
        notes: "completed_via_repairApprovedWithdrawals",
      });
      updatedCount++;
    }

    for (const uid of affectedUsers) {
      await recalculateWallet(uid);
    }

    await safeAppendAudit(
      request.auth.uid,
      "admin",
      "repairApprovedWithdrawals",
      "transaction",
      "bulk",
      null,
      {
        scanned: txSnap.size,
        candidates: candidates.length,
        updated: updatedCount,
        affectedUsers: affectedUsers.size,
      },
    );

    return {
      ok: true,
      dryRun: false,
      scanned: txSnap.size,
      candidates: candidates.length,
      updated: updatedCount,
      affectedUsers: [...affectedUsers],
    };
  },
);

/** Admin: reject a transaction */
exports.adminRejectTransaction = onCall(
  { region: "us-central1" },
  async (request) => {
    if (!request.auth?.uid)
      throw new HttpsError("unauthenticated", "Sign in required.");
    await assertAdmin(request.auth.uid);

    const { txnId, rejectionNote } = request.data || {};
    if (!txnId) throw new HttpsError("invalid-argument", "txnId required.");

    const txRef = db().collection("transactions").doc(txnId);
    const txSnap = await txRef.get();
    if (!txSnap.exists)
      throw new HttpsError("not-found", "Transaction not found.");

    const txData = txSnap.data();
    const status = (txData.status || "").toLowerCase();
    if (status !== "pending") {
      throw new HttpsError(
        "failed-precondition",
        `Transaction is already ${status}.`,
      );
    }

    const userId = txData.userId;
    const now = admin.firestore.FieldValue.serverTimestamp();
    const adminUid = request.auth.uid;

    await txRef.update({
      status: "rejected",
      rejectedAt: now,
      rejectedBy: adminUid,
      rejectionNote: rejectionNote ? String(rejectionNote).trim() : "",
    });

    await recalculateWallet(userId);
    await safeAppendAudit(
      adminUid,
      "admin",
      "adminRejectTransaction",
      "transaction",
      txnId,
      { status: "pending" },
      { status: "rejected", rejectionNote },
    );

    const txAmt = Number(txData.amount) || 0;
    const txType = (txData.type || "").toLowerCase();
    const note = rejectionNote ? String(rejectionNote).trim() : "";
    await safeNotify(() =>
      sendCustomerTransactionAlerts(userId, {
        title: "Transaction not approved",
        body: note.length
          ? `Your ${txType || "transaction"} of PKR ${txAmt.toFixed(0)} was not approved. ${note}`
          : `Your ${txType || "transaction"} of PKR ${txAmt.toFixed(0)} was not approved.`,
        type: txType || "transaction",
        category: "wallet",
        action: "open_wallet",
        refId: txnId,
        amount: txAmt,
        currency: "PKR",
      }),
    );

    return { ok: true };
  },
);

/** Admin: apply percentage return to ALL portfolios */
exports.applyMonthlyReturns = onCall(
  { region: "us-central1" },
  async (request) => {
    if (!request.auth?.uid)
      throw new HttpsError("unauthenticated", "Sign in required.");
    await assertAdmin(request.auth.uid);

    const returnPct = Number(request.data?.returnPct);
    if (!returnPct || returnPct <= 0 || returnPct > 100) {
      throw new HttpsError(
        "invalid-argument",
        "returnPct must be between 0 and 100.",
      );
    }

    const adminUid = request.auth.uid;
    const now = admin.firestore.FieldValue.serverTimestamp();
    const feeConfig = await getFeeConfigInternal();
    const portfoliosSnap = await db().collection("portfolios").get();

    // Manual returns are applied for the current calendar month.
    const ymKey = (() => {
      const d = new Date();
      const y = d.getUTCFullYear();
      const m = String(d.getUTCMonth() + 1).padStart(2, "0");
      return `${y}-${m}`;
    })();

    let successCount = 0;
    let failCount = 0;
    let totalGrossProfit = 0;
    let totalNetProfit = 0;
    let totalManagementFee = 0;
    let totalPerformanceFee = 0;
    const errors = [];

    for (const portfolioDoc of portfoliosSnap.docs) {
      const uid = portfolioDoc.id;
      try {
        const data = portfolioDoc.data();
        const previousValue = Number(data.currentValue) || 0;
        if (previousValue <= 0) continue; // skip empty portfolios

        const grossProfit = previousValue * (returnPct / 100);
        const newValue = previousValue + grossProfit;

        const batch = db().batch();

        batch.update(portfolioDoc.ref, {
          currentValue: newValue,
          lastMonthlyReturnPct: returnPct,
          lastUpdated: now,
        });

        const histRef = db()
          .collection("portfolios")
          .doc(uid)
          .collection("returnHistory")
          .doc();
        batch.set(histRef, {
          returnPct,
          profitAmount: grossProfit,
          previousValue,
          newValue,
          appliedAt: now,
          appliedBy: adminUid,
          mode: "percentage",
        });

        const result = await bookMonthEndFeesAndProfit({
          uid,
          grossProfit,
          monthlyPct: returnPct,
          annualRatePct: returnPct * 12,
          periodKey: ymKey,
          approverUid: adminUid,
          batch,
          now,
          feeConfig,
        });

        await batch.commit();
        await recalculateWallet(uid);

        totalGrossProfit += result.grossProfit;
        totalNetProfit += result.netProfit;
        totalManagementFee += result.managementFee;
        totalPerformanceFee += result.performanceFee;
        successCount++;

        await safeNotify(() =>
          sendCustomerTransactionAlerts(uid, {
            title: "Monthly return applied",
            body: `PKR ${result.netProfit.toFixed(0)} net profit credited (${returnPct}% gross). Fees: PKR ${(result.performanceFee + result.managementFee).toFixed(0)}.`,
            type: "profit_entry",
            category: "portfolio",
            action: "open_portfolio",
            refId: uid,
            amount: result.netProfit,
            currency: "PKR",
          }),
        );
      } catch (e) {
        failCount++;
        errors.push(`${uid}: ${String(e)}`);
        logger.error("applyMonthlyReturns user failed", {
          uid,
          error: String(e),
        });
      }
    }

    if (totalManagementFee > 0 || totalPerformanceFee > 0) {
      try {
        const { bumpCompanyEarnings } = require("./fees");
        await bumpCompanyEarnings(ymKey, {
          management: totalManagementFee,
          performance: totalPerformanceFee,
        });
      } catch (e) {
        logger.warn("applyMonthlyReturns_bumpCompanyEarnings_failed", {
          error: String(e),
        });
      }
    }

    await safeAppendAudit(
      adminUid,
      "admin",
      "applyMonthlyReturns",
      "portfolios",
      "all",
      null,
      {
        returnPct,
        successCount,
        failCount,
        totalGrossProfit,
        totalNetProfit,
        totalManagementFee,
        totalPerformanceFee,
      },
    );

    return {
      successCount,
      failCount,
      totalProfit: totalNetProfit,
      totalGrossProfit,
      totalManagementFee,
      totalPerformanceFee,
      errors,
    };
  },
);

/** Admin: save live projection configuration used by investor live profit UI */
exports.saveReturnsProjectionConfig = onCall(
  { region: "us-central1" },
  async (request) => {
    try {
      if (!request.auth?.uid) {
        throw new HttpsError("unauthenticated", "Sign in required.");
      }
      await assertAdmin(request.auth.uid);

      const rate = Number(request.data?.globalAnnualRatePct);
      if (!Number.isFinite(rate) || rate < 0 || rate > 100) {
        throw new HttpsError(
          "invalid-argument",
          "globalAnnualRatePct must be between 0 and 100.",
        );
      }

      await db().collection("settings").doc("returns_projection").set(
        {
          globalAnnualRatePct: rate,
          isEnabled: true,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedBy: request.auth.uid,
        },
        { merge: true },
      );

      return { ok: true };
    } catch (error) {
      logger.error("saveReturnsProjectionConfig_failed", {
        uid: request.auth?.uid || null,
        error: String(error),
      });
      if (error instanceof HttpsError) {
        throw error;
      }
      throw new HttpsError(
        "internal",
        "Unable to save projection settings. Check function deployment and admin access.",
      );
    }
  },
);

/** Investor/Admin: read live projection configuration via Admin SDK */
exports.getReturnsProjectionConfig = onCall(
  { region: "us-central1" },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Sign in required.");
    }
    const snap = await db().collection("settings").doc("returns_projection").get();
    const data = snap.data() || {};
    const rate = Number(data.globalAnnualRatePct ?? data.annualRatePct ?? 0);
    return {
      globalAnnualRatePct: Number.isFinite(rate) ? rate : 0,
      isEnabled: data.isEnabled === true,
      exists: snap.exists,
    };
  },
);

/** Admin: manual trigger or dry-run for month-end profit automation. */
exports.triggerMonthEndProfitCredit = onCall(
  { region: "us-central1" },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Sign in required.");
    }
    await assertAdmin(request.auth.uid);
    const dryRun = request.data?.dryRun !== false;
    const monthKey = String(request.data?.monthKey || "").trim();
    return runMonthEndProfitCredit({
      dryRun,
      requestedBy: request.auth.uid,
      forceMonthKey: monthKey || undefined,
    });
  },
);

/**
 * Admin: one-time repair — recalculates every user's wallet from their
 * transaction ledger and writes corrected values to wallets/{uid}.
 * Returns a summary of what was changed.
 */
exports.repairUserBalances = onCall(
  { region: "us-central1" },
  async (request) => {
    if (!request.auth?.uid)
      throw new HttpsError("unauthenticated", "Sign in required.");
    await assertAdmin(request.auth.uid);

    const usersSnap = await db().collection("users").get();
    const results = [];
    let fixedCount = 0;
    let errorCount = 0;

    for (const userDoc of usersSnap.docs) {
      const uid = userDoc.id;
      const userName = userDoc.data().name || userDoc.data().email || uid;
      try {
        // Read old wallet values before repair
        const oldWallet =
          (await db().collection("wallets").doc(uid).get()).data() || {};
        const oldBalance = Number(oldWallet.availableBalance) || 0;
        const oldWithdrawn = Number(oldWallet.totalWithdrawn) || 0;

        // Recalculate from transaction ledger
        await recalculateWallet(uid);

        // Read new values
        const newWallet =
          (await db().collection("wallets").doc(uid).get()).data() || {};
        const newBalance = Number(newWallet.availableBalance) || 0;
        const newWithdrawn = Number(newWallet.totalWithdrawn) || 0;

        const balanceChanged = Math.abs(oldBalance - newBalance) > 0.01;
        const withdrawnChanged = Math.abs(oldWithdrawn - newWithdrawn) > 0.01;

        if (balanceChanged || withdrawnChanged) {
          fixedCount++;
          results.push({
            uid,
            name: userName,
            balanceBefore: oldBalance,
            balanceAfter: newBalance,
            withdrawnBefore: oldWithdrawn,
            withdrawnAfter: newWithdrawn,
            changed: true,
          });
          logger.info("repairUserBalances: fixed", {
            uid,
            userName,
            balanceBefore: oldBalance,
            balanceAfter: newBalance,
            withdrawnBefore: oldWithdrawn,
            withdrawnAfter: newWithdrawn,
          });
        } else {
          results.push({ uid, name: userName, changed: false });
        }
      } catch (err) {
        errorCount++;
        logger.error("repairUserBalances: error for user", {
          uid,
          error: String(err),
        });
        results.push({ uid, name: userName, error: String(err) });
      }
    }

    return {
      totalUsers: usersSnap.size,
      fixedCount,
      errorCount,
      results,
    };
  },
);

/** Nightly reconciliation: log mismatches */
exports.reconcileWalletsDaily = onSchedule("0 3 * * *", async () => {
  let cursor = null;
  while (true) {
    let q = db()
      .collection("users")
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(500);
    if (cursor) q = q.startAfter(cursor);
    const usersSnap = await q.get();
    if (usersSnap.empty) break;

    for (const doc of usersSnap.docs) {
      const uid = doc.id;
      const wBefore = (await db().collection("wallets").doc(uid).get()).data();
      await recalculateWallet(uid);
      const wAfter = (await db().collection("wallets").doc(uid).get()).data();
      if (
        wBefore &&
        wAfter &&
        Math.abs(
          (wBefore.availableBalance || 0) - (wAfter.availableBalance || 0),
        ) > 0.01
      ) {
        logger.info("Wallet recalculated", {
          uid,
          before: wBefore,
          after: wAfter,
        });
      }
    }

    cursor = usersSnap.docs[usersSnap.docs.length - 1];
  }
});

/** Calendar month-end automation: credits monthly profit from annual rate. */
exports.applyMonthEndProfitCredits = onSchedule("10 0 * * *", async () => {
  const now = new Date();
  if (!isCalendarMonthEnd(now)) {
    return;
  }
  await runMonthEndProfitCredit({
    dryRun: false,
    requestedBy: "system_scheduler",
    now,
  });
});

/** One-time: set CORS on the Storage bucket so Flutter Web can load images. */
exports.setStorageCors = onCall({ region: "us-central1" }, async (request) => {
  if (!request.auth?.uid)
    throw new HttpsError("unauthenticated", "Sign in required.");
  await assertAdmin(request.auth.uid);

  const bucketName = "portfolio-e97b1.firebasestorage.app";
  const bucket = admin.storage().bucket(bucketName);
  await bucket.setCorsConfiguration([
    {
      origin: ["*"],
      method: ["GET", "HEAD", "PUT", "OPTIONS"],
      maxAgeSeconds: 3600,
      responseHeader: [
        "Content-Type",
        "Authorization",
        "Content-Length",
        "User-Agent",
        "x-goog-resumable",
        "x-goog-content-length-range",
        "x-goog-hash",
      ],
    },
  ]);

  const [metadata] = await bucket.getMetadata();
  return { ok: true, cors: metadata.cors };
});

/** Admin: fetch storage image bytes safely (CORS-proof for web). */
exports.getStorageImageData = onCall(
  { region: "us-central1" },
  async (request) => {
    if (!request.auth?.uid)
      throw new HttpsError("unauthenticated", "Sign in required.");
    await assertAdmin(request.auth.uid);

    const rawUrl = String(request.data?.rawUrl || "").trim();
    if (!rawUrl)
      throw new HttpsError("invalid-argument", "rawUrl is required.");

    let bucketName = null;
    let objectPath = null;

    if (rawUrl.startsWith("gs://")) {
      // gs://bucket/path/to/file.jpg
      const withoutScheme = rawUrl.replace("gs://", "");
      const slashIndex = withoutScheme.indexOf("/");
      if (slashIndex > 0) {
        bucketName = withoutScheme.slice(0, slashIndex);
        objectPath = withoutScheme.slice(slashIndex + 1);
      }
    } else if (rawUrl.startsWith("https://firebasestorage.googleapis.com")) {
      // https://firebasestorage.googleapis.com/v0/b/{bucket}/o/{encodedPath}?...
      const url = new URL(rawUrl);
      const segments = url.pathname.split("/").filter(Boolean);
      const bIndex = segments.indexOf("b");
      const oIndex = segments.indexOf("o");
      if (bIndex !== -1 && bIndex + 1 < segments.length) {
        bucketName = segments[bIndex + 1];
      }
      if (oIndex !== -1 && oIndex + 1 < segments.length) {
        objectPath = decodeURIComponent(segments.slice(oIndex + 1).join("/"));
      }
    } else {
      // Plain object path; use default bucket
      objectPath = rawUrl;
    }

    if (!objectPath) {
      throw new HttpsError(
        "invalid-argument",
        "Could not parse storage object path.",
      );
    }

    const bucket = bucketName
      ? admin.storage().bucket(bucketName)
      : admin.storage().bucket();
    const file = bucket.file(objectPath);

    const [exists] = await file.exists();
    if (!exists) throw new HttpsError("not-found", "Image file not found.");

    const [metadata] = await file.getMetadata();
    const [buffer] = await file.download();

    return {
      ok: true,
      bytesBase64: buffer.toString("base64"),
      contentType: metadata.contentType || "image/jpeg",
    };
  },
);

/**
 * Admin: POST raw PDF bytes with Authorization: Bearer <Firebase ID token>.
 * Uses Admin SDK file.save() — avoids getSignedUrl() which needs iam.serviceAccounts.signBlob
 * (often missing on Cloud Functions SA and surfaces as HTTP 500).
 */
exports.uploadInvestorReportHttp = onRequest(
  {
    region: "us-central1",
    cors: true,
    memory: "512MiB",
    // Default for 512MiB is 1 vCPU; cap to reduce regional CPU quota usage.
    cpu: 0.5,
    timeoutSeconds: 120,
    invoker: "public",
  },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).json({ error: "POST only" });
      return;
    }
    try {
      const authHeader = req.headers.authorization;
      if (!authHeader || !authHeader.startsWith("Bearer ")) {
        res.status(401).json({ error: "Sign in required." });
        return;
      }
      const idToken = authHeader.slice(7);
      let decoded;
      try {
        decoded = await admin.auth().verifyIdToken(idToken);
      } catch (e) {
        logger.warn("uploadInvestorReportHttp_bad_token", { err: String(e) });
        res.status(401).json({ error: "Invalid session token." });
        return;
      }
      await assertAdmin(decoded.uid);

      const buffer = await getPdfBuffer(req);
      if (buffer.length === 0) {
        res.status(400).json({ error: "Empty PDF body." });
        return;
      }
      if (buffer.length > 25 * 1024 * 1024) {
        res.status(400).json({ error: "PDF must be 25 MB or smaller." });
        return;
      }

      const bucket = admin.storage().bucket();
      const id = `${Date.now()}_${Math.random().toString(36).slice(2, 12)}`;
      const objectPath = `reports/${id}.pdf`;
      const file = bucket.file(objectPath);
      await file.save(buffer, {
        metadata: { contentType: "application/pdf" },
        resumable: false,
      });

      res.status(200).json({ ok: true, storagePath: objectPath });
    } catch (e) {
      logger.error("uploadInvestorReportHttp", {
        err: String(e),
        stack: e.stack,
      });
      if (e instanceof HttpsError) {
        res.status(e.httpErrorCode?.status ?? 500).json({ error: e.message });
        return;
      }
      res.status(500).json({ error: "Upload failed." });
    }
  },
);

/**
 * Admin: POST raw APK bytes with Authorization: Bearer <Firebase ID token>.
 * Stores object in Cloud Storage and returns storage path.
 */
exports.uploadAndroidReleaseApkHttp = onRequest(
  {
    region: "us-central1",
    cors: true,
    memory: "512MiB",
    cpu: 0.5,
    timeoutSeconds: 180,
    invoker: "public",
  },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).json({ error: "POST only" });
      return;
    }
    try {
      const authHeader = req.headers.authorization;
      if (!authHeader || !authHeader.startsWith("Bearer ")) {
        res.status(401).json({ error: "Sign in required." });
        return;
      }
      const versionCodeRaw = String(req.query.versionCode || "").trim();
      const versionCode = Number(versionCodeRaw);
      if (!versionCodeRaw || !Number.isFinite(versionCode) || versionCode <= 0) {
        res.status(400).json({ error: "versionCode query param is required." });
        return;
      }

      const idToken = authHeader.slice(7);
      let decoded;
      try {
        decoded = await admin.auth().verifyIdToken(idToken);
      } catch (e) {
        logger.warn("uploadAndroidReleaseApkHttp_bad_token", { err: String(e) });
        res.status(401).json({ error: "Invalid session token." });
        return;
      }
      await assertAdmin(decoded.uid);

      const buffer = await getBinaryBuffer(req);
      if (buffer.length === 0) {
        res.status(400).json({ error: "Empty APK body." });
        return;
      }
      if (buffer.length > 200 * 1024 * 1024) {
        res.status(400).json({ error: "APK must be 200 MB or smaller." });
        return;
      }
      const contentType = String(req.headers["content-type"] || "").toLowerCase();
      if (contentType && !contentType.includes("application/vnd.android.package-archive")) {
        logger.warn("uploadAndroidReleaseApkHttp_content_type", { contentType });
      }

      const bucket = admin.storage().bucket();
      const id = `${Date.now()}_${Math.random().toString(36).slice(2, 12)}`;
      const objectPath = `releases/android/${versionCode}/${id}.apk`;
      const file = bucket.file(objectPath);
      await file.save(buffer, {
        metadata: { contentType: "application/vnd.android.package-archive" },
        resumable: false,
      });

      res.status(200).json({ ok: true, storagePath: objectPath });
    } catch (e) {
      logger.error("uploadAndroidReleaseApkHttp", {
        err: String(e),
        stack: e.stack,
      });
      if (e instanceof HttpsError) {
        res.status(e.httpErrorCode?.status ?? 500).json({ error: e.message });
        return;
      }
      res.status(500).json({ error: "APK upload failed." });
    }
  },
);

/**
 * Admin: disable investor account access while preserving financial history.
 * Deletes Firebase Auth user and marks users/{uid} as deleted/anonymized.
 */
exports.deleteInvestorAccount = onCall(
  { region: "us-central1", invoker: "public" },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Sign in required.");
    }
    await assertAdmin(request.auth.uid);

    const userId = String(request.data?.userId || "").trim();
    const reason = String(request.data?.reason || "").trim();
    if (!userId) {
      throw new HttpsError("invalid-argument", "userId required.");
    }
    if (userId === request.auth.uid) {
      throw new HttpsError(
        "failed-precondition",
        "You cannot delete your own admin account.",
      );
    }

    const now = admin.firestore.FieldValue.serverTimestamp();
    const userRef = db().collection("users").doc(userId);
    const userSnap = await userRef.get();
    const existing = userSnap.data() || {};
    const existingRole = String(existing.role || "").toLowerCase();
    if (existingRole === "admin" || existingRole === "crm" || existingRole === "team") {
      throw new HttpsError(
        "failed-precondition",
        "Staff accounts cannot be deleted from investor panel.",
      );
    }

    try {
      await admin.auth().deleteUser(userId);
    } catch (e) {
      const code = e.errorInfo?.code || e.code || "";
      if (code !== "auth/user-not-found") {
        logger.error("deleteInvestorAccount_deleteUser_failed", {
          userId,
          err: String(e),
          code,
        });
        throw new HttpsError("internal", "Failed to delete auth user.");
      }
    }

    const anonymizedEmail = `deleted_${userId}@deleted.local`;
    await userRef.set(
      {
        deleted: true,
        deletedAt: now,
        deletedBy: request.auth.uid,
        deleteReason: reason,
        name: "Deleted investor",
        email: anonymizedEmail,
        phone: "",
      },
      { merge: true },
    );

    await safeAppendAudit(
      request.auth.uid,
      "admin",
      "deleteInvestorAccount",
      "user",
      userId,
      null,
      { reason: reason || null },
    );

    return { ok: true, userId };
  },
);

/**
 * Admin-only: create a Firebase Auth user and Firestore profile with role "crm".
 * invoker: "public" — required for 2nd gen callables on Flutter Web so Cloud Run
 * accepts OPTIONS/POST (browser preflight); auth is still enforced via request.auth.
 */
exports.createCrmUser = onCall(
  { region: "us-central1", invoker: "public" },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Sign in required.");
    }
    await assertAdmin(request.auth.uid);

    const email = (request.data?.email ?? "").trim();
    const password = request.data?.password ?? "";
    const displayName = (request.data?.displayName ?? "").trim();
    if (!email) {
      throw new HttpsError("invalid-argument", "email is required.");
    }
    if (password.length < 6) {
      throw new HttpsError(
        "invalid-argument",
        "Password must be at least 6 characters.",
      );
    }

    let userRecord;
    try {
      userRecord = await admin.auth().createUser({
        email,
        password,
        displayName: displayName || undefined,
      });
    } catch (e) {
      const code = e.errorInfo?.code || e.code;
      logger.error("createCrmUser_auth", { err: String(e), code });
      if (code === "auth/email-already-exists") {
        throw new HttpsError(
          "already-exists",
          "This email is already registered.",
        );
      }
      if (code === "auth/invalid-email") {
        throw new HttpsError("invalid-argument", "Invalid email address.");
      }
      if (code === "auth/weak-password") {
        throw new HttpsError("invalid-argument", "Password is too weak.");
      }
      throw new HttpsError("internal", "Could not create account.");
    }

    const uid = userRecord.uid;
    const name =
      displayName || (email.includes("@") ? email.split("@")[0] : "CRM");

    try {
      await db()
        .collection("users")
        .doc(uid)
        .set({
          email,
          name,
          role: "crm",
          kycStatus: "pending",
          phone: "",
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
    } catch (e) {
      logger.error("createCrmUser_firestore", { err: String(e), uid });
      try {
        await admin.auth().deleteUser(uid);
      } catch (delErr) {
        logger.warn("createCrmUser_rollback_auth_failed", {
          err: String(delErr),
          uid,
        });
      }
      throw new HttpsError("internal", "Could not save user profile.");
    }

    return { uid, email };
  },
);
