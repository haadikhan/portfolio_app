import "dart:convert";

import "package:http/http.dart" as http;
import "package:rxdart/rxdart.dart";

import "../models/kmi30_bar.dart";
import "../models/kmi30_index_tick.dart";
import "../models/kmi30_tick.dart";
import "../websocket/psx_websocket_service.dart";

class PsxRepository {
  PsxRepository(this._ws, {http.Client? client})
    : _client = client ?? http.Client();

  final PsxWebSocketService _ws;
  final http.Client _client;

  Stream<Kmi30Tick> streamAllTicks() => _ws.ticks;

  Stream<Kmi30Tick> streamTicksForSymbol(String symbol) {
    final s = symbol.trim().toUpperCase();
    return _ws.ticks
        .where((t) => t.symbol.toUpperCase() == s)
        .throttleTime(const Duration(milliseconds: 500));
  }

  Stream<PsxWsStatus> connectionStatusStream() => _ws.status;

  Kmi30Tick? latestCachedTick(String symbol) => _ws.latestForSymbol(symbol);

  bool get isWsConnected => _ws.isConnected;

  void connectWebSocket() => _ws.connect();

  /// Updates WS cache and broadcasts to tick listeners (REST priming).
  void seedTick(Kmi30Tick tick) => _ws.seedTick(tick);

  Future<Kmi30Tick> fetchTick(String symbol, {String market = "EQ"}) async {
    final s = symbol.trim().toUpperCase();
    final preferred = Uri.parse("https://psxterminal.com/api/ticks/$market/$s");
    final fallback = Uri.parse("https://psxterminal.com/api/ticks/IDX/$s");

    Future<Kmi30Tick> tryUrl(Uri url) async {
      final res = await _client.get(url);
      if (res.statusCode != 200) {
        throw Exception("HTTP ${res.statusCode}");
      }
      final json = jsonDecode(res.body);
      if (json is! Map<String, dynamic>) {
        throw Exception("Invalid JSON shape.");
      }
      if (json["success"] != true) {
        throw Exception("PSX response indicates failure.");
      }
      return Kmi30Tick.fromRestJson(json);
    }

    try {
      return await tryUrl(preferred);
    } catch (_) {
      return tryUrl(fallback);
    }
  }

  Future<List<Kmi30Bar>> fetchKlines(
    String symbol,
    String timeframe, {
    int limit = 30,
  }) async {
    final s = symbol.trim().toUpperCase();
    final tf = timeframe.trim().toLowerCase();
    final uri = Uri.parse(
      "https://psxterminal.com/api/klines/$s/$tf?limit=$limit",
    );
    final res = await _client.get(uri);
    if (res.statusCode == 403) {
      throw Exception(
        "Chart data unavailable. Market data access restricted.",
      );
    }
    if (res.statusCode != 200) {
      throw Exception("Klines request failed (HTTP ${res.statusCode}).");
    }
    final json = jsonDecode(res.body);
    if (json is! Map<String, dynamic>) {
      throw Exception("Invalid klines payload.");
    }
    if (json["success"] != true) {
      throw Exception("Klines response indicates failure.");
    }
    final data = json["data"];
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => Kmi30Bar.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// Latest index from **daily klines** (same path as charts). Bars are sorted by
  /// time so API order (asc/desc) does not matter. Day change matches PSX **vs
  /// previous close** when two bars exist; with one bar only, change uses
  /// session open → last (approximate; UI may show a footnote).
  Future<Kmi30IndexTick?> fetchIndexTick(String symbol) async {
    try {
      final s = symbol.trim().toUpperCase();
      final bars = await fetchKlines(
        s,
        "1d",
        limit: 2,
      ).timeout(const Duration(seconds: 10));
      if (bars.isEmpty) {
        return null;
      }
      final sorted = [...bars]
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      final today = sorted.last;
      if (today.close == 0) {
        return null;
      }

      final bool usesPriorClose = sorted.length >= 2;
      final double baseline;
      final double? previousClose;
      if (usesPriorClose) {
        final prev = sorted[sorted.length - 2];
        baseline = prev.close;
        previousClose = prev.close;
      } else {
        baseline = today.open;
        previousClose = null;
      }
      if (baseline == 0) {
        return null;
      }

      final changeAbs = today.close - baseline;
      final changePct = (changeAbs / baseline) * 100;

      return Kmi30IndexTick(
        currentValue: today.close,
        changeAbsolute: double.parse(changeAbs.toStringAsFixed(2)),
        changePercent: double.parse(changePct.toStringAsFixed(4)),
        high: today.high,
        low: today.low,
        volume: today.volume,
        previousClose: previousClose,
        sessionOpen: today.open != 0 ? today.open : null,
        dayChangeUsesPriorClose: usesPriorClose,
        receivedAt: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }
}
