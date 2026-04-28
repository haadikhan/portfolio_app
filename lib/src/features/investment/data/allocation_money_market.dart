/// Percentage of the illustrative allocation assigned to Money Market
/// ([`allocation_pie_chart_widget.dart`]). Keep in sync with that UI.
const double kMoneyMarketAllocationPercent = 5.0;

/// Same rule as segment amounts in the allocation pie: [percentage] of [total].
double allocationAmountFromTotal(double total, double percentage) {
  if (!total.isFinite || total <= 0) return 0;
  return total * (percentage / 100);
}

/// PKR in the Money Market slice for a given allocation base total.
double moneyMarketAmountFromAllocationTotal(double total) =>
    allocationAmountFromTotal(total, kMoneyMarketAllocationPercent);

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

/// Net-invested allocation total used by dashboard / wallet hero / portfolio
/// allocation pie. Drops by completed withdrawals (matches user's chosen model:
/// 100,000 deposit, 100 withdrawn => Total = 99,900).
///
/// Pending/reserved withdrawals do NOT shrink this number — they only reduce
/// `availableBalance`, leaving Total at its post-settlement value.
double allocationTotalFromWallet(Map<String, dynamic>? wallet) {
  final deposited = _safeNum(wallet?["totalDeposited"]);
  final profit = _safeNum(wallet?["totalProfit"]);
  final adjustments = _safeNum(wallet?["totalAdjustments"]);
  final withdrawn = _safeNum(wallet?["totalWithdrawn"]);
  final net = deposited + profit + adjustments - withdrawn;
  return net > 0 ? net : 0;
}
