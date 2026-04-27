import "package:flutter/foundation.dart";
import "package:flutter/services.dart";
import "package:local_auth/local_auth.dart";

enum BiometricAvailability {
  available,
  notSupported,
  notEnrolled,
  temporarilyLocked,
  permanentlyLocked,
  unavailable,
}

class BiometricCapability {
  const BiometricCapability({required this.availability, required this.types});

  final BiometricAvailability availability;
  final List<BiometricType> types;

  bool get isAvailable => availability == BiometricAvailability.available;
}

abstract class BiometricAuthClient {
  Future<bool> isDeviceSupported();
  Future<bool> canCheckBiometrics();
  Future<List<BiometricType>> getAvailableBiometrics();
  Future<bool> authenticate({
    required String localizedReason,
    required bool biometricOnly,
    required bool persistAcrossBackgrounding,
  });
}

class LocalBiometricAuthClient implements BiometricAuthClient {
  LocalBiometricAuthClient(this._auth);

  final LocalAuthentication _auth;

  @override
  Future<bool> isDeviceSupported() => _auth.isDeviceSupported();

  @override
  Future<bool> canCheckBiometrics() => _auth.canCheckBiometrics;

  @override
  Future<List<BiometricType>> getAvailableBiometrics() =>
      _auth.getAvailableBiometrics();

  @override
  Future<bool> authenticate({
    required String localizedReason,
    required bool biometricOnly,
    required bool persistAcrossBackgrounding,
  }) {
    return _auth.authenticate(
      localizedReason: localizedReason,
      biometricOnly: biometricOnly,
      persistAcrossBackgrounding: persistAcrossBackgrounding,
    );
  }
}

class BiometricService {
  BiometricService({BiometricAuthClient? client})
    : _client = client ?? LocalBiometricAuthClient(LocalAuthentication());

  final BiometricAuthClient _client;

  Future<BiometricCapability> getCapability() async {
    try {
      final supported = await _client.isDeviceSupported();
      if (!supported) {
        return const BiometricCapability(
          availability: BiometricAvailability.notSupported,
          types: <BiometricType>[],
        );
      }
      final canCheck = await _client.canCheckBiometrics();
      final types = await _client.getAvailableBiometrics();
      if (!canCheck || types.isEmpty) {
        return BiometricCapability(
          availability: BiometricAvailability.notEnrolled,
          types: types,
        );
      }
      return BiometricCapability(
        availability: BiometricAvailability.available,
        types: types,
      );
    } on LocalAuthException catch (e) {
      final mapped = _mapLocalAuthCodeToAvailability(e.code);
      return BiometricCapability(availability: mapped, types: const []);
    } on PlatformException catch (e) {
      final mapped = _mapLegacyCodeToAvailability(e.code);
      return BiometricCapability(availability: mapped, types: const []);
    }
  }

  Future<bool> authenticateForLogin() async {
    try {
      return await _client.authenticate(
        localizedReason:
            "Authenticate with biometrics to continue to your account.",
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } on LocalAuthException catch (e) {
      if (kDebugMode) {
        debugPrint(
          "[BIOMETRIC][Service] LocalAuthException during authenticate: ${e.code.name}, ${e.description}",
        );
      }
      // User cancel/fallback/timeout should never crash auth flows.
      return false;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint(
          "[BIOMETRIC][Service] PlatformException during authenticate: ${e.code}, ${e.message}",
        );
      }
      // Backward compatibility with platform-channel exceptions.
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint("[BIOMETRIC][Service] Unknown exception: $e");
      }
      return false;
    }
  }

  BiometricAvailability _mapLocalAuthCodeToAvailability(
    LocalAuthExceptionCode code,
  ) {
    switch (code) {
      case LocalAuthExceptionCode.noBiometricHardware:
        return BiometricAvailability.notSupported;
      case LocalAuthExceptionCode.noBiometricsEnrolled:
      case LocalAuthExceptionCode.noCredentialsSet:
        return BiometricAvailability.notEnrolled;
      case LocalAuthExceptionCode.temporaryLockout:
        return BiometricAvailability.temporarilyLocked;
      case LocalAuthExceptionCode.biometricLockout:
        return BiometricAvailability.permanentlyLocked;
      default:
        return BiometricAvailability.unavailable;
    }
  }

  BiometricAvailability _mapLegacyCodeToAvailability(String code) {
    switch (code) {
      case "NotAvailable":
        return BiometricAvailability.notSupported;
      case "NotEnrolled":
        return BiometricAvailability.notEnrolled;
      case "LockedOut":
        return BiometricAvailability.temporarilyLocked;
      case "PermanentlyLockedOut":
        return BiometricAvailability.permanentlyLocked;
      default:
        return BiometricAvailability.unavailable;
    }
  }
}
