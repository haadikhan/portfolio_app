import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../market/data/gold_units.dart";
import "../../../market/data/models/gold_price_quote.dart";
import "../../../market/presentation/providers/kmi30_companies_providers.dart";

/// Latest gold quote (stream → initial fetch → last known cache).
final goldMarketQuoteProvider = Provider<GoldPriceQuote?>((ref) {
  ref.watch(goldPriceStreamProvider);
  ref.watch(goldPriceInitialProvider);
  return ref.watch(goldPriceStreamProvider).valueOrNull ??
      ref.watch(goldPriceInitialProvider).valueOrNull ??
      ref.watch(goldPriceLastKnownProvider);
});

/// PKR per Pakistani tola — same quote stack as five-market daily / KMI30 gold card.
final goldPricePerTolaProvider = Provider<double?>((ref) {
  final quote = ref.watch(goldMarketQuoteProvider);
  if (quote == null || quote.xauPkr <= 0) return null;
  final pkrPerTola = pkrPerTolaFromPkrPerTroyOz(quote.xauPkr);
  return (pkrPerTola * 100).round() / 100;
});
