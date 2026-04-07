import "package:cloud_functions/cloud_functions.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../models/market_daily_bar.dart";
import "../../providers/auth_providers.dart";
import "../../providers/market_providers.dart";

final adminMarketCompaniesProvider = StreamProvider(
  (ref) => ref.read(marketDataServiceProvider).watchCompanies(activeOnly: false),
);

final adminSelectedCompanyIdProvider = StateProvider<String?>((ref) => null);

final adminSelectedCompanyProvider = Provider((ref) {
  final companies = ref.watch(adminMarketCompaniesProvider).valueOrNull ?? const [];
  final selectedId = ref.watch(adminSelectedCompanyIdProvider);
  if (companies.isEmpty) return null;
  if (selectedId == null || selectedId.isEmpty) return companies.first;
  for (final c in companies) {
    if (c.id == selectedId) return c;
  }
  return companies.first;
});

final adminSelectedCompanyBarsProvider = StreamProvider<List<MarketDailyBar>>((ref) {
  final selected = ref.watch(adminSelectedCompanyProvider);
  if (selected == null) return Stream.value(const <MarketDailyBar>[]);
  return ref.read(marketDataServiceProvider).watchDailyBars(selected.id, limit: 365);
});

final marketFunctionsProvider = Provider<FirebaseFunctions>(
  (_) => FirebaseFunctions.instanceFor(region: "us-central1"),
);

final adminActorUidProvider = Provider<String?>(
  (ref) => ref.watch(currentUserProvider)?.uid,
);
