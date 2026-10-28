/**
 * Shared Money Market cash projection.
 *
 * wallet_helpers.recalculateWallet and wallet_ledger.deriveWalletFromTransactions
 * MUST use this module so MM fields cannot drift.
 *
 * Product rules:
 * - Unstamped (legacy) deposits always credit 5%. Never rewrite them to today's
 *   Admin allocations.money (1B).
 * - Stamped deposits use moneyMarketAllocationPercent / moneyMarketCreditPkr
 *   written at approval from live Admin config.
 * - Profit/adjustment: add rate × non-MM P/L. Do NOT add Money Market sleeve
 *   daily profit into the MM cash bucket.
 * - When metadata.markets is missing, INCLUDE the whole amount as non-MM so
 *   old lump profit_entry rows still move MM with the portfolio.
 * - Completed withdrawals subtract the FULL amount from MM cash.
 * - Fees never enter moneyMarketCreditedTotal (they already reduce
 *   availableBalance / NAV).
 */

"use strict";

/** Legacy default when a deposit was approved before MM stamps existed. */
const LEGACY_DEPOSIT_MONEY_ALLOCATION_PERCENT = 5;

function roundMoney2(n) {
  const x = Number(n);
  if (!Number.isFinite(x)) return 0;
  return parseFloat(x.toFixed(2));
}

function readFiniteNumber(...candidates) {
  for (const raw of candidates) {
    if (raw == null || raw === "") continue;
    const n = Number(raw);
    if (Number.isFinite(n)) return n;
  }
  return null;
}

function txData(doc) {
  if (!doc) return {};
  if (typeof doc.data === "function") return doc.data() || {};
  return doc;
}

function txMetadata(tx) {
  return tx && tx.metadata && typeof tx.metadata === "object" ? tx.metadata : {};
}

/**
 * Admin allocations.money if finite and >= 0; else legacy 5.
 * Does not resplit when allocations do not sum to 100.
 */
function moneyAllocationPercentFromAllocations(allocations) {
  if (allocations == null || typeof allocations !== "object") {
    return LEGACY_DEPOSIT_MONEY_ALLOCATION_PERCENT;
  }
  if (allocations.money == null || allocations.money === "") {
    return LEGACY_DEPOSIT_MONEY_ALLOCATION_PERCENT;
  }
  const n = Number(allocations.money);
  if (!Number.isFinite(n) || n < 0) return LEGACY_DEPOSIT_MONEY_ALLOCATION_PERCENT;
  return n;
}

function allocationsSum(allocations) {
  if (!allocations || typeof allocations !== "object") return null;
  const keys = ["stock", "tech", "debt", "gold", "money"];
  let sum = 0;
  let any = false;
  for (const k of keys) {
    const n = Number(allocations[k]);
    if (Number.isFinite(n)) {
      any = true;
      sum += n;
    }
  }
  return any ? sum : null;
}

function inspectMoneyAllocation(allocations) {
  const percent = moneyAllocationPercentFromAllocations(allocations);
  const sum = allocationsSum(allocations);
  const sumWarning = sum != null && Math.abs(sum - 100) > 0.01;
  return { percent, sum, sumWarning };
}

function hasPerSleeveMarkets(markets) {
  if (!markets || typeof markets !== "object") return false;
  return (
    markets.money != null ||
    markets.stock != null ||
    markets.tech != null ||
    markets.debt != null ||
    markets.gold != null
  );
}

function moneySleeveProfitPkr(markets) {
  if (!hasPerSleeveMarkets(markets)) return 0;
  return Number(markets.money && markets.money.profitPkr) || 0;
}

/**
 * Non-MM P/L for MM cash top-up.
 * Prefer per-sleeve markets when present: amount − markets.money.profitPkr.
 * INCLUDE the whole amount when markets are absent (legacy lump rows).
 */
function extractNonMmProfitPkr(tx) {
  const amt = Number(tx.amount) || 0;
  const metadata = txMetadata(tx);
  const markets = metadata.markets || tx.markets;
  if (hasPerSleeveMarkets(markets)) {
    return roundMoney2(amt - moneySleeveProfitPkr(markets));
  }
  return roundMoney2(amt);
}

function resolvePnlRatePercent(tx, fallbackPercent) {
  const metadata = txMetadata(tx);
  const stamped = readFiniteNumber(
    tx.moneyMarketPnlRatePercent,
    metadata.moneyMarketPnlRatePercent,
  );
  if (stamped != null && stamped >= 0) return stamped;
  const fallback = Number(fallbackPercent);
  if (Number.isFinite(fallback) && fallback >= 0) return fallback;
  return LEGACY_DEPOSIT_MONEY_ALLOCATION_PERCENT;
}

function moneyMarketCreditForDeposit(tx) {
  const amt = Number(tx.amount) || 0;
  const stampedCredit = readFiniteNumber(tx.moneyMarketCreditPkr);
  if (stampedCredit != null) {
    return Math.max(0, roundMoney2(stampedCredit));
  }
  const stampedPct = readFiniteNumber(tx.moneyMarketAllocationPercent);
  const pct =
    stampedPct != null && stampedPct >= 0
      ? stampedPct
      : LEGACY_DEPOSIT_MONEY_ALLOCATION_PERCENT;
  return Math.max(0, roundMoney2(amt * (pct / 100)));
}

