// Lightweight connectivity checker using dart:io InternetAddress.
// Does NOT require connectivity_plus; uses DNS lookup for real internet access.

import "dart:async";
import "dart:io";

import "package:flutter_riverpod/flutter_riverpod.dart";

class ConnectivityService {
  /// Returns true if device has real internet access.
  /// Uses DNS lookup to google.com — more reliable than
  /// just checking network interface state.
  static Future<bool> hasInternet() async {
    try {
      final result = await InternetAddress.lookup("google.com")
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } on SocketException {
      return false;
    } on TimeoutException {
      return false;
    } catch (_) {
      return false;
    }
  }
}

/// Stream that emits true/false every 3 seconds.
/// true = has internet, false = no internet.
/// Used to auto-recover when connection is restored.
final connectivityStreamProvider = StreamProvider<bool>((ref) async* {
  while (true) {
    yield await ConnectivityService.hasInternet();
    await Future.delayed(const Duration(seconds: 3));
  }
});

/// Simple provider for current connectivity state.
/// Returns true = online, false = offline, null = checking.
final isOnlineProvider = Provider<bool?>((ref) {
  return ref.watch(connectivityStreamProvider).when(
    data: (v) => v,
    loading: () => null,
    error: (_, __) => false,
  );
});
