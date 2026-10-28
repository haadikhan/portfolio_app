"use strict";

/**
 * Runs only under `firebase emulators:exec` (Auth + Firestore + Functions).
 * Skips when the emulator host variables are absent so `npm test` stays local.
 */

const { describe, it, before } = require("node:test");
const assert = require("node:assert/strict");

const emulator =
  !!process.env.FIRESTORE_EMULATOR_HOST &&
  !!process.env.FIREBASE_AUTH_EMULATOR_HOST;

describe("admin cash desk emulator", { skip: !emulator }, () => {
  const admin = require("firebase-admin");
  const projectId = process.env.GCLOUD_PROJECT || "portfolio-e97b1";
  const functionsPort = 5001;

  before(() => {
    if (!admin.apps.length) {
      admin.initializeApp({ projectId });
    }
  });

  function db() {
    return admin.firestore();
  }

  async function signIn(email, password) {
    const host = process.env.FIREBASE_AUTH_EMULATOR_HOST;
    const res = await fetch(
      `http://${host}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake-api-key`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          email,
          password,
          returnSecureToken: true,
        }),
      },
    );
    const body = await res.json();
    if (!body.idToken) {
      throw new Error(`signIn failed: ${JSON.stringify(body)}`);
    }
    return body.idToken;
  }

  async function ensureUser({ uid, email, password, role, claims, balance }) {
    try {
      await admin.auth().getUser(uid);
    } catch {
      await admin.auth().createUser({ uid, email, password });
    }
    if (claims) await admin.auth().setCustomUserClaims(uid, claims);
    await db()
      .collection("users")
      .doc(uid)
      .set(
        {
          email,
          name: email,
          role,
          ...(balance == null ? {} : { balance }),
        },
        { merge: true },
      );
    return signIn(email, password);
  }

  async function callFn(name, data, token) {
    const res = await fetch(
      `http://127.0.0.1:${functionsPort}/${projectId}/us-central1/${name}`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
        body: JSON.stringify({ data }),
      },
    );
    const body = await res.json();
    return { http: res.status, body };
  }

  function resultOf(response) {
    if (response.body && response.body.result) return response.body.result;
    const message =
      response.body?.error?.message || JSON.stringify(response.body);
    const status = response.body?.error?.status || String(response.http);
    const err = new Error(message);
    err.status = status;
    throw err;
  }

  async function seedLedger(uid, extraPortfolio) {
    const now = admin.firestore.FieldValue.serverTimestamp();
    await db().collection("transactions").doc(`dep-${uid}`).set({
      id: `dep-${uid}`,
      userId: uid,
      type: "deposit",
      amount: 10000,
      status: "approved",
      moneyMarketAllocationPercent: 5,
      moneyMarketCreditPkr: 500,
      createdAt: now,
      updatedAt: now,
    });
    await db().collection("transactions").doc(`profit-${uid}`).set({
      id: `profit-${uid}`,
      userId: uid,
      type: "profit",
      amount: 1000,
      status: "approved",
      createdAt: now,
      updatedAt: now,
    });
    await db().collection("transactions").doc(`fee-${uid}`).set({
      id: `fee-${uid}`,
      userId: uid,
      type: "management_fee",
      amount: 100,
      status: "approved",
      createdAt: now,
      updatedAt: now,
    });
    await db()
      .collection("portfolios")
      .doc(uid)
      .set(
        {
          fiveMarketDailyLedger: true,
          currentValue: 12345,
          ...(extraPortfolio || {}),
        },
        { merge: true },
      );
  }

  async function walletOf(uid) {
    const snap = await db().collection("wallets").doc(uid).get();
    return snap.data() || {};
  }

  it("rejects unauthenticated, investor, and CRM callers", async () => {
    const investorToken = await ensureUser({
      uid: "cash-investor-auth",
      email: "cash-investor-auth@example.com",
      password: "secret123",
      role: "investor",
    });
    const crmToken = await ensureUser({
      uid: "cash-crm-auth",
      email: "cash-crm-auth@example.com",
      password: "secret123",
      role: "crm",
    });
    const payload = {
      userId: "cash-investor-auth",
      amount: 1,
      idempotencyKey: "unauthkey1",
    };
    const anon = await callFn("adminCashWithdraw", payload, null);
    assert.equal(anon.body.error.status, "UNAUTHENTICATED");
    const investor = await callFn("adminCashWithdraw", payload, investorToken);
    assert.equal(investor.body.error.status, "PERMISSION_DENIED");
    const crm = await callFn("adminCashCredit", payload, crmToken);
    assert.equal(crm.body.error.status, "PERMISSION_DENIED");
  });

  it("withdraws a partial amount then the rest without fees, alerts, or ledger flags", async () => {
    const uid = "cash-full-user";
    const adminToken = await ensureUser({
      uid: "cash-admin-full",
      email: "cash-admin-full@example.com",
      password: "secret123",
      role: "admin",
      claims: { admin: true },
      balance: 4242,
    });
    await ensureUser({
      uid,
      email: "cash-full-user@example.com",
      password: "secret123",
      role: "investor",
      balance: 4242,
    });
    await seedLedger(uid);

    const first = resultOf(
      await callFn(
        "adminCashWithdraw",
        {
          userId: uid,
          amount: 1000,
          idempotencyKey: "partialwd1",
          reference: "RCPT-1",
          note: "counter",
        },
        adminToken,
      ),
    );
    assert.equal(first.balanceBefore, 10900);
    assert.equal(first.balanceAfter, 9900);

    const second = resultOf(
      await callFn(
        "adminCashWithdraw",
        {
          userId: uid,
          amount: 9900,
          idempotencyKey: "fullwd0001",
          reference: "RCPT-2",
        },
        adminToken,
      ),
    );
    assert.equal(second.balanceAfter, 0);

    const wallet = await walletOf(uid);
    assert.equal(Number(wallet.availableBalance), 0);
    assert.equal(Number(wallet.totalWithdrawn), 10900);
    assert.equal(Number(wallet.moneyMarketBalance), 0);

    const portfolio = (
      await db().collection("portfolios").doc(uid).get()
    ).data();
    assert.equal(portfolio.fiveMarketDailyLedger, true);
    assert.equal(portfolio.currentValue, 12345);
    assert.equal(Number(portfolio.netDeposits), 10000 - 10900);

    const user = (await db().collection("users").doc(uid).get()).data();
    assert.equal(user.balance, 4242);

    const notes = await db()
      .collection("users")
      .doc(uid)
      .collection("notifications")
      .get();
    assert.equal(notes.size, 0);

    const tx = await db().collection("transactions").doc(second.transactionId).get();
    assert.equal(tx.data().status, "completed");
    assert.equal(tx.data().type, "withdrawal");
    assert.equal(tx.data().metadata.source, "admin_cash");
    assert.equal(tx.data().metadata.method, "cash");
    assert.equal(tx.data().notes, "Cash withdrawal by admin");

    const req = await db()
      .collection("withdrawal_requests")
      .doc(second.requestId)
      .get();
    assert.equal(req.data().status, "completed");
    assert.equal(req.data().settlementRef, "RCPT-2");

    const audits = await db()
      .collection("audit_logs")
      .where("action", "==", "adminCashWithdraw")
      .get();
    const mine = audits.docs.filter((d) => d.data().after?.userId === uid);
    assert.equal(mine.length, 2);
  });

  it("credits cash with a money-market stamp and no fee transaction", async () => {
    const uid = "cash-credit-user";
    const adminToken = await ensureUser({
      uid: "cash-admin-credit",
      email: "cash-admin-credit@example.com",
      password: "secret123",
      role: "admin",
      claims: { admin: true },
    });
    await ensureUser({
      uid,
      email: "cash-credit-user@example.com",
      password: "secret123",
      role: "investor",
      balance: 7,
    });
    await seedLedger(uid);

    const credited = resultOf(
      await callFn(
        "adminCashCredit",
        {
          userId: uid,
          amount: 200,
          idempotencyKey: "creditkey1",
        },
        adminToken,
      ),
    );
    assert.equal(credited.balanceBefore, 10900);
    assert.equal(credited.balanceAfter, 11100);

    const again = resultOf(
      await callFn(
        "adminCashCredit",
        {
          userId: uid,
          amount: 200,
          idempotencyKey: "creditkey1",
        },
        adminToken,
      ),
    );
    assert.equal(again.replayed, true);
    assert.equal(again.transactionId, credited.transactionId);

    const wallet = await walletOf(uid);
    assert.equal(Number(wallet.availableBalance), 11100);
    assert.equal(Number(wallet.totalDeposited), 10200);
    assert.equal(Number(wallet.totalFees), 100);

    const tx = await db()
      .collection("transactions")
      .doc(credited.transactionId)
      .get();
    assert.equal(tx.data().status, "approved");
    assert.equal(tx.data().type, "deposit");
    assert.equal(tx.data().metadata.source, "admin_cash");
    assert.equal(tx.data().moneyMarketCreditPkr, 10);
    assert.equal(tx.data().frontEndFeeApplied, undefined);

    const fees = await db()
      .collection("transactions")
      .where("userId", "==", uid)
      .where("type", "==", "front_end_load_fee")
      .get();
    assert.equal(fees.size, 0);

    const user = (await db().collection("users").doc(uid).get()).data();
    assert.equal(user.balance, 7);
    const notes = await db()
      .collection("users")
      .doc(uid)
      .collection("notifications")
      .get();
    assert.equal(notes.size, 0);
  });

  it("lets only one of two full withdrawals succeed", async () => {
    const uid = "cash-race-user";
    const adminToken = await ensureUser({
      uid: "cash-admin-race",
      email: "cash-admin-race@example.com",
      password: "secret123",
      role: "admin",
      claims: { admin: true },
    });
    await ensureUser({
      uid,
      email: "cash-race-user@example.com",
      password: "secret123",
      role: "investor",
    });
    const now = admin.firestore.FieldValue.serverTimestamp();
    await db().collection("transactions").doc(`dep-${uid}`).set({
      id: `dep-${uid}`,
      userId: uid,
      type: "deposit",
      amount: 500,
      status: "approved",
      moneyMarketAllocationPercent: 5,
      moneyMarketCreditPkr: 25,
      createdAt: now,
    });

    const [a, b] = await Promise.all([
      callFn(
        "adminCashWithdraw",
        { userId: uid, amount: 500, idempotencyKey: "racekey01" },
        adminToken,
      ),
      callFn(
        "adminCashWithdraw",
        { userId: uid, amount: 500, idempotencyKey: "racekey02" },
        adminToken,
      ),
    ]);
    const outcomes = [a, b];
    const ok = outcomes.filter((r) => r.body && r.body.result);
    const failed = outcomes.filter((r) => r.body && r.body.error);
    assert.equal(ok.length, 1);
    assert.equal(failed.length, 1);
    assert.match(failed[0].body.error.message, /available balance/i);

    const wallet = await walletOf(uid);
    assert.equal(Number(wallet.availableBalance), 0);
    assert.ok(Number(wallet.availableBalance) >= 0);
  });

  it("blocks both actions while a withdrawal is pending", async () => {
    const uid = "cash-blocked-user";
    const adminToken = await ensureUser({
      uid: "cash-admin-blocked",
      email: "cash-admin-blocked@example.com",
      password: "secret123",
      role: "admin",
      claims: { admin: true },
    });
    await ensureUser({
      uid,
      email: "cash-blocked-user@example.com",
      password: "secret123",
      role: "investor",
    });
    const now = admin.firestore.FieldValue.serverTimestamp();
    await db().collection("transactions").doc(`dep-${uid}`).set({
      id: `dep-${uid}`,
      userId: uid,
      type: "deposit",
      amount: 800,
      status: "approved",
      createdAt: now,
    });
    await db().collection("transactions").doc(`pend-${uid}`).set({
      id: `pend-${uid}`,
      userId: uid,
      type: "withdrawal",
      amount: 50,
      status: "pending",
      createdAt: now,
    });

    const withdraw = await callFn(
      "adminCashWithdraw",
      { userId: uid, amount: 10, idempotencyKey: "blockwd001" },
      adminToken,
    );
    const credit = await callFn(
      "adminCashCredit",
      { userId: uid, amount: 10, idempotencyKey: "blockcr001" },
      adminToken,
    );
    assert.equal(withdraw.body.error.status, "FAILED_PRECONDITION");
    assert.match(withdraw.body.error.message, /Resolve open requests/);
    assert.equal(credit.body.error.status, "FAILED_PRECONDITION");
    assert.match(credit.body.error.message, /Resolve open requests/);
  });

  it("still completes the existing user withdrawal through the admin queue", async () => {
    const uid = "cash-regression-user";
    const adminToken = await ensureUser({
      uid: "cash-admin-regression",
      email: "cash-admin-regression@example.com",
      password: "secret123",
      role: "admin",
      claims: { admin: true },
      balance: 50000,
    });
    const investorToken = await ensureUser({
      uid,
      email: "cash-regression-user@example.com",
      password: "secret123",
      role: "investor",
      balance: 10000,
    });
    await db().collection("kyc").doc(uid).set({ status: "approved" });
    const now = admin.firestore.FieldValue.serverTimestamp();
    await db().collection("transactions").doc(`dep-${uid}`).set({
      id: `dep-${uid}`,
      userId: uid,
      type: "deposit",
      amount: 10000,
      status: "approved",
      moneyMarketAllocationPercent: 5,
      moneyMarketCreditPkr: 500,
      createdAt: now,
    });

    const created = resultOf(
      await callFn(
        "createWithdrawalRequest",
        { amount: 100 },
        investorToken,
      ),
    );
    const approved = resultOf(
      await callFn(
        "adminApproveTransaction",
        { txnId: created.transactionId },
        adminToken,
      ),
    );
    assert.equal(approved.ok, true);
    const tx = await db()
      .collection("transactions")
      .doc(created.transactionId)
      .get();
    assert.equal(tx.data().status, "completed");
    assert.equal(tx.data().type, "withdrawal");
    const user = (await db().collection("users").doc(uid).get()).data();
    assert.equal(user.balance, 9900);
  });
});
