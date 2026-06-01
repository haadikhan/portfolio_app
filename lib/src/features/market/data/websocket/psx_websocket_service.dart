import "dart:async";
import "dart:convert";
import "dart:math";

import "package:flutter/foundation.dart";
import "package:web_socket_channel/web_socket_channel.dart";

import "../models/kmi30_tick.dart";

Map<String, dynamic>? _parseMessage(String raw) {
  try {
    final parsed = jsonDecode(raw);
    if (parsed is Map<String, dynamic>) return parsed;
    if (parsed is Map) return parsed.cast<String, dynamic>();
    return null;
  } catch (_) {
    return null;
  }
}

enum PsxWsStatus { connecting, connected, disconnected, reconnecting }

class PsxWebSocketService {
  PsxWebSocketService({required List<String> symbols})
      : _symbols = symbols.map((e) => e.trim().toUpperCase()).toSet().toList();

  final List<String> _symbols;

  final _ticksController = StreamController<Kmi30Tick>.broadcast();
  final _statusController = StreamController<PsxWsStatus>.broadcast();
  final _latestBySymbol = <String, Kmi30Tick>{};

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _retryTimer;
  bool _disposed = false;
  int _attempt = 0;

  Stream<Kmi30Tick> get ticks => _ticksController.stream;
  Stream<PsxWsStatus> get status => _statusController.stream;

  Kmi30Tick? latestForSymbol(String symbol) =>
      _latestBySymbol[symbol.trim().toUpperCase()];

  bool get isConnected => _channel != null;

  void connect() {
    if (_disposed) return;
    if (_channel != null) return;
    debugPrint("[PSX-WS] Attempting connection...");
    debugPrint("[PSX-WS] URI: wss://psxterminal.com:443/");
    _setStatus(_attempt == 0 ? PsxWsStatus.connecting : PsxWsStatus.reconnecting);
    try {
      final wsUri = Uri(
        scheme: "wss",
        host: "psxterminal.com",
        port: 443,
        path: "/",
      );
      debugPrint("[PSX-WS] Built URI: $wsUri");
      final channel = WebSocketChannel.connect(wsUri);
      _channel = channel;
      channel.ready.then((_) {
        debugPrint("[PSX-WS] Connection ready ✓");
      }).catchError((Object e) {
        debugPrint("[PSX-WS] ready failed: $e");
        debugPrint("[PSX-WS] runtimeType: ${e.runtimeType}");
      });
      _sub = channel.stream.listen(
        _handleMessage,
        onError: (Object e) => _handleDisconnect(e),
        onDone: _handleDisconnect,
        cancelOnError: true,
      );
      _attempt = 0;
      _setStatus(PsxWsStatus.connected);
      _sendSubscribe();
    } catch (_) {
      _handleDisconnect();
    }
  }

  void _sendSubscribe() {
    final ch = _channel;
    if (ch == null) return;
    ch.sink.add(jsonEncode({
      "action": "subscribe",
      "symbols": _symbols,
    }));
    for (var i = 0; i < _symbols.length; i++) {
      final sym = _symbols[i];
      final marketType = sym == "KMI30" ? "IDX" : "EQ";
      ch.sink.add(jsonEncode({
        "type": "subscribe",
        "subscriptionType": "marketData",
        "params": {"marketType": marketType, "symbol": sym},
        "requestId": "kmi30-$i-$sym",
      }));
    }
  }

  /// Seeds cache so UI can show REST priming without waiting for WS.
  void seedTick(Kmi30Tick tick) {
    if (tick.symbol.isEmpty) return;
    _latestBySymbol[tick.symbol.toUpperCase()] = tick;
    _ticksController.add(tick);
  }

  void _handleMessage(dynamic raw) async {
    if (raw is! String) return;
    final map = await compute(_parseMessage, raw);
    if (map == null) return;
    final t = map["type"];
    if (t == "pong" || t == "ping") return;
    if (t == "connected" || t == "subscriptionAck" || t == "error") return;

    // Handles common shapes:
    // 1) direct tick payload
    // 2) { type: "tickUpdate", data: {...} }
    // 3) { event: "...", payload: {...} }
    Map<String, dynamic> data = (map["data"] as Map?)?.cast<String, dynamic>() ??
        (map["payload"] as Map?)?.cast<String, dynamic>() ??
        map;

    if (t == "tickUpdate" || t == "tick" || t == "marketData") {
      final nested = map["data"];
      if (nested is Map) {
        data = nested.cast<String, dynamic>();
      }
    }

    final topSymbol = data["symbol"] ?? map["symbol"];
    if (topSymbol != null && (data["symbol"] == null || data["symbol"] == "")) {
      data = Map<String, dynamic>.from(data);
      data["symbol"] = topSymbol is String ? topSymbol : topSymbol.toString();
    }

    final tick = Kmi30Tick.fromWsJson(data);
    if (tick.symbol.isEmpty) return;
    _latestBySymbol[tick.symbol] = tick;
    _ticksController.add(tick);
  }

  bool _isWsUpgradeHandshakeError(Object? error) {
    if (error == null) return false;
    final text = error.toString().toLowerCase();
    return text.contains("not upgraded to websocket") ||
        text.contains("websocketchannelexception") && text.contains("https://");
  }

  void _handleDisconnect([Object? error]) {
    _sub?.cancel();
    _sub = null;
    _channel = null;
    if (_disposed) return;
    _setStatus(PsxWsStatus.disconnected);
    // When the endpoint rejects websocket upgrade, reconnect loops only
    // repeat the same exception noise; keep REST path active without thrashing.
    if (_isWsUpgradeHandshakeError(error)) {
      return;
    }
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _attempt += 1;
    final exp = min(_attempt, 6);
    final base = pow(2, exp).toInt();
    final jitterMs = Random().nextInt(750);
    final delay = Duration(seconds: base, milliseconds: jitterMs);
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () {
      if (_disposed) return;
      connect();
    });
  }

  void _setStatus(PsxWsStatus s) {
    if (_disposed) return;
    _statusController.add(s);
  }

  Future<void> dispose() async {
    _disposed = true;
    _retryTimer?.cancel();
    _retryTimer = null;
    await _sub?.cancel();
    _sub = null;
    try {
      _channel?.sink.add(jsonEncode({"action": "unsubscribe", "symbols": _symbols}));
    } catch (_) {}
    await _channel?.sink.close();
    _channel = null;
    await _ticksController.close();
    await _statusController.close();
  }
}
