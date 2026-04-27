import "package:flutter_test/flutter_test.dart";
import "package:local_auth/local_auth.dart";
import "package:portfolio_app/src/services/biometric_service.dart";

class _FakeBiometricAuthClient implements BiometricAuthClient {
  _FakeBiometricAuthClient({
    required this.deviceSupported,
    required this.canCheck,
    required this.types,
    this.authenticateResult = false,
    this.authenticateError,
  });

  final bool deviceSupported;
  final bool canCheck;
  final List<BiometricType> types;
  final bool authenticateResult;
  final Exception? authenticateError;

  @override
  Future<bool> authenticate({
    required String localizedReason,
    required bool biometricOnly,
    required bool persistAcrossBackgrounding,
  }) async {
    if (authenticateError != null) {
      throw authenticateError!;
    }
    return authenticateResult;
  }

  @override
  Future<bool> canCheckBiometrics() async => canCheck;

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async => types;

  @override
  Future<bool> isDeviceSupported() async => deviceSupported;
}

void main() {
  test("returns available capability when enrolled", () async {
    final service = BiometricService(
      client: _FakeBiometricAuthClient(
        deviceSupported: true,
        canCheck: true,
        types: const [BiometricType.fingerprint],
        authenticateResult: true,
      ),
    );

    final capability = await service.getCapability();
    expect(capability.isAvailable, isTrue);
  });

  test("returns not enrolled capability when no biometrics", () async {
    final service = BiometricService(
      client: _FakeBiometricAuthClient(
        deviceSupported: true,
        canCheck: false,
        types: const [],
      ),
    );

    final capability = await service.getCapability();
    expect(capability.availability, BiometricAvailability.notEnrolled);
  });

  test("returns false when user cancels biometric prompt", () async {
    final service = BiometricService(
      client: _FakeBiometricAuthClient(
        deviceSupported: true,
        canCheck: true,
        types: const [BiometricType.fingerprint],
        authenticateError: const LocalAuthException(
          code: LocalAuthExceptionCode.userCanceled,
        ),
      ),
    );

    final ok = await service.authenticateForLogin();
    expect(ok, isFalse);
  });
}
