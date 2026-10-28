/**
 * Admin Cash Desk.
 *
 * adminCashWithdraw posts a completed withdrawal for any amount up to the
 * fee-aware available balance (not limited to the money-market bucket).
 * adminCashCredit posts an approved deposit with the same money-market stamp
 * as adminCreateDeposit and does not charge a fee.
 *
 * txId, assertAdmin, and syncPortfolioNetDeposits are copied here. They stay
 * private in wallet_ledger.js because index.js Object.assigns that module's
 * exports, and a plain helper would be published as a broken Cloud Function.
 */

"use strict";

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const { FieldValue } = require("firebase-admin/firestore");
const { logger } = require("firebase-functions");
const {
  recalculateWallet,
  appendAudit,
  loadFiveMarketMoneyAllocationPercent,
  isFeeType,
} = require("./wallet_helpers");
const { depositMoneyMarketStamp } = require("./moneyMarketFromTransactions");

const db = () => admin.firestore();

const IDEMPOTENCY_KEY_RE = /^[A-Za-z0-9_-]{8,128}$/;

function txId() {
  const y = new Date().getFullYear();
  const rand = Math.random().toString(36).slice(2, 10).toUpperCase();
  return `ISC-${y}-${rand}`;
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

/** Same merge as wallet_ledger.syncPortfolioNetDeposits. */
async function syncPortfolioNetDeposits(uid) {
  const snap = await db().collection("wallets").doc(uid).get();
  if (!snap.exists) return;
  const w = snap.data();
  const netDeposits = parseFloat(
    (Number(w.totalDeposited || 0) - Number(w.totalWithdrawn || 0)).toFixed(2),
  );
  await db()
    .collection("portfolios")
    .doc(uid)
    .set(
      {
        netDeposits,
        netDepositsUpdatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
}

function roundCashAmount(n) {
  const x = Number(n);
  if (!Number.isFinite(x)) return 0;
  return parseFloat(x.toFixed(2));
}

/**
 * @returns {{ ok: true, amount: number } | { ok: false, code: "invalid" | "non_positive" }}
 */
function parseCashAmount(raw) {
  if (typeof raw === "string" && raw.trim() === "") {
    return { ok: false, code: "invalid" };
  }
  if (raw == null || typeof raw === "boolean") {
    return { ok: false, code: "invalid" };
  }
  const n = typeof raw === "number" ? raw : Number(raw);
  if (!Number.isFinite(n)) return { ok: false, code: "invalid" };
  const amount = parseFloat(n.toFixed(2));
  if (!(amount > 0)) return { ok: false, code: "non_positive" };
  return { ok: true, amount };
}

function validIdempotencyKey(raw) {
  const key = typeof raw === "string" ? raw.trim() : "";
  if (!IDEMPOTENCY_KEY_RE.test(key)) return null;
  return key;
}

function docData(doc) {
  if (!doc) return {};
  if (typeof doc.data === "function") return doc.data() || {};
  return doc;
}

function docId(doc, data) {
  if (doc && typeof doc.id === "string" && doc.id) return doc.id;
  if (data && data.id) return String(data.id);
  return "";
}

/**
 * Fee-aware totals. Same status rules as wallet_helpers.recalculateWallet.
 * Does not read Firestore and does not change that function.
 */
function deriveFeeAwareBalances(docs) {
  let totalDeposited = 0;
  let totalWithdrawn = 0;
  let totalProfit = 0;
  let totalAdjustments = 0;
  let totalFees = 0;
  let reservedAmount = 0;

  for (const doc of docs || []) {
    const d = docData(doc);
    const amt = Number(d.amount) || 0;
    const st = String(d.status || "").toLowerCase();
    const ty = String(d.type || "").toLowerCase();

    if (ty === "deposit" && st === "approved") {
      totalDeposited += amt;
    } else if (ty === "withdrawal") {
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
    } else if (isFeeType(ty) && (st === "approved" || st === "completed")) {
      totalFees += Math.abs(amt);
    }
  }

  const availableBalance =
    totalDeposited +
    totalProfit +
    totalAdjustments -
    totalWithdrawn -
    reservedAmount -
    totalFees;

  return {
    totalDeposited,
    totalWithdrawn,
    totalProfit,
    totalAdjustments,
    totalFees,
    reservedAmount,
    availableBalance,
  };
}

function withdrawalFits(amount, availableBalance) {
  return amount <= roundCashAmount(availableBalance);
}

function transactionStatusById(transactionDocs) {
  const map = new Map();
  for (const doc of transactionDocs || []) {
    const d = docData(doc);
    const id = docId(doc, d);
    if (id) map.set(id, String(d.status || "").toLowerCase());
  }
  return map;
}

function findCashDeskBlockers(
  transactionDocs,
  withdrawalRequestDocs,
  depositRequestDocs,
) {
  const blockers = [];
  const seenTx = new Set();
  const txStatus = transactionStatusById(transactionDocs);

  for (const doc of transactionDocs || []) {
    const d = docData(doc);
    const id = docId(doc, d);
    const ty = String(d.type || "").toLowerCase();
    const st = String(d.status || "").toLowerCase();
    if (ty === "withdrawal" && (st === "pending" || st === "approved")) {
      blockers.push({ kind: "withdrawal", id, status: st });
      if (id) seenTx.add(id);
    } else if (ty === "deposit" && st === "pending") {
      blockers.push({ kind: "deposit", id, status: st });
      if (id) seenTx.add(id);
    }
  }

  for (const doc of withdrawalRequestDocs || []) {
    const d = docData(doc);
    const st = String(d.status || "").toLowerCase();
    if (st !== "pending" && st !== "approved") continue;
    const tid = d.transactionId ? String(d.transactionId) : "";
    if (tid) {
      const linked = txStatus.get(tid);
      if (linked === "completed" || linked === "rejected") continue;
      if (seenTx.has(tid)) continue;
    }
    blockers.push({
      kind: "withdrawal_request",
      id: docId(doc, d),
      status: st,
    });
  }

  for (const doc of depositRequestDocs || []) {
    const d = docData(doc);
    const st = String(d.status || "").toLowerCase();
    if (st !== "pending") continue;
    const tid = d.transactionId ? String(d.transactionId) : "";
    if (tid) {
      const linked = txStatus.get(tid);
      // Legacy admin queue uses adminApproveTransaction on the txn only;
      // deposit_requests can stay "pending" after the txn is settled.
      if (linked && linked !== "pending") continue;
      if (seenTx.has(tid)) continue;
    }
    blockers.push({
      kind: "deposit_request",
      id: docId(doc, d),
      status: st,
    });
  }

  return blockers;
}

function formatCashDeskBlockers(blockers) {
  const parts = blockers.map((b) => `${b.kind} ${b.id} (${b.status})`);
  return `Resolve open requests first: ${parts.join("; ")}`;
}

/**
 * @returns {{ kind: "new" } | { kind: "replay", stored: object } | { kind: "conflict" }}
 */
function idempotencyDecision(existing, request) {
  if (!existing) return { kind: "new" };
  const same =
    existing.userId === request.userId &&
    existing.action === request.action &&
    Number(existing.amount) === Number(request.amount);
  if (same) return { kind: "replay", stored: existing };
  return { kind: "conflict" };
}

function optionalText(raw, max, label) {
  if (raw == null) return null;
  const s = String(raw).trim();
  if (!s) return null;
  if (s.length > max) {
    throw new HttpsError(
      "invalid-argument",
      `${label} exceeds ${max} characters.`,
    );
  }
  return s;
}

function buildCashMetadata({ reference, note, balanceBefore, balanceAfter }) {
  return {
    source: "admin_cash",
    method: "cash",
    reference: reference || null,
    note: note || null,
    balanceBefore,
    balanceAfter,
  };
}

function buildCreditTransactionFields({
  id,
  userId,
  amount,
  adminUid,
  reference,
  note,
  balanceBefore,
  balanceAfter,
  moneyStamp,
}) {
  return {
    id,
    userId,
    type: "deposit",
    amount,
    status: "approved",
    notes: "Cash credit by admin",
    paymentMethod: "cash",
    approvedBy: adminUid,
    completedBy: adminUid,
    metadata: buildCashMetadata({
      reference,
      note,
      balanceBefore,
      balanceAfter,
    }),
    ...moneyStamp,
  };
}

function requireUserId(raw) {
  const userId = typeof raw === "string" ? raw.trim() : "";
  if (!userId) throw new HttpsError("invalid-argument", "userId required.");
  return userId;
}

function requireAmount(raw) {
  const parsed = parseCashAmount(raw);
  if (!parsed.ok) {
    throw new HttpsError(
      "invalid-argument",
      parsed.code === "non_positive"
        ? "Amount must be greater than zero."
        : "Invalid amount.",
    );
  }
  return parsed.amount;
}

function requireKey(raw) {
  const key = validIdempotencyKey(raw);
  if (!key) {
    throw new HttpsError(
      "invalid-argument",
      "idempotencyKey must be 8-128 letters, digits, _ or -.",
    );
  }
  return key;
}

async function executeAdminCash({ authUid, action, data }) {
  if (!authUid) throw new HttpsError("unauthenticated", "Sign in required.");
  await assertAdmin(authUid);

  const payload = data || {};
  const userId = requireUserId(payload.userId);
  const amount = requireAmount(payload.amount);
  const idempotencyKey = requireKey(payload.idempotencyKey);
  const reference = optionalText(payload.reference, 80, "reference");
  const note = optionalText(payload.note, 500, "note");
  const actionName =
    action === "withdraw" ? "adminCashWithdraw" : "adminCashCredit";

  let moneyStamp = null;
  if (action === "credit") {
    const pct = await loadFiveMarketMoneyAllocationPercent();
    moneyStamp = depositMoneyMarketStamp(amount, pct);
  }

  const userRef = db().collection("users").doc(userId);
  const idemRef = db().collection("cash_desk_idempotency").doc(idempotencyKey);
  const guardRef = db().collection("cash_desk_guards").doc(userId);
  const reqRef =
    action === "withdraw"
      ? db().collection("withdrawal_requests").doc()
      : null;
  const tid = txId();
  const tRef = db().collection("transactions").doc(tid);

  const outcome = await db().runTransaction(async (tx) => {
    const userSnap = await tx.get(userRef);
    const idemSnap = await tx.get(idemRef);
    await tx.get(guardRef);
    const txsSnap = await tx.get(
      db().collection("transactions").where("userId", "==", userId),
    );
    const withdrawalReqSnap = await tx.get(
      db().collection("withdrawal_requests").where("userId", "==", userId),
    );
    const depositReqSnap = await tx.get(
      db().collection("deposit_requests").where("userId", "==", userId),
    );

    if (!userSnap.exists) {
      throw new HttpsError("not-found", "User not found.");
    }

    const decision = idempotencyDecision(idemSnap.exists ? idemSnap.data() : null, {
      userId,
      action: actionName,
      amount,
    });
    if (decision.kind === "conflict") {
      throw new HttpsError(
        "already-exists",
        "idempotencyKey was already used with a different payload.",
      );
    }
    if (decision.kind === "replay") {
      const stored = decision.stored;
      return {
        ok: true,
        replayed: true,
        transactionId: stored.transactionId,
        requestId: stored.requestId || null,
        balanceBefore: stored.balanceBefore,
        balanceAfter: stored.balanceAfter,
        amount: stored.amount,
      };
    }

    const blockers = findCashDeskBlockers(
      txsSnap.docs,
      withdrawalReqSnap.docs,
      depositReqSnap.docs,
    );
    if (blockers.length) {
      throw new HttpsError(
        "failed-precondition",
        formatCashDeskBlockers(blockers),
      );
    }

    const balances = deriveFeeAwareBalances(txsSnap.docs);
    const available = roundCashAmount(balances.availableBalance);
    if (action === "withdraw" && !withdrawalFits(amount, available)) {
      throw new HttpsError(
        "failed-precondition",
        "Amount exceeds available balance.",
      );
    }

    const balanceBefore = available;
    const balanceAfter =
      action === "withdraw"
        ? roundCashAmount(available - amount)
        : roundCashAmount(available + amount);
    const now = FieldValue.serverTimestamp();
    const metadata = buildCashMetadata({
      reference,
      note,
      balanceBefore,
      balanceAfter,
    });

    if (action === "withdraw") {
      tx.set(reqRef, {
        userId,
        amount,
        status: "completed",
        transactionId: tid,
        createdAt: now,
        updatedAt: now,
        adminNote: note,
        settlementRef: reference,
        approvedBy: authUid,
        completedBy: authUid,
      });
      tx.set(tRef, {
        id: tid,
        userId,
        type: "withdrawal",
        amount,
        status: "completed",
        createdAt: now,
        updatedAt: now,
        requestId: reqRef.id,
        notes: "Cash withdrawal by admin",
        approvedBy: authUid,
        completedBy: authUid,
        metadata,
      });
    } else {
      const creditFields = buildCreditTransactionFields({
        id: tid,
        userId,
        amount,
        adminUid: authUid,
        reference,
        note,
        balanceBefore,
        balanceAfter,
        moneyStamp,
      });
      tx.set(tRef, {
        ...creditFields,
        createdAt: now,
        updatedAt: now,
      });
    }

    tx.set(
      guardRef,
      {
        updatedAt: now,
        lastAction: actionName,
        lastTransactionId: tid,
      },
      { merge: true },
    );
    tx.set(idemRef, {
      userId,
      action: actionName,
      amount,
      transactionId: tid,
      requestId: reqRef ? reqRef.id : null,
      balanceBefore,
      balanceAfter,
      createdAt: now,
    });

    return {
      ok: true,
      replayed: false,
      transactionId: tid,
      requestId: reqRef ? reqRef.id : null,
      balanceBefore,
      balanceAfter,
      amount,
    };
  });

  if (outcome.replayed) return outcome;

  // Ledger docs are already committed. Do not fail the callable if the
  // follow-up rewrite throws — the client would otherwise show an error
  // after the money has already moved.
  try {
    await recalculateWallet(userId);
    await syncPortfolioNetDeposits(userId);
    await appendAudit(
      authUid,
      "admin",
      actionName,
      action === "withdraw" ? "withdrawal_request" : "transaction",
      outcome.requestId || outcome.transactionId,
      { availableBalance: outcome.balanceBefore },
      {
        availableBalance: outcome.balanceAfter,
        userId,
        amount: outcome.amount,
        transactionId: outcome.transactionId,
        requestId: outcome.requestId,
        reference,
      },
    );
  } catch (e) {
    logger.error("admin_cash_desk_postcommit_failed", {
      action: actionName,
      userId,
      transactionId: outcome.transactionId,
      error: String(e),
    });
  }

  logger.info("admin_cash_desk_posted", {
    action: actionName,
    userId,
    amount: outcome.amount,
    transactionId: outcome.transactionId,
  });

  return outcome;
}

const adminCashWithdraw = onCall(
  { region: "us-central1", memory: "512MiB", timeoutSeconds: 120 },
  async (request) =>
    executeAdminCash({
      authUid: request.auth?.uid,
      action: "withdraw",
      data: request.data,
    }),
);

const adminCashCredit = onCall(
  { region: "us-central1", memory: "512MiB", timeoutSeconds: 120 },
  async (request) =>
    executeAdminCash({
      authUid: request.auth?.uid,
      action: "credit",
      data: request.data,
    }),
);

module.exports = {
  adminCashWithdraw,
  adminCashCredit,
  IDEMPOTENCY_KEY_RE,
  roundCashAmount,
  parseCashAmount,
  validIdempotencyKey,
  deriveFeeAwareBalances,
  withdrawalFits,
  findCashDeskBlockers,
  formatCashDeskBlockers,
  idempotencyDecision,
  buildCashMetadata,
  buildCreditTransactionFields,
  executeAdminCash,
};
