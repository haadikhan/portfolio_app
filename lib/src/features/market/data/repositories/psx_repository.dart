import "dart:convert";

import "package:http/http.dart" as http;
import "package:rxdart/rxdart.dart";

import "../models/kmi30_bar.dart";
import "../models/kmi30_index_tick.dart";
import "../models/kmi30_tick.dart";
import "../websocket/psx_websocket_service.dart";

class PsxRepository {
  PsxRepository(this._ws, {http.Client? client}) : _client = client ?? http.Client();

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
    final uri = Uri.parse("https://psxterminal.com/api/klines/$s/$tf?limit=$limit");
    final res = await _client.get(uri);
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

  /// Latest index level from **klines** (ticks/IDX is unreliable from Flutter HTTP).
  Future<Kmi30IndexTick?> fetchIndexTick(String symbol) async {
    try {
      final s = symbol.trim().toUpperCase();
      final uri = Uri.parse("https://psxterminal.com/api/klines/$s/1d?limit=2");
      final response = await _client.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        return null;
      }
      final decoded = jsonDecode(response.body);

      List<dynamic> bars = [];
      if (decoded is List) {
        bars = decoded;
      } else if (decoded is Map) {
        final m = Map<String, dynamic>.from(decoded);
        if (m["success"] != true) {
          return null;
        }
        final inner = m["data"] ?? m["bars"] ?? m["candles"];
        if (inner is List) {
          bars = inner;
        }
      }
      if (bars.isEmpty) {
        return null;
      }

      double v(dynamic x) =>
          x == null ? 0.0 : double.tryParse(x.toString()) ?? 0.0;

      double openFromBar(dynamic bar) {
        if (bar is List && bar.length > 2) {
          return v(bar[1]);
        }
        if (bar is Map) {
          return v(Map<String, dynamic>.from(bar)["open"]);
        }
        return 0;
      }

      double closeFromBar(dynamic bar) {
        if (bar is List && bar.length > 5) {
          return v(bar[4]);
        }
        if (bar is Map) {
          return v(Map<String, dynamic>.from(bar)["close"]);
        }
        return 0;
      }

      double? highFromBar(dynamic bar) {
        if (bar is List && bar.length > 3) {
          return v(bar[2]);
        }
        if (bar is Map) {
          final h = Map<String, dynamic>.from(bar)["high"];
          return h != null ? v(h) : null;
        }
        return null;
      }

      double? lowFromBar(dynamic bar) {
        if (bar is List && bar.length > 4) {
          return v(bar[3]);
        }
        if (bar is Map) {
          final l = Map<String, dynamic>.from(bar)["low"];
          return l != null ? v(l) : null;
        }
        return null;
      }

      double? volFromBar(dynamic bar) {
        if (bar is List && bar.length > 6) {
          return v(bar[5]);
        }
        if (bar is Map) {
          final vol = Map<String, dynamic>.from(bar)["volume"];
          return vol != null ? v(vol) : null;
        }
        return null;
      }

      final bar = bars.last;
      final open = openFromBar(bar);
      final close = closeFromBar(bar);
      if (close == 0 || open == 0) {
        return null;
      }

      final changeAbs = close - open;
      final changePct = (changeAbs / open) * 100;

      return Kmi30IndexTick(
        currentValue: close,
        changeAbsolute: double.parse(changeAbs.toStringAsFixed(2)),
        changePercent: double.parse(changePct.toStringAsFixed(4)),
        high: highFromBar(bar),
        low: lowFromBar(bar),
        volume: volFromBar(bar),
        receivedAt: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }
}
