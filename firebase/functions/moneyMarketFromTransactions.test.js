"use strict";

const { describe, it } = require("node:test");
const assert = require("node:assert/strict");
const {
  LEGACY_DEPOSIT_MONEY_ALLOCATION_PERCENT,
  moneyAllocationPercentFromAllocations,
  inspectMoneyAllocation,
  extractNonMmProfitPkr,
  depositMoneyMarketStamp,
  profitMoneyMarketMetadataStamp,
  moneyMarketFromTransactions,
} = require("./moneyMarketFromTransactions");

function mm(docs, fallback) {
  return moneyMarketFromTransactions(docs, {
    moneyAllocationPercent: fallback,
  });
}

describe("moneyAllocationPercentFromAllocations", () => {
  it("reads allocations.money as-is even when sleeves do not sum to 100", () => {
    const allocations = { stock: 40, tech: 25, debt: 25, money: 6, gold: 10 };
    assert.equal(moneyAllocationPercentFromAllocations(allocations), 6);
    const inspected = inspectMoneyAllocation(allocations);
    assert.equal(inspected.sumWarning, true);
    assert.equal(inspected.percent, 6);
  });

  it("falls back to 5 when money is missing or invalid", () => {
    assert.equal(moneyAllocationPercentFromAllocations({}), 5);
    assert.equal(moneyAllocationPercentFromAllocations({ money: -1 }), 5);
    assert.equal(moneyAllocationPercentFromAllocations({ money: "x" }), 5);
    assert.equal(moneyAllocationPercentFromAllocations(null), 5);
  });

  it("allows 0% money allocation", () => {
    assert.equal(moneyAllocationPercentFromAllocations({ money: 0 }), 0);
  });
});

describe("deposit stamps and legacy 5%", () => {
  it("Deposit 100000, no stamp, recalc → MM credited 5000", () => {
    const out = mm(
      [{ type: "deposit", status: "approved", amount: 100000 }],
      6,
    );
    assert.equal(out.moneyMarketCreditedTotal, 5000);
  });

  it("Deposit 100000 stamped 6% → MM credited 6000", () => {
    const stamp = depositMoneyMarketStamp(100000, 6);
    assert.equal(stamp.moneyMarketAllocationPercent, 6);
    assert.equal(stamp.moneyMarketCreditPkr, 6000);
    const out = mm(
      [{ type: "deposit", status: "approved", amount: 100000, ...stamp }],
      5,
    );
    assert.equal(out.moneyMarketCreditedTotal, 6000);
  });

  it("Mix: old 100000 (5%) + new 100000 (6%) → 11000 before P/L", () => {
    const out = mm(
      [
        { type: "deposit", status: "approved", amount: 100000 },
        {
          type: "deposit",
          status: "approved",
          amount: 100000,
          ...depositMoneyMarketStamp(100000, 6),
        },
      ],
      6,
    );
    assert.equal(out.moneyMarketCreditedTotal, 11000);
  });

  it("Changing Admin money % to 7% does not change unstamped old deposits", () => {
    const out = mm(
      [{ type: "deposit", status: "approved", amount: 100000 }],
      7,
    );
    assert.equal(out.moneyMarketCreditedTotal, 5000);
    assert.equal(LEGACY_DEPOSIT_MONEY_ALLOCATION_PERCENT, 5);
  });

  it("New deposit after Admin 7% credits 7%", () => {
    const stamp = depositMoneyMarketStamp(100000, 7);
    assert.equal(stamp.moneyMarketCreditPkr, 7000);
    const out = mm(
      [{ type: "deposit", status: "approved", amount: 100000, ...stamp }],
      7,
    );
    assert.equal(out.moneyMarketCreditedTotal, 7000);
  });

  it("never credits a negative amount from a single deposit", () => {
    const stamp = depositMoneyMarketStamp(-1000, 6);
    assert.equal(stamp.moneyMarketCreditPkr, 0);
  });
});

