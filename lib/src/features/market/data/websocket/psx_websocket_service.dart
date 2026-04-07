import "dart:async";
import "dart:convert";
import "dart:math";

import "package:web_socket_channel/web_socket_channel.dart";

import "../models/kmi30_tick.dart";

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
    _setStatus(_attempt == 0 ? PsxWsStatus.connecting : PsxWsStatus.reconnecting);
    try {
      final channel = WebSocketChannel.connect(Uri.parse("wss://psxterminal.com/"));
      _channel = channel;
      _sub = channel.stream.listen(
        _handleMessage,
        onError: (_) => _handleDisconnect(),
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
    final payload = {
      "action": "subscribe",
      "symbols": _symbols,
    };
    ch.sink.add(jsonEncode(payload));
  }

  void _handleMessage(dynamic raw) {
    Map<String, dynamic>? map;
    if (raw is String) {
      try {
        final parsed = jsonDecode(raw);
        if (parsed is Map<String, dynamic>) {
          map = parsed;
        } else if (parsed is Map) {
          map = parsed.cast<String, dynamic>();
        }
      } catch (_) {
        return;
      }
    } else if (raw is Map<String, dynamic>) {
      map = raw;
    }
    if (map == null) return;
    if (map["type"] == "pong" || map["type"] == "ping") return;

    // Handles common shapes:
    // 1) direct tick payload
    // 2) { type: "tickUpdate", data: {...} }
    // 3) { event: "...", payload: {...} }
    final data = (map["data"] as Map?)?.cast<String, dynamic>() ??
        (map["payload"] as Map?)?.cast<String, dynamic>() ??
        map;

    final tick = Kmi30Tick.fromWsJson(data);
    if (tick.symbol.isEmpty) return;
    _latestBySymbol[tick.symbol] = tick;
    _ticksController.add(tick);
  }

  void _handleDisconnect() {
    _sub?.cancel();
    _sub = null;
    _channel = null;
    if (_disposed) return;
    _setStatus(PsxWsStatus.disconnected);
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
