import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:local_auth/local_auth.dart";

import "../core/security/biometric_prefs_store.dart";
import "../services/biometric_service.dart";
import "auth_providers.dart";

final localAuthProvider = Provider<LocalAuthentication>(
  (_) => LocalAuthentication(),
);

final secureStorageProvider = Provider<FlutterSecureStorage>(
  (_) => const FlutterSecureStorage(),
);

final biometricPrefsStoreProvider = Provider<BiometricPrefsStore>(
  (ref) => BiometricPrefsStore(ref.read(secureStorageProvider)),
);

final biometricServiceProvider = Provider<BiometricService>(
  (ref) => BiometricService(
    client: LocalBiometricAuthClient(ref.read(localAuthProvider)),
  ),
);

final biometricCapabilityProvider = FutureProvider<BiometricCapability>((
  ref,
) async {
  return ref.read(biometricServiceProvider).getCapability();
});

class BiometricEnabledNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    return ref.read(biometricPrefsStoreProvider).isEnabled();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(biometricPrefsStoreProvider).isEnabled(),
    );
  }

  Future<void> enableForEmail(String email) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(biometricPrefsStoreProvider)
          .setEnabled(enabled: true, email: email);
      return true;
    });
  }

  Future<void> disable() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(biometricPrefsStoreProvider).clear();
      return false;
    });
  }
}

final biometricEnabledProvider =
    AsyncNotifierProvider<BiometricEnabledNotifier, bool>(
      BiometricEnabledNotifier.new,
    );

final biometricEnabledForCurrentUserProvider = FutureProvider<bool>((
  ref,
) async {
  final enabled = await ref.watch(biometricEnabledProvider.future);
  if (!enabled) return false;

  final currentEmail = ref
      .read(currentUserProvider)
      ?.email
      ?.trim()
      .toLowerCase();
  if (currentEmail == null || currentEmail.isEmpty) return false;

  final storedEmail = await ref
      .read(biometricPrefsStoreProvider)
      .getEnabledEmail();
  return storedEmail == currentEmail;
});

class BiometricController extends StateNotifier<AsyncValue<void>> {
  BiometricController(this._ref) : super(const AsyncData(null));

  final Ref _ref;

  Future<bool> authenticate() async {
    return _ref.read(biometricServiceProvider).authenticateForLogin();
  }

  Future<bool> enableForCurrentUser({String? fallbackEmail}) async {
    state = const AsyncLoading();
    final capability = await _ref
        .read(biometricServiceProvider)
        .getCapability();
    if (!capability.isAvailable) {
      state = AsyncError(
        Exception("Biometric authentication is not available on this device."),
        StackTrace.current,
      );
      return false;
    }

    final ok = await authenticate();
    if (!ok) {
      state = AsyncError(
        Exception("Biometric authentication failed or was cancelled."),
        StackTrace.current,
      );
      return false;
    }

    final activeEmail = _ref.read(currentUserProvider)?.email;
    final emailToStore = (activeEmail ?? fallbackEmail ?? "")
        .trim()
        .toLowerCase();
    if (emailToStore.isEmpty) {
      state = AsyncError(
        Exception("No account email is available for biometric setup."),
        StackTrace.current,
      );
      return false;
    }

    await _ref
        .read(biometricEnabledProvider.notifier)
        .enableForEmail(emailToStore);
    state = const AsyncData(null);
    return true;
  }

  Future<void> disable() async {
    state = const AsyncLoading();
    await _ref.read(biometricEnabledProvider.notifier).disable();
    state = const AsyncData(null);
  }
}

final biometricControllerProvider =
    StateNotifierProvider<BiometricController, AsyncValue<void>>(
      (ref) => BiometricController(ref),
    );
