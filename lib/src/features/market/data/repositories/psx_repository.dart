import "dart:convert";

import "package:http/http.dart" as http;

import "../models/kmi30_bar.dart";
import "../models/kmi30_tick.dart";
import "../websocket/psx_websocket_service.dart";

class PsxRepository {
  PsxRepository(this._ws, {http.Client? client}) : _client = client ?? http.Client();

  final PsxWebSocketService _ws;
  final http.Client _client;

  Stream<Kmi30Tick> streamAllTicks() => _ws.ticks;

  Stream<Kmi30Tick> streamTicksForSymbol(String symbol) {
    final s = symbol.trim().toUpperCase();
    return _ws.ticks.where((t) => t.symbol.toUpperCase() == s);
  }

  Stream<PsxWsStatus> connectionStatusStream() => _ws.status;

  Kmi30Tick? latestCachedTick(String symbol) => _ws.latestForSymbol(symbol);

  bool get isWsConnected => _ws.isConnected;

  void connectWebSocket() => _ws.connect();

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
}
