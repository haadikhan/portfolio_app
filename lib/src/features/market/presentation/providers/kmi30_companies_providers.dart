import "dart:async";

import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../data/gold_units.dart";
import "../../data/kmi30_seed_companies.dart";
import "../../data/models/gold_price_quote.dart";
import "../../data/models/kmi30_bar.dart";
import "../../data/models/kmi30_company.dart";
import "../../data/models/kmi30_tick.dart";
import "../../data/repositories/gold_price_repository.dart";
import "../../data/repositories/psx_repository.dart";
import "../../data/websocket/psx_websocket_service.dart";

final kmi30CompaniesProvider = Provider<List<Kmi30Company>>(
  (_) => kmi30SeedCompanies,
);

final companySearchQueryProvider = StateProvider<String>((_) => "");

final filteredKmi30CompaniesProvider = Provider<List<Kmi30Company>>((ref) {
  final all = ref.watch(kmi30CompaniesProvider);
  final q = ref.watch(companySearchQueryProvider).trim().toLowerCase();
  if (q.isEmpty) return all;
  return all
      .where(
        (c) =>
            c.symbol.toLowerCase().contains(q) ||
            c.name.toLowerCase().contains(q),
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

final selectedCompanyInitialTickProvider = Provider.family<Kmi30Tick?, String>((
  ref,
  symbol,
) {
  return ref.read(psxRepositoryProvider).latestCachedTick(symbol);
});

final selectedCompanyLiveTickStreamProvider =
    StreamProvider.family<Kmi30Tick, String>((ref, symbol) {
      return ref.read(psxRepositoryProvider).streamTicksForSymbol(symbol);
    });

/// REST snapshot for immediate UI (never waits on WebSocket first emit).
final kmi30RestTickProvider = FutureProvider.family<Kmi30Tick, String>((
  ref,
  symbol,
) async {
  final repo = ref.read(psxRepositoryProvider);
  final t = await repo.fetchTick(symbol);
  repo.seedTick(t);
  return t;
});

/// Latest daily bars for session OHLC (independent of chart timeframe).
final companyDailyOhlcBarsProvider =
    FutureProvider.family<List<Kmi30Bar>, String>((ref, symbol) async {
      return ref
          .read(psxRepositoryProvider)
          .fetchKlines(symbol, "1d", limit: 2);
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

// ─── Gold spot (KMI30 screen only) ─────────────────────────────────────────

/// PKR line: per troy oz (international) vs per Pakistani tola (11.664 g).
final goldPkrUnitProvider = StateProvider<GoldPkrUnit>(
  (_) => GoldPkrUnit.tola,
);

final goldPriceRepositoryProvider = Provider<GoldPriceRepository>((ref) {
  final repo = GoldPriceRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

/// Bumps when the user taps refresh so [goldPriceStreamProvider] rebuilds.
final goldPriceRefreshCounterProvider =
    NotifierProvider<_GoldPriceRefreshCounter, int>(
      _GoldPriceRefreshCounter.new,
    );

final goldPriceLastKnownProvider = StateProvider<GoldPriceQuote?>((_) => null);

/// One-shot fetch for the first frame.
final goldPriceInitialProvider = FutureProvider<GoldPriceQuote>((ref) async {
  ref.watch(goldPriceRefreshCounterProvider);
  final repo = ref.read(goldPriceRepositoryProvider);
  final quote = await repo.fetchGoldQuote();
  ref.read(goldPriceLastKnownProvider.notifier).state = quote;
  return quote;
});

/// Emits on load, every 60s, and when [goldPriceRefreshCounterProvider] changes.
/// On failure, re-emits last successful quote if available.
final goldPriceStreamProvider = StreamProvider<GoldPriceQuote>((ref) {
  ref.watch(goldPriceRefreshCounterProvider);
  final repo = ref.read(goldPriceRepositoryProvider);
  final cache = ref.read(goldPriceLastKnownProvider.notifier);

  final controller = StreamController<GoldPriceQuote>();

  Future<void> tick() async {
    try {
      final q = await repo.fetchGoldQuote();
      cache.state = q;
      if (!controller.isClosed) controller.add(q);
    } catch (e, st) {
      final last = cache.state;
      if (last != null) {
        if (!controller.isClosed) controller.add(last);
      } else if (!controller.isClosed) {
        controller.addError(e, st);
      }
    }
  }

  unawaited(tick());
  final timer = Timer.periodic(const Duration(seconds: 60), (_) => tick());
  ref.onDispose(() {
    timer.cancel();
    unawaited(controller.close());
  });

  return controller.stream;
});

class _GoldPriceRefreshCounter extends Notifier<int> {
  @override
  int build() => 0;

  void refresh() => state++;
}

/// Gold detail chart only — same labels as KMI30 (`1m`…`1d`), independent of company charts.
final goldChartTimeframeProvider = StateProvider<String>((_) => "1d");

final goldChartTypeProvider = StateProvider<String>((_) => "line");

/// Binance PAXG klines in PKR (see [GoldPriceRepository.fetchPaxgKlinesPkr]).
final goldDetailKlinesProvider = FutureProvider<List<Kmi30Bar>>((ref) async {
  final tf = ref.watch(goldChartTimeframeProvider);
  final repo = ref.read(goldPriceRepositoryProvider);
  return repo.fetchPaxgKlinesPkr(tf, limit: 30);
});
