import "dart:convert";
import "dart:math";

import "package:crypto/crypto.dart";
import "package:device_info_plus/device_info_plus.dart";
import "package:flutter/foundation.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:package_info_plus/package_info_plus.dart";

/// Per-device identity used for the trusted-devices feature.
///
/// `deviceHash` is a stable per-device + per-user SHA-256 hash that the
/// backend stores under `users/{uid}/trustedDevices/{deviceHash}`. It is
/// deliberately *not* the raw vendor id so that compromised hashes leak no
/// PII and cannot be reused across users.
@immutable
class DeviceFingerprint {
  const DeviceFingerprint({
    required this.deviceHash,
    required this.deviceName,
    required this.platform,
    required this.appVersion,
  });

  final String deviceHash;
  final String deviceName;
  final String platform;
  final String appVersion;

  Map<String, Object?> toCallablePayload() => <String, Object?>{
    "deviceHash": deviceHash,
    "deviceName": deviceName,
    "platform": platform,
    "appVersion": appVersion,
  };
}

const _kSecureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);
const _kWebDeviceIdKey = "wakalat_invest_web_device_id_v1";

String _truncate(String input, int max) {
  if (input.length <= max) return input;
  return input.substring(0, max);
}

String _sha256Hex(String input) {
  final digest = sha256.convert(utf8.encode(input));
  return digest.toString();
}

String _platformLabel() {
  if (kIsWeb) return "web";
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return "android";
    case TargetPlatform.iOS:
      return "ios";
    case TargetPlatform.macOS:
      return "macos";
    case TargetPlatform.windows:
      return "windows";
    case TargetPlatform.linux:
      return "linux";
    case TargetPlatform.fuchsia:
      return "fuchsia";
  }
}

Future<String> _stableRawIdForCurrentDevice() async {
  if (kIsWeb) {
    final existing = await _kSecureStorage.read(key: _kWebDeviceIdKey);
    if (existing != null && existing.length >= 16) return existing;
    final rng = Random.secure();
    final bytes = List<int>.generate(24, (_) => rng.nextInt(256));
    final id = base64Url.encode(bytes).replaceAll("=", "");
    await _kSecureStorage.write(key: _kWebDeviceIdKey, value: id);
    return id;
  }

  final info = DeviceInfoPlugin();
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      final a = await info.androidInfo;
      final raw = a.id;
      return raw.isNotEmpty ? raw : a.fingerprint;
    case TargetPlatform.iOS:
      final i = await info.iosInfo;
      return i.identifierForVendor ?? "ios-${i.utsname.machine}-${i.name}";
    case TargetPlatform.macOS:
      final m = await info.macOsInfo;
      return m.systemGUID ?? "mac-${m.computerName}";
    case TargetPlatform.windows:
      final w = await info.windowsInfo;
      return w.deviceId.isNotEmpty
          ? w.deviceId
          : "win-${w.computerName}-${w.numberOfCores}";
    case TargetPlatform.linux:
      final l = await info.linuxInfo;
      return l.machineId ?? "linux-${l.id}-${l.name}";
    case TargetPlatform.fuchsia:
      return "fuchsia-${defaultTargetPlatform.name}";
  }
}

Future<String> _humanDeviceName() async {
  if (kIsWeb) {
    final w = await DeviceInfoPlugin().webBrowserInfo;
    final browser = w.browserName.name;
    final platform = w.platform ?? "web";
    return _truncate("$browser on $platform", 80);
  }
  final info = DeviceInfoPlugin();
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      final a = await info.androidInfo;
      final brand = a.brand.isEmpty ? a.manufacturer : a.brand;
      return _truncate(
        "${_capitalize(brand)} ${a.model} (Android ${a.version.release})",
        80,
      );
    case TargetPlatform.iOS:
      final i = await info.iosInfo;
      return _truncate(
        "${i.name} (${i.systemName} ${i.systemVersion})",
        80,
      );
    case TargetPlatform.macOS:
      final m = await info.macOsInfo;
      return _truncate("${m.computerName} (macOS ${m.osRelease})", 80);
    case TargetPlatform.windows:
      final w = await info.windowsInfo;
      return _truncate(
        "${w.computerName} (Windows ${w.displayVersion})",
        80,
      );
    case TargetPlatform.linux:
      final l = await info.linuxInfo;
      return _truncate("${l.prettyName}", 80);
    case TargetPlatform.fuchsia:
      return "Fuchsia device";
  }
}

String _capitalize(String input) {
  if (input.isEmpty) return input;
  return input[0].toUpperCase() + input.substring(1);
}

/// Computes a stable device hash for the given user + this physical device.
///
/// Same `(uid, device)` pair always produces the same hash. Reinstalling the
/// app on iOS/web rotates the underlying id and therefore the hash, which is
/// the desired behaviour (a reinstall should look like a fresh device and
/// require an OTP).
Future<DeviceFingerprint> currentDeviceFingerprint(String uid) async {
  final rawId = await _stableRawIdForCurrentDevice();
  final platform = _platformLabel();
  final hash = _sha256Hex("v1|$uid|$platform|$rawId");
  String name;
  try {
    name = await _humanDeviceName();
  } catch (_) {
    name = "$platform device";
  }
  String appVersion = "";
  try {
    final pkg = await PackageInfo.fromPlatform();
    appVersion = "${pkg.version}+${pkg.buildNumber}";
  } catch (_) {
    appVersion = "";
  }
  return DeviceFingerprint(
    deviceHash: hash,
    deviceName: name,
    platform: platform,
    appVersion: appVersion,
  );
}
