import "package:flutter_riverpod/flutter_riverpod.dart";

import "../models/market_daily_bar.dart";
import "../services/market_data_service.dart";
import "auth_providers.dart";

final marketDataServiceProvider = Provider<MarketDataService>(
  (ref) => MarketDataService(ref.read(firebaseFirestoreProvider)),
);

final marketCompaniesProvider = StreamProvider(
  (ref) => ref.read(marketDataServiceProvider).watchCompanies(activeOnly: true),
);

final selectedMarketCompanyIdProvider = StateProvider<String?>((ref) => null);

final selectedMarketCompanyProvider = Provider((ref) {
  final companies = ref.watch(marketCompaniesProvider).valueOrNull ?? const [];
  final selectedId = ref.watch(selectedMarketCompanyIdProvider);
  if (companies.isEmpty) return null;
  if (selectedId == null || selectedId.isEmpty) return companies.first;
  for (final c in companies) {
    if (c.id == selectedId) return c;
  }
  return companies.first;
});

final marketDailyBarsProvider = StreamProvider<List<MarketDailyBar>>((ref) {
  final selected = ref.watch(selectedMarketCompanyProvider);
  if (selected == null) return Stream.value(const []);
  return ref.read(marketDataServiceProvider).watchDailyBars(selected.id);
});
