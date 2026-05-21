import "package:flutter/foundation.dart";

/// Immutable. One row in the purchase history report per approved deposit.
@immutable
class SleevePurchaseEntry {
  const SleevePurchaseEntry({
    required this.sno,
    required this.depositDate,
    required this.depositTotal,
    required this.investedPkr,
    this.purchasePricePerTola,
    this.tolasBought,
    this.currentPricePerTola,
    this.precomputedPnl,
    this.note,
  });

  final int sno;
  final DateTime depositDate;

  /// Full deposit amount PKR.
  final double depositTotal;

  /// depositTotal * sleeveAllocPct / 100.
  final double investedPkr;

  /// PKR/tola at deposit date (gold), index value (stock), annual rate% (tech/debt/money).
  final double? purchasePricePerTola;

  /// investedPkr / purchasePricePerTola (tolas for gold, index units for stock).
  /// Null for tech/debt/money.
  final double? tolasBought;

  /// Live PKR/tola (gold), current index (stock), current annual rate% (tech/debt/money).
  final double? currentPricePerTola;

  /// Pre-computed P/L for rate-based sleeves (tech/debt/money).
  final double? precomputedPnl;

  final String? note;

  /// P/L calculation. For rate-based sleeves uses [precomputedPnl].
  /// For market-price sleeves: (currentPrice - purchasePrice) * units.
  double? get netProfitPkr {
    if (precomputedPnl != null) {
      return precomputedPnl;
    }
    if (tolasBought == null ||
        purchasePricePerTola == null ||
        currentPricePerTola == null) {
      return null;
    }
    return (currentPricePerTola! - purchasePricePerTola!) * tolasBought!;
  }

  bool get hasPurchasePrice => purchasePricePerTola != null;
}
