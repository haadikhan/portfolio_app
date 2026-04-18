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