function moneyMarketCreditForPnl(tx, fallbackPercent) {
  const metadata = txMetadata(tx);
  const stampedCredit = readFiniteNumber(
    tx.moneyMarketPnlCreditPkr,
    metadata.moneyMarketPnlCreditPkr,
  );
  if (stampedCredit != null) return roundMoney2(stampedCredit);
  const pct = resolvePnlRatePercent(tx, fallbackPercent);
  const nonMm = extractNonMmProfitPkr(tx);
  return roundMoney2(nonMm * (pct / 100));
}

function depositMoneyMarketStamp(amountPkr, allocationPercent) {
  const amt = Number(amountPkr) || 0;
  const pct = Number(allocationPercent);
  const percent =
    Number.isFinite(pct) && pct >= 0
      ? pct
      : LEGACY_DEPOSIT_MONEY_ALLOCATION_PERCENT;
  return {
    moneyMarketAllocationPercent: percent,
    moneyMarketCreditPkr: Math.max(0, roundMoney2(amt * (percent / 100))),
  };
}

function profitMoneyMarketMetadataStamp({
  amountPkr,
  markets,
  allocationPercent,
} = {}) {
  const dummy = { amount: amountPkr, metadata: { markets } };
  const nonMm = extractNonMmProfitPkr(dummy);
  const excluded = roundMoney2(moneySleeveProfitPkr(markets));
  const pct = Number(allocationPercent);
  const percent =
    Number.isFinite(pct) && pct >= 0
      ? pct
      : LEGACY_DEPOSIT_MONEY_ALLOCATION_PERCENT;
  return {
    moneyMarketPnlRatePercent: percent,
    moneyMarketPnlCreditPkr: roundMoney2(nonMm * (percent / 100)),
    moneyProfitPkrExcluded: excluded,
  };
}

/**
 * @param {Array<object>} docs Firestore snapshots or plain transaction maps
 * @param {{ moneyAllocationPercent?: number }} [options]
 *   Fallback Admin money % for unstamped profit/adjustment rows.
 *   Unstamped deposits ignore this and stay at 5%.
 */
function moneyMarketFromTransactions(docs, options = {}) {
  const fallbackPercent = options.moneyAllocationPercent;
  let moneyMarketCreditedTotal = 0;
  let moneyMarketWithdrawnTotal = 0;
  let moneyMarketReserved = 0;

  for (const doc of docs || []) {
    const d = txData(doc);
    const amt = Number(d.amount) || 0;
    const st = String(d.status || "").toLowerCase();
    const ty = String(d.type || "").toLowerCase();

    if (ty === "deposit" && st === "approved") {
      moneyMarketCreditedTotal = roundMoney2(
        moneyMarketCreditedTotal + moneyMarketCreditForDeposit(d),
      );
      continue;
    }

    if (ty === "withdrawal") {
      // pending/approved → reserve full amount; completed → subtract full amount.
      if (st === "pending" || st === "approved") {
        moneyMarketReserved = roundMoney2(moneyMarketReserved + amt);
      } else if (st === "completed") {
        moneyMarketWithdrawnTotal = roundMoney2(moneyMarketWithdrawnTotal + amt);
      }
      continue;
    }

    if (
      (ty === "profit" || ty === "profit_entry") &&
      (st === "approved" || st === "completed")
    ) {
      moneyMarketCreditedTotal = roundMoney2(
        moneyMarketCreditedTotal + moneyMarketCreditForPnl(d, fallbackPercent),
      );
      continue;
    }

    if (ty === "adjustment" && (st === "approved" || st === "completed")) {
      // General portfolio P/L: same non-MM rule. INCLUDE when unknown.
      moneyMarketCreditedTotal = roundMoney2(
        moneyMarketCreditedTotal + moneyMarketCreditForPnl(d, fallbackPercent),
      );
    }
    // Fee types are intentionally omitted from MM cash.
  }

  const moneyMarketBalance = Math.max(
    0,
    roundMoney2(moneyMarketCreditedTotal - moneyMarketWithdrawnTotal),
  );
  const moneyMarketAvailable = Math.max(
    0,
    roundMoney2(moneyMarketBalance - moneyMarketReserved),
  );

  return {
    moneyMarketCreditedTotal,
    moneyMarketWithdrawnTotal,
    moneyMarketReserved,
    moneyMarketBalance,
    moneyMarketAvailable,
  };
}

module.exports = {
  LEGACY_DEPOSIT_MONEY_ALLOCATION_PERCENT,
  roundMoney2,
  moneyAllocationPercentFromAllocations,
  allocationsSum,
  inspectMoneyAllocation,
  extractNonMmProfitPkr,
  depositMoneyMarketStamp,
  profitMoneyMarketMetadataStamp,
  moneyMarketFromTransactions,
};
