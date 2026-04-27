import "package:flutter_secure_storage/flutter_secure_storage.dart";

class BiometricPrefsStore {
  BiometricPrefsStore(this._storage);

  final FlutterSecureStorage _storage;

  static const String _enabledKey = "biometric_enabled";
  static const String _emailKey = "biometric_user_email";
  static const String _enabledAtKey = "biometric_enabled_at";

  Future<bool> isEnabled() async {
    final value = await _storage.read(key: _enabledKey);
    return value == "true";
  }

  Future<void> setEnabled({
    required bool enabled,
    required String email,
  }) async {
    if (enabled) {
      await _storage.write(key: _enabledKey, value: "true");
      await _storage.write(key: _emailKey, value: email.trim().toLowerCase());
      await _storage.write(
        key: _enabledAtKey,
        value: DateTime.now().toIso8601String(),
      );
      return;
    }
    await clear();
  }

  Future<String?> getEnabledEmail() async {
    final value = await _storage.read(key: _emailKey);
    return value?.trim().toLowerCase();
  }

  Future<void> clear() async {
    await _storage.delete(key: _enabledKey);
    await _storage.delete(key: _emailKey);
    await _storage.delete(key: _enabledAtKey);
  }
}
