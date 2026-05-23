// Native platforms only (Android, iOS, desktop) — dart:io is available.

import "dart:async";
import "dart:io";

/// DNS lookup to verify real internet on non-web platforms.
Future<bool> checkNativeConnectivity() async {
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
