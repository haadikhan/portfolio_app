/**
 * Wallet & ledger: server-side source of truth.
 * All mutations go through these callables + Admin SDK.
 */

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const { logger } = require("firebase-functions");
const { recalculateWallet, appendAudit } = require("./wallet_helpers");

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

async function assertKycApproved(uid) {
  const k = await db().collection("kyc").doc(uid).get();
  const kyc = (k.data()?.status || "pending").toLowerCase();
  if (kyc !== "approved") {
    throw new HttpsError("failed-precondition", "KYC must be approved.");
  }
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

  for (const doc of docs) {
    const d = doc.data ? doc.data() : doc;
    const amt = Number(d.amount) || 0;
    const st = (d.status || "").toLowerCase();
    const ty = (d.type || "").toLowerCase();

    if (ty === "deposit" && st === "approved") totalDeposited += amt;
    if (ty === "withdrawal") {
      // Only "pending" withdrawals are reserved; "approved"/"completed" are fully settled
      if (st === "pending") reservedAmount += amt;
      else if (st === "approved" || st === "completed") totalWithdrawn += amt;
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
  return { availableBalance };
}

async function safeAppendAudit(...args) {
  try {
    await appendAudit(...args);
  } catch (e) {
    logger.error("audit_log_failed", { error: String(e), args });
  }
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
  await safeAppendAudit(
    request.auth.uid,
    "admin",
    "approveDeposit",
    "deposit_request",
    requestId,
    { status: "pending" },
    { status: "approved", transactionId: tid },
  );

  return { ok: true };
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

  return { transactionId: tid };
});

/** Admin: adjustment entry (signed amount) */
exports.addAdjustmentEntry = onCall(
  { region: "us-central1" },
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

/** Admin: approve a transaction (deposit or withdrawal) */
exports.adminApproveTransaction = onCall(
  { region: "us-central1" },
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

    // Mark transaction approved
    batch.update(txRef, {
      status: "approved",
      approvedAt: now,
      approvedBy: adminUid,
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
    await safeAppendAudit(
      adminUid,
      "admin",
      "adminApproveTransaction",
      "transaction",
      txnId,
      { status: "pending" },
      { status: "approved", type, amount },
    );

    return { ok: true };
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
    const portfoliosSnap = await db().collection("portfolios").get();

    let successCount = 0;
    let failCount = 0;
    let totalProfit = 0;
    const errors = [];

    for (const portfolioDoc of portfoliosSnap.docs) {
      const uid = portfolioDoc.id;
      try {
        const data = portfolioDoc.data();
        const previousValue = Number(data.currentValue) || 0;
        if (previousValue <= 0) continue; // skip empty portfolios

        const profit = previousValue * (returnPct / 100);
        const newValue = previousValue + profit;

        const batch = db().batch();

        // Update portfolio
        batch.update(portfolioDoc.ref, {
          currentValue: newValue,
          lastMonthlyReturnPct: returnPct,
          lastUpdated: now,
        });

        // Write returnHistory entry
        const histRef = db()
          .collection("portfolios")
          .doc(uid)
          .collection("returnHistory")
          .doc();
        batch.set(histRef, {
          returnPct,
          profitAmount: profit,
          previousValue,
          newValue,
          appliedAt: now,
          appliedBy: adminUid,
          mode: "percentage",
        });

        // Write profit_entry transaction
        const txRef = db().collection("transactions").doc();
        batch.set(txRef, {
          userId: uid,
          type: "profit_entry",
          amount: profit,
          status: "approved",
          createdAt: now,
          notes: `Monthly return ${returnPct}% applied by admin`,
          approvedBy: adminUid,
        });

        await batch.commit();
        totalProfit += profit;
        successCount++;
      } catch (e) {
        failCount++;
        errors.push(`${uid}: ${String(e)}`);
        logger.error("applyMonthlyReturns user failed", {
          uid,
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
        totalProfit,
      },
    );

    return { successCount, failCount, totalProfit, errors };
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
      method: ["GET", "HEAD"],
      maxAgeSeconds: 3600,
      responseHeader: [
        "Content-Type",
        "Authorization",
        "Content-Length",
        "User-Agent",
        "x-goog-resumable",
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
