"use strict";

const { describe, it } = require("node:test");
const assert = require("node:assert/strict");
const { calculateDailyProfit } = require("./five_market_daily");

describe("five-market daily profit formulas (unchanged)", () => {
  it("stock/tech/debt/gold still use config allocations of NAV", () => {
    const result = calculateDailyProfit({
      basePkr: 100000,
      config: {
        allocations: { stock: 40, tech: 25, debt: 25, money: 6, gold: 4 },
        rates: {
          techBenchmarkAnnualPercent: 0,
          debtAnnualPercent: 0,
          moneyAnnualPercent: 15,
        },
      },
      eodSnap: {
        kmi30: { changePercent: 10 },
        gold: { changePercent: 5 },
      },
    });

    assert.equal(result.markets.stock.allocatedPkr, 40000);
    assert.equal(result.markets.tech.allocatedPkr, 25000);
    assert.equal(result.markets.debt.allocatedPkr, 25000);
    assert.equal(result.markets.gold.allocatedPkr, 4000);
    assert.equal(result.markets.money.allocatedPkr, 6000);

    assert.equal(result.markets.stock.profitPkr, 4000);
    assert.equal(result.markets.tech.profitPkr, 0);
    assert.equal(result.markets.debt.profitPkr, 0);
    assert.equal(result.markets.gold.profitPkr, 200);
    // MM sleeve daily profit still exists; it is excluded only from MM cash.
    assert.equal(
      result.markets.money.profitPkr,
      parseFloat(((6000 * 0.15) / 365).toFixed(2)),
    );
  });
});