describe("non-MM P/L into MM cash", () => {
  it("NAV 100000, +2000 non-MM and +2 MM sleeve → MM cash 5100 not 5100.12", () => {
    const profit = {
      type: "profit_entry",
      status: "approved",
      amount: 2002,
      metadata: {
        source: "five_market_daily",
        markets: { money: { profitPkr: 2 } },
      },
    };
    assert.equal(extractNonMmProfitPkr(profit), 2000);
    const out = mm(
      [
        { type: "deposit", status: "approved", amount: 100000 },
        profit,
      ],
      5,
    );
    assert.equal(out.moneyMarketCreditedTotal, 5100);
    assert.equal(out.moneyMarketBalance, 5100);
  });

  it("same with -2000 non-MM → MM 4900", () => {
    const out = mm(
      [
        { type: "deposit", status: "approved", amount: 100000 },
        {
          type: "profit_entry",
          status: "approved",
          amount: -1998,
          metadata: {
            source: "five_market_daily",
            markets: { money: { profitPkr: 2 } },
          },
        },
      ],
      5,
    );
    assert.equal(out.moneyMarketCreditedTotal, 4900);
    assert.equal(out.moneyMarketBalance, 4900);
  });

  it("INCLUDE whole amount when metadata has no per-sleeve markets", () => {
    const lump = {
      type: "profit_entry",
      status: "approved",
      amount: 2000,
    };
    assert.equal(extractNonMmProfitPkr(lump), 2000);
    const out = mm(
      [
        { type: "deposit", status: "approved", amount: 100000 },
        lump,
      ],
      5,
    );
    assert.equal(out.moneyMarketCreditedTotal, 5100);
  });

  it("unstamped profit uses current Admin % fallback, not 5%", () => {
    const out = mm(
      [
        { type: "deposit", status: "approved", amount: 100000 },
        { type: "profit_entry", status: "approved", amount: 2000 },
      ],
      6,
    );
    assert.equal(out.moneyMarketCreditedTotal, 5120);
  });

  it("stamped profit rate is kept when Admin fallback later changes", () => {
    const stamp = profitMoneyMarketMetadataStamp({
      amountPkr: 2002,
      markets: { money: { profitPkr: 2 } },
      allocationPercent: 5,
    });
    assert.equal(stamp.moneyMarketPnlRatePercent, 5);
    assert.equal(stamp.moneyMarketPnlCreditPkr, 100);
    assert.equal(stamp.moneyProfitPkrExcluded, 2);
    const out = mm(
      [
        { type: "deposit", status: "approved", amount: 100000 },
        {
          type: "profit_entry",
          status: "approved",
          amount: 2002,
          metadata: {
            source: "five_market_daily",
            markets: { money: { profitPkr: 2 } },
            ...stamp,
          },
        },
      ],
      7,
    );
    assert.equal(out.moneyMarketCreditedTotal, 5100);
  });

  it("applies the same non-MM rule to general adjustments", () => {
    const out = mm(
      [
        { type: "deposit", status: "approved", amount: 100000 },
        { type: "adjustment", status: "approved", amount: 2000 },
      ],
      5,
    );
    assert.equal(out.moneyMarketCreditedTotal, 5100);
  });

  it("floors moneyMarketBalance at 0", () => {
    const out = mm(
      [
        { type: "deposit", status: "approved", amount: 1000 },
        { type: "profit_entry", status: "approved", amount: -100000 },
      ],
      5,
    );
    assert.ok(out.moneyMarketCreditedTotal < 0);
    assert.equal(out.moneyMarketBalance, 0);
    assert.equal(out.moneyMarketAvailable, 0);
  });
});

describe("withdrawals", () => {
  it("Completed withdrawal 1000 decreases MM cash by 1000, not by 5%/6%", () => {
    const out = mm(
      [
        { type: "deposit", status: "approved", amount: 100000 },
        { type: "withdrawal", status: "completed", amount: 1000 },
      ],
      5,
    );
    assert.equal(out.moneyMarketCreditedTotal, 5000);
    assert.equal(out.moneyMarketWithdrawnTotal, 1000);
    assert.equal(out.moneyMarketBalance, 4000);
    assert.equal(out.moneyMarketAvailable, 4000);
  });

  it("Pending withdrawal reserves MM and does not increase withdrawn total", () => {
    const out = mm(
      [
        { type: "deposit", status: "approved", amount: 100000 },
        { type: "withdrawal", status: "pending", amount: 1000 },
      ],
      5,
    );
    assert.equal(out.moneyMarketWithdrawnTotal, 0);
    assert.equal(out.moneyMarketReserved, 1000);
    assert.equal(out.moneyMarketBalance, 5000);
    assert.equal(out.moneyMarketAvailable, 4000);
  });

  it("Approved (unsettled) withdrawal behaves like pending for MM reserve", () => {
    const out = mm(
      [
        { type: "deposit", status: "approved", amount: 100000 },
        { type: "withdrawal", status: "approved", amount: 500 },
      ],
      5,
    );
    assert.equal(out.moneyMarketReserved, 500);
    assert.equal(out.moneyMarketWithdrawnTotal, 0);
  });
});

describe("fees excluded from MM cash", () => {
  it("does not put fee transactions into moneyMarketCreditedTotal", () => {
    const out = mm(
      [
        { type: "deposit", status: "approved", amount: 100000 },
        { type: "front_end_load_fee", status: "approved", amount: 2000 },
        { type: "management_fee", status: "approved", amount: 50 },
        { type: "performance_fee", status: "completed", amount: 10 },
        { type: "referral_fee", status: "approved", amount: 100 },
      ],
      5,
    );
    assert.equal(out.moneyMarketCreditedTotal, 5000);
  });
});
