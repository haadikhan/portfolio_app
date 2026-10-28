"use strict";

const { describe, it } = require("node:test");
const assert = require("node:assert/strict");
const { depositMoneyMarketStamp } = require("./moneyMarketFromTransactions");
const {
  parseCashAmount,
  validIdempotencyKey,
  deriveFeeAwareBalances,
  withdrawalFits,
  findCashDeskBlockers,
  idempotencyDecision,
  buildCreditTransactionFields,
  roundCashAmount,
} = require("./admin_cash_desk");

describe("deriveFeeAwareBalances", () => {
  it("subtracts fees and reserves pending withdrawals", () => {
    const bal = deriveFeeAwareBalances([
      { type: "deposit", status: "approved", amount: 1000 },
      { type: "management_fee", status: "approved", amount: 100 },
      { type: "withdrawal", status: "pending", amount: 200 },
      { type: "withdrawal", status: "completed", amount: 50 },
      { type: "profit", status: "approved", amount: 25 },
      { type: "deposit", status: "pending", amount: 999 },
    ]);
    assert.equal(bal.totalDeposited, 1000);
    assert.equal(bal.totalFees, 100);
    assert.equal(bal.reservedAmount, 200);
    assert.equal(bal.totalWithdrawn, 50);
    assert.equal(bal.totalProfit, 25);
    assert.equal(bal.availableBalance, 675);
  });

  it("counts an approved deposit and ignores a completed deposit", () => {
    const bal = deriveFeeAwareBalances([
      { type: "deposit", status: "approved", amount: 40 },
      { type: "deposit", status: "completed", amount: 15 },
    ]);
    assert.equal(bal.totalDeposited, 40);
    assert.equal(bal.availableBalance, 40);
  });
});

describe("parseCashAmount", () => {
  it("rejects zero, negative, NaN, and non-numeric values", () => {
    for (const raw of [0, -1, -0.01, NaN, Infinity, "nope", null, "", "  "]) {
      const parsed = parseCashAmount(raw);
      assert.equal(parsed.ok, false, String(raw));
    }
  });

  it("rounds to 2 decimals and keeps a positive amount", () => {
    const parsed = parseCashAmount("10.126");
    assert.equal(parsed.ok, true);
    assert.equal(parsed.amount, Number((10.126).toFixed(2)));
    assert.equal(parseCashAmount(10.5).amount, 10.5);
  });

  it("treats a rounded-to-zero fraction as non-positive", () => {
    const parsed = parseCashAmount(0.001);
    assert.equal(parsed.ok, false);
    assert.equal(parsed.code, "non_positive");
  });
});

describe("withdrawalFits", () => {
  it("allows the exact available balance and rejects a larger amount", () => {
    assert.equal(withdrawalFits(100, 100), true);
    assert.equal(withdrawalFits(100, 100.004), true);
    assert.equal(withdrawalFits(100.01, 100), false);
    assert.equal(roundCashAmount(100.004), 100);
  });
});

describe("findCashDeskBlockers", () => {
  it("blocks pending or approved withdrawals and pending deposits", () => {
    const blockers = findCashDeskBlockers(
      [
        { id: "w1", type: "withdrawal", status: "pending" },
        { id: "w2", type: "withdrawal", status: "approved" },
        { id: "w3", type: "withdrawal", status: "completed" },
        { id: "d1", type: "deposit", status: "pending" },
        { id: "d2", type: "deposit", status: "approved" },
      ],
      [{ id: "req-w", status: "pending", transactionId: "w1" }],
      [{ id: "req-d", status: "pending", transactionId: "d1" }],
    );
    const ids = blockers.map((b) => b.id).sort();
    assert.deepEqual(ids, ["d1", "w1", "w2"]);
  });

  it("includes an orphan request that has no transaction row", () => {
    const blockers = findCashDeskBlockers(
      [],
      [{ id: "orphan", status: "approved" }],
      [],
    );
    assert.equal(blockers.length, 1);
    assert.equal(blockers[0].kind, "withdrawal_request");
    assert.equal(blockers[0].id, "orphan");
  });

  it("ignores stale deposit_requests when the transaction is already settled", () => {
    const blockers = findCashDeskBlockers(
      [{ id: "d9", type: "deposit", status: "approved" }],
      [],
      [{ id: "stale-req", status: "pending", transactionId: "d9" }],
    );
    assert.equal(blockers.length, 0);
  });

  it("ignores stale withdrawal_requests when the transaction is completed", () => {
    const blockers = findCashDeskBlockers(
      [{ id: "w9", type: "withdrawal", status: "completed" }],
      [{ id: "stale-req", status: "approved", transactionId: "w9" }],
      [],
    );
    assert.equal(blockers.length, 0);
  });
});

describe("idempotencyDecision", () => {
  it("replays the same payload and rejects a different one", () => {
    const existing = {
      userId: "u1",
      action: "adminCashWithdraw",
      amount: 25,
      transactionId: "ISC-1",
    };
    const replay = idempotencyDecision(existing, {
      userId: "u1",
      action: "adminCashWithdraw",
      amount: 25,
    });
    assert.equal(replay.kind, "replay");
    assert.equal(replay.stored.transactionId, "ISC-1");

    const conflict = idempotencyDecision(existing, {
      userId: "u1",
      action: "adminCashWithdraw",
      amount: 26,
    });
    assert.equal(conflict.kind, "conflict");
    assert.equal(idempotencyDecision(null, {}).kind, "new");
  });

  it("accepts only safe idempotency keys", () => {
    assert.equal(validIdempotencyKey("abcd1234"), "abcd1234");
    assert.equal(validIdempotencyKey("short"), null);
    assert.equal(validIdempotencyKey("has space!"), null);
    assert.equal(validIdempotencyKey(""), null);
  });
});

describe("buildCreditTransactionFields", () => {
  it("stamps the money market and does not attach a fee", () => {
    const stamp = depositMoneyMarketStamp(1000, 5);
    const fields = buildCreditTransactionFields({
      id: "ISC-2026-TEST",
      userId: "u1",
      amount: 1000,
      adminUid: "admin1",
      reference: "R-1",
      note: "counter",
      balanceBefore: 100,
      balanceAfter: 1100,
      moneyStamp: stamp,
    });
    assert.equal(fields.type, "deposit");
    assert.equal(fields.status, "approved");
    assert.equal(fields.paymentMethod, "cash");
    assert.equal(fields.metadata.source, "admin_cash");
    assert.equal(fields.moneyMarketAllocationPercent, 5);
    assert.equal(fields.moneyMarketCreditPkr, 50);
    assert.equal(fields.frontEndFeeApplied, undefined);
    assert.equal(fields.frontEndFeeAmount, undefined);
    assert.equal(
      Object.values(fields).includes("front_end_load_fee"),
      false,
    );
  });
});
