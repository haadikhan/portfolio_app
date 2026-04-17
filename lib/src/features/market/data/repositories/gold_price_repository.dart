import "dart:convert";

import "package:http/http.dart" as http;

import "../models/gold_price_quote.dart";
import "../models/kmi30_bar.dart";

class GoldPriceRepository {
  GoldPriceRepository({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  static const Duration _timeout = Duration(seconds: 12);

  static const String _metalsApiKey = String.fromEnvironment(
    "GOLD_API_KEY",
    defaultValue: "",
  );
  static const String _metalsQuoteUrl = String.fromEnvironment(
    "GOLD_QUOTE_URL",
    defaultValue: "https://api.metals.dev/v1/latest",
  );

  /// Public open-access FX. See https://www.exchangerate-api.com/docs/free
  static const String _openErLatestUsd =
      "https://open.er-api.com/v6/latest/USD";

  /// Free USD cross-table (PKR, XAU as oz per 1 USD, etc.). No API key.
  /// See https://github.com/fawazahmed0/exchange-api
  static const String _freeUsdCurrenciesJson =
      "https://latest.currency-api.pages.dev/v1/currencies/usd.json";

  static const String _coinbasePaxgUsd =
      "https://api.coinbase.com/v2/prices/PAXG-USD/spot";

  static const String _binancePaxgUsdtTicker =
      "https://api.binance.com/api/v3/ticker/price?symbol=PAXGUSDT";

  static const Map<String, String> _jsonHeaders = <String, String>{
    "Accept": "application/json",
    "User-Agent": "PortfolioApp/1.0 (Flutter; gold spot)",
  };

  Future<GoldPriceQuote> fetchGoldQuote() async {
    final metals = await _tryFetchMetalsDevLatest();
    if (metals != null) {
      final usdPkr = metals.usdPkr ?? await _fetchUsdPkrWithFallbacks();
      final source = metals.usdPkr != null
          ? "metals.dev"
          : "metals.dev + ${_usdPkrSourceLabel()}";
      return _quote(
        xauUsd: metals.xauUsd,
        usdPkr: usdPkr,
        source: source,
      );
    }

    try {
      final q = await _fetchQuoteFromFreeUsdCurrencyTable();
      return q;
    } catch (_) {}

    try {
      final xauUsd = await _fetchXauUsdBinancePaxg();
      final usdPkr = await _fetchUsdPkrWithFallbacks();
      return _quote(
        xauUsd: xauUsd,
        usdPkr: usdPkr,
        source: "binance PAXG/USDT + ${_usdPkrSourceLabel()}",
      );
    } catch (_) {}

    try {
      final xauUsd = await _fetchXauUsdCoinbasePaxg();
      final usdPkr = await _fetchUsdPkrWithFallbacks();
      return _quote(
        xauUsd: xauUsd,
        usdPkr: usdPkr,
        source: "coinbase PAXG/USD + ${_usdPkrSourceLabel()}",
      );
    } catch (e) {
      throw Exception("Could not load gold rates: $e");
    }
  }

  GoldPriceQuote _quote({
    required double xauUsd,
    required double usdPkr,
    required String source,
  }) {
    return GoldPriceQuote(
      xauUsd: xauUsd,
      usdPkr: usdPkr,
      xauPkr: xauUsd * usdPkr,
      timestamp: DateTime.now(),
      source: source,
    );
  }

  String _usdPkrSourceLabel() {
    return "USD/PKR (open.er-api or currency-api)";
  }

  /// Free table: [usd][pkr], [usd][xau] (oz gold per 1 USD when small).
  Future<GoldPriceQuote> _fetchQuoteFromFreeUsdCurrencyTable() async {
    final body = await _getJson(Uri.parse(_freeUsdCurrenciesJson));
    final usd = body["usd"];
    if (usd is! Map) {
      throw Exception("currency-api: missing usd map.");
    }
    final pkr = _readNum(usd["pkr"]);
    if (pkr == null || pkr <= 0) {
      throw Exception("currency-api: missing PKR.");
    }
    final xauUsd = _xauUsdFromFawazCommodity(
      _readNum(usd["xau"]) ?? _readNum(usd["paxg"]),
    );
    return _quote(
      xauUsd: xauUsd,
      usdPkr: pkr,
      source: "currency-api.pages.dev (free)",
    );
  }

  /// Free USD table lists gold as **troy oz per 1 USD** (small fraction) or rarely USD/oz.
  static double _xauUsdFromFawazCommodity(double? raw) {
    if (raw == null || raw <= 0) {
      throw Exception("missing XAU/PAXG in currency table.");
    }
    if (raw >= 500 && raw <= 30000) {
      return raw;
    }
    if (raw < 0.02) {
      return 1.0 / raw;
    }
    throw Exception("unexpected gold quote scale: $raw");
  }

  Future<double> _fetchUsdPkrWithFallbacks() async {
    try {
      return await _fetchUsdPkrOpenErApi();
    } catch (_) {}
    try {
      return await _fetchUsdPkrFromFreeUsdCurrencyTable();
    } catch (_) {}
    throw Exception("USD/PKR unavailable from open.er-api and currency-api.");
  }

  Future<double> _fetchUsdPkrFromFreeUsdCurrencyTable() async {
    final body = await _getJson(Uri.parse(_freeUsdCurrenciesJson));
    final usd = body["usd"];
    if (usd is! Map) throw Exception("currency-api: missing usd.");
    final pkr = _readNum(usd["pkr"]);
    if (pkr == null || pkr <= 0) throw Exception("currency-api: PKR.");
    return pkr;
  }

  Future<double> _fetchXauUsdBinancePaxg() async {
    final body = await _getJson(Uri.parse(_binancePaxgUsdtTicker));
    final p = _readNum(body["price"]);
    if (p == null || p <= 0) {
      throw Exception("binance: bad PAXG price.");
    }
    return p;
  }

  Future<double> _fetchXauUsdCoinbasePaxg() async {
    final body = await _getJson(Uri.parse(_coinbasePaxgUsd));
    final data = body["data"];
    if (data is! Map<String, dynamic>) {
      throw Exception("Unexpected Coinbase payload.");
    }
    final amt = _readNum(data["amount"]);
    if (amt == null || amt <= 0) {
      throw Exception("Invalid PAXG spot.");
    }
    return amt;
  }

  /// Binance PAXG/USDT klines converted to **PKR per troy oz** (matches KMI30 UI
  /// timeframes: 1m, 5m, 15m, 1h, 4h, 1d).
  Future<List<Kmi30Bar>> fetchPaxgKlinesPkr(
    String uiTimeframe, {
    int limit = 30,
  }) async {
    const allowed = <String>{"1m", "5m", "15m", "1h", "4h", "1d"};
    final tf = uiTimeframe.trim().toLowerCase();
    if (!allowed.contains(tf)) {
      throw Exception("Unsupported gold timeframe: $uiTimeframe");
    }
    final lim = limit.clamp(1, 1000);
    final uri = Uri.parse("https://api.binance.com/api/v3/klines").replace(
      queryParameters: <String, String>{
        "symbol": "PAXGUSDT",
        "interval": tf,
        "limit": "$lim",
      },
    );
    final res = await _client.get(uri, headers: _jsonHeaders).timeout(_timeout);
    if (res.statusCode != 200) {
      throw Exception("Binance klines HTTP ${res.statusCode}");
    }
    final parsed = jsonDecode(res.body);
    if (parsed is! List) {
      throw Exception("Binance klines: expected JSON array.");
    }
    final usdPkr = await _fetchUsdPkrWithFallbacks();
    final out = <Kmi30Bar>[];
    for (final row in parsed) {
      if (row is! List || row.length < 6) continue;
      final openMs = (row[0] as num).toInt();
      final o = _readNum(row[1]);
      final h = _readNum(row[2]);
      final l = _readNum(row[3]);
      final c = _readNum(row[4]);
      final vol = _readNum(row[5]) ?? 0;
      if (o == null || h == null || l == null || c == null) continue;
      if (o <= 0 || c <= 0) continue;
      out.add(
        Kmi30Bar(
          symbol: "GOLD",
          timeframe: tf,
          timestamp: DateTime.fromMillisecondsSinceEpoch(openMs, isUtc: true),
          open: o * usdPkr,
          high: h * usdPkr,
          low: l * usdPkr,
          close: c * usdPkr,
          volume: vol,
        ),
      );
    }
    return out;
  }

  Future<_MetalsLatest?> _tryFetchMetalsDevLatest() async {
    if (_metalsApiKey.isEmpty) return null;
    try {
      final base = Uri.parse(_metalsQuoteUrl);
      final qp = Map<String, String>.from(base.queryParameters);
      qp["api_key"] = _metalsApiKey;
      final uri = base.replace(queryParameters: qp);
      final body = await _getJson(uri);
      if (body["status"] != "success") return null;

      final metals = body["metals"];
      final goldUsd = _readNum(metals is Map ? metals["gold"] : null);
      if (goldUsd == null || goldUsd <= 0) return null;

      final cur = body["currencies"];
      double? usdPkr;
      if (cur is Map && cur["PKR"] != null) {
        usdPkr = _pkrPerUsdFromMetalsCurrencies(cur["PKR"]);
      }

      return _MetalsLatest(xauUsd: goldUsd, usdPkr: usdPkr);
    } catch (_) {
      return null;
    }
  }

  Future<double> _fetchUsdPkrOpenErApi() async {
    final body = await _getJson(Uri.parse(_openErLatestUsd));
    if (body["result"] != "success") {
      throw Exception("open.er-api: ${body["error-type"] ?? "failure"}");
    }
    final rates = body["conversion_rates"];
    if (rates is! Map) {
      throw Exception("open.er-api: missing conversion_rates.");
    }
    final pkr = _readNum(rates["PKR"]);
    if (pkr == null || pkr <= 0) {
      throw Exception("open.er-api: missing PKR.");
    }
    return pkr;
  }

  /// metals.dev [currencies] uses **USD per 1 PKR** for PKR (e.g. 0.0035).
  static double _pkrPerUsdFromMetalsCurrencies(dynamic pkrVal) {
    final v = _readNum(pkrVal);
    if (v == null || v <= 0) {
      throw Exception("Invalid PKR in metals payload.");
    }
    if (v < 1) {
      return 1.0 / v;
    }
    return v;
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final res = await _client
        .get(uri, headers: _jsonHeaders)
        .timeout(_timeout);
    if (res.statusCode != 200) {
      throw Exception("HTTP ${res.statusCode}");
    }
    final parsed = jsonDecode(res.body);
    if (parsed is! Map<String, dynamic>) {
      throw Exception("Invalid JSON payload.");
    }
    return parsed;
  }

  static double? _readNum(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  void dispose() => _client.close();
}

class _MetalsLatest {
  const _MetalsLatest({required this.xauUsd, this.usdPkr});

  final double xauUsd;
  final double? usdPkr;
}
