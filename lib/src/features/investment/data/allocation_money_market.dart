// Illustrative allocation percentages — single source for pie chart + portfolio tabs.
// Must sum to 100.

/// Money market / liquidity sleeve ([`allocation_pie_chart_widget.dart`]).
@Deprecated("Use FiveMarketConfig.defaults.allocations instead")
const double kMoneyMarketAllocationPercent = 5.0;

/// Listed equities / PSX-oriented sleeve.
@Deprecated("Use FiveMarketConfig.defaults.allocations instead")
const double kStockMarketAllocationPercent = 40.0;

/// Technology-oriented growth sleeve.
@Deprecated("Use FiveMarketConfig.defaults.allocations instead")
const double kTechAllocationPercent = 25.0;

/// Debt / income sleeve (e.g. Sukuk).
@Deprecated("Use FiveMarketConfig.defaults.allocations instead")
const double kDebtMarketAllocationPercent = 25.0;

/// Alternative sleeve represented here as digital gold / commodities-style exposure.
@Deprecated("Use FiveMarketConfig.defaults.allocations instead")
const double kAlternativeAssetAllocationPercent = 5.0;

/// Same rule as segment amounts in the allocation pie: [percentage] of [total].
double allocationAmountFromTotal(double total, double percentage) {
  if (!total.isFinite || total <= 0) return 0;
  return total * (percentage / 100);
}

/// PKR in the Money Market slice for a given allocation base total.
double moneyMarketAmountFromAllocationTotal(double total) =>
    allocationAmountFromTotal(total, kMoneyMarketAllocationPercent);

/// PKR in the alternative / digital-gold illustrative sleeve.
double digitalGoldSleeveAmountFromTotal(double total) =>
    allocationAmountFromTotal(total, kAlternativeAssetAllocationPercent);

/// PKR in the stock illustrative sleeve.
double stockSleeveAmountFromTotal(double total) =>
    allocationAmountFromTotal(total, kStockMarketAllocationPercent);

/// PKR in the tech illustrative sleeve.
double techSleeveAmountFromTotal(double total) =>
    allocationAmountFromTotal(total, kTechAllocationPercent);

/// PKR in the debt illustrative sleeve.
double debtSleeveAmountFromTotal(double total) =>
    allocationAmountFromTotal(total, kDebtMarketAllocationPercent);

double _safeNum(dynamic raw) {
  if (raw is num && raw.isFinite) return raw.toDouble();
  return 0;
}

/// True iff the wallet document carries the new money-market schema fields
/// produced by the latest `recalculateWallet`. Used to choose between the
/// explicit values and the legacy-field fallback.
bool _hasNewMoneyMarketSchema(Map<String, dynamic>? wallet) {
  if (wallet == null) return false;
  return wallet.containsKey("moneyMarketCreditedTotal") ||
      wallet.containsKey("moneyMarketAvailable") ||
      wallet.containsKey("moneyMarketBalance") ||
      wallet.containsKey("moneyMarketWithdrawnTotal") ||
      wallet.containsKey("moneyMarketReserved");
}

/// Money market gross balance after settlements (before reservations).
///
/// New schema:  `moneyMarketCreditedTotal - moneyMarketWithdrawnTotal`.
/// Legacy fallback: in the canonical contract, money-market withdrawals equal
/// the FULL withdrawal amount, so legacy `totalWithdrawn` is a valid stand-in
/// for `moneyMarketWithdrawnTotal` and `5% * totalDeposited` is a valid
/// stand-in for `moneyMarketCreditedTotal`. This makes the dashboard correct
/// even when the wallet document hasn't been recalculated since the new MM
/// fields were introduced.
double moneyMarketBalanceFromWallet(Map<String, dynamic>? wallet) {
  if (_hasNewMoneyMarketSchema(wallet)) {
    final explicit = _safeNum(wallet?["moneyMarketBalance"]);
    if (explicit > 0) return explicit;
    final credited = _safeNum(wallet?["moneyMarketCreditedTotal"]);
    final withdrawn = _safeNum(wallet?["moneyMarketWithdrawnTotal"]);
    final derived = credited - withdrawn;
    return derived > 0 ? derived : 0;
  }

  final deposited = _safeNum(wallet?["totalDeposited"]);
  final legacyWithdrawn = _safeNum(wallet?["totalWithdrawn"]);
  final fallbackCredited = moneyMarketAmountFromAllocationTotal(deposited);
  final fallback = fallbackCredited - legacyWithdrawn;
  return fallback > 0 ? fallback : 0;
}

/// Money market currently free to withdraw (after reservations).
///
/// New schema:  `moneyMarketAvailable` if explicit, else `balance - moneyMarketReserved`.
/// Legacy fallback: legacy `reservedAmount` matches `moneyMarketReserved` in
/// the canonical contract, so it's a valid stand-in.
double moneyMarketAvailableFromWallet(Map<String, dynamic>? wallet) {
  if (_hasNewMoneyMarketSchema(wallet)) {
    final explicit = _safeNum(wallet?["moneyMarketAvailable"]);
    if (explicit > 0) return explicit;
    final balance = moneyMarketBalanceFromWallet(wallet);
    final reserved = _safeNum(wallet?["moneyMarketReserved"]);
    final derived = balance - reserved;
    return derived > 0 ? derived : 0;
  }

  final balance = moneyMarketBalanceFromWallet(wallet);
  final reserved = _safeNum(wallet?["reservedAmount"]);
  final derived = balance - reserved;
  return derived > 0 ? derived : 0;
}

/// Gross capital before fees: deposits − withdrawals + credited profit/adjustments.
///
/// Pending/reserved withdrawals do NOT shrink this number — they only reduce
/// `availableBalance`, leaving this at its post-settlement value.
double allocationTotalFromWallet(Map<String, dynamic>? wallet) {
  final deposited = _safeNum(wallet?["totalDeposited"]);
  final profit = _safeNum(wallet?["totalProfit"]);
  final adjustments = _safeNum(wallet?["totalAdjustments"]);
  final withdrawn = _safeNum(wallet?["totalWithdrawn"]);
  final net = deposited + profit + adjustments - withdrawn;
  return net > 0 ? net : 0;
}

/// Actual current portfolio capital after fees (and before today's uncredited P/L).
///
/// Uses `availableBalance + reservedAmount` from the wallet ledger (fees already
/// deducted). Falls back to [allocationTotalFromWallet] minus `totalFees`.
double netPortfolioValueFromWallet(Map<String, dynamic>? wallet) {
  if (wallet == null) return 0;
  final avail = _safeNum(wallet["availableBalance"]);
  final reserved = _safeNum(wallet["reservedAmount"]);
  final fromLedger = avail + reserved;
  if (fromLedger > 0) return fromLedger;
  final fees = _safeNum(wallet["totalFees"]);
  final gross = allocationTotalFromWallet(wallet);
  final net = gross - fees;
  return net > 0 ? net : 0;
}

/// Canonical allocation base for all investor-facing "Allocated PKR"
/// displays. Wraps netPortfolioValueFromWallet for consistency with
/// dashboard, sleeve balances, and backend fee engine.
double investorAllocationBaseFromWallet(Map<String, dynamic>? wallet) {
  return netPortfolioValueFromWallet(wallet);
}
