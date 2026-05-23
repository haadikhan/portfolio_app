// Connectivity checker: DNS lookup on native; web bypasses dart:io.

import "dart:async";

import "package:flutter/foundation.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "connectivity_stub.dart"
    if (dart.library.io) "connectivity_native.dart";

class ConnectivityService {
  /// On web: always online (browser handles connectivity natively).
  /// On native: DNS lookup to verify real internet access.
  static Future<bool> hasInternet() async {
    if (kIsWeb) return true;
    return checkNativeConnectivity();
  }
}

/// Stream that emits true/false every 3 seconds.
/// Used to auto-recover when connection is restored.
final connectivityStreamProvider = StreamProvider<bool>((ref) async* {
  while (true) {
    yield await ConnectivityService.hasInternet();
    await Future.delayed(const Duration(seconds: 3));
  }
});

/// Returns true = online, false = offline, null = checking.
final isOnlineProvider = Provider<bool?>((ref) {
  return ref.watch(connectivityStreamProvider).when(
    data: (v) => v,
    loading: () => null,
    error: (_, __) => false,
  );
});
