import "dart:async";

import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../data/kmi30_seed_companies.dart";
import "../../data/models/kmi30_bar.dart";
import "../../data/models/kmi30_company.dart";
import "../../data/models/kmi30_tick.dart";
import "../../data/repositories/psx_repository.dart";
import "../../data/websocket/psx_websocket_service.dart";

final kmi30CompaniesProvider = Provider<List<Kmi30Company>>((_) => kmi30SeedCompanies);

final companySearchQueryProvider = StateProvider<String>((_) => "");

final filteredKmi30CompaniesProvider = Provider<List<Kmi30Company>>((ref) {
  final all = ref.watch(kmi30CompaniesProvider);
  final q = ref.watch(companySearchQueryProvider).trim().toLowerCase();
  if (q.isEmpty) return all;
  return all
      .where(
        (c) =>
            c.symbol.toLowerCase().contains(q) || c.name.toLowerCase().contains(q),
      )
      .toList();
});

final selectedCompanySymbolProvider = StateProvider<String?>(
  (ref) => kmi30SeedCompanies.first.symbol,
);

final selectedTimeframeProvider = StateProvider<String>((_) => "1d");
final selectedChartTypeProvider = StateProvider<String>((_) => "line");

final webSocketServiceProvider = Provider<PsxWebSocketService>((ref) {
  final svc = PsxWebSocketService(
    symbols: kmi30SeedCompanies.map((e) => e.symbol).toList(),
  );
  svc.connect();
  ref.onDispose(() {
    unawaited(svc.dispose());
  });
  return svc;
});

final psxRepositoryProvider = Provider<PsxRepository>((ref) {
  return PsxRepository(ref.read(webSocketServiceProvider));
});

final wsConnectionStatusProvider = StreamProvider<PsxWsStatus>((ref) {
  return ref.read(psxRepositoryProvider).connectionStatusStream();
});

final selectedCompanyInitialTickProvider =
    Provider.family<Kmi30Tick?, String>((ref, symbol) {
  return ref.read(psxRepositoryProvider).latestCachedTick(symbol);
});

final selectedCompanyLiveTickStreamProvider =
    StreamProvider.family<Kmi30Tick, String>((ref, symbol) {
  return ref.read(psxRepositoryProvider).streamTicksForSymbol(symbol);
});

/// REST snapshot for immediate UI (never waits on WebSocket first emit).
final kmi30RestTickProvider = FutureProvider.family<Kmi30Tick, String>((ref, symbol) async {
  final repo = ref.read(psxRepositoryProvider);
  final t = await repo.fetchTick(symbol);
  repo.seedTick(t);
  return t;
});

/// Latest daily bars for session OHLC (independent of chart timeframe).
final companyDailyOhlcBarsProvider =
    FutureProvider.family<List<Kmi30Bar>, String>((ref, symbol) async {
  return ref.read(psxRepositoryProvider).fetchKlines(symbol, "1d", limit: 2);
});

final selectedCompanyKlinesProvider =
    FutureProvider.family<List<Kmi30Bar>, String>((ref, symbol) async {
  final tf = ref.watch(selectedTimeframeProvider);
  return ref.read(psxRepositoryProvider).fetchKlines(symbol, tf, limit: 30);
});

/// One-shot fallback for UI when websocket is disconnected.
final selectedCompanyRestFallbackTickProvider =
    FutureProvider.family<Kmi30Tick, String>((ref, symbol) async {
  return ref.read(psxRepositoryProvider).fetchTick(symbol);
});
