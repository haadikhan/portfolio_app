import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:http/http.dart" as http;

import "../models/kmi30_tick.dart";

class AhleTradeRepository {
  AhleTradeRepository({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  static const _base =
      "http://feed.ahletrade.com/HTTPFeedServer/FeedFetcher";

  Future<Kmi30Tick> fetchTick(String symbol) async {
    final s = symbol.trim().toUpperCase();
    try {
      final pvUri = Uri.parse(
        "$_base?action=Market&identifier=PriceVolume&market=REG&symbol=$s",
      );
      final bsUri = Uri.parse(
        "$_base?action=Market&identifier=BuySell&market=REG&symbol=$s",
      );

      final results = await Future.wait([
        _client.get(pvUri),
        _client.get(bsUri),
      ]);

      final pvRes = results[0];
      final bsRes = results[1];

      if (pvRes.statusCode != 200) {
        throw Exception("PriceVolume HTTP ${pvRes.statusCode}");
      }
      if (bsRes.statusCode != 200) {
        throw Exception("BuySell HTTP ${bsRes.statusCode}");
      }

      // PriceVolume: "HH:MM:SS;bid;ask| HH:MM:SS;bid;ask|..."
      final pvBody = pvRes.body.trim();
      final pvEntries =
          pvBody.split("|").map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

      double bid = 0;
      double ask = 0;
      if (pvEntries.isNotEmpty) {
        final lastPv = pvEntries.last.split(";");
        if (lastPv.length >= 3) {
          bid = double.tryParse(lastPv[1]) ?? 0;
          ask = double.tryParse(lastPv[2]) ?? 0;
        }
      }

      // BuySell: "HH:MM:SS;price;volume| ..."
      final bsBody = bsRes.body.trim();
      final bsEntries =
          bsBody.split("|").map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

      double price = 0;
      double open = 0;
      double high = 0;
      double low = double.infinity;
      double totalVolume = 0;

      for (int i = 0; i < bsEntries.length; i++) {
        final parts = bsEntries[i].split(";");
        if (parts.length < 3) continue;
        final p = double.tryParse(parts[1]) ?? 0;
        final v = double.tryParse(parts[2]) ?? 0;
        totalVolume += v;
        if (p > 0) {
          if (i == 0) open = p;
          if (p > high) high = p;
          if (p < low) low = p;
        }
      }

      if (bsEntries.isNotEmpty) {
        final lastBs = bsEntries.last.split(";");
        if (lastBs.length >= 2) {
          price = double.tryParse(lastBs[1]) ?? 0;
        }
      }

      if (low == double.infinity) low = 0;

      // Use mid-price as price when BuySell body is empty
      if (price == 0 && bid > 0 && ask > 0) {
        price = (bid + ask) / 2;
      }
      if (open == 0) open = price;

      final changePercent =
          open > 0 ? (price - open) / open * 100 : 0.0;

      return Kmi30Tick(
        symbol: s,
        price: price,
        change: price - open,
        changePercent: changePercent,
        open: open,
        high: high > 0 ? high : price,
        low: low > 0 ? low : price,
        volume: totalVolume,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      throw Exception("AhleTrade fetch failed for $s: $e");
    }
  }
}

final ahleTradeRepositoryProvider = Provider<AhleTradeRepository>(
  (ref) => AhleTradeRepository(),
);
