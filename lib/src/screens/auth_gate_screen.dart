import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../features/security/data/security_providers.dart";
import "../providers/auth_providers.dart";
import "../providers/biometric_providers.dart";

class AuthGateScreen extends ConsumerStatefulWidget {
  const AuthGateScreen({super.key});

  @override
  ConsumerState<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends ConsumerState<AuthGateScreen> {
  bool _isRouting = false;

  Future<void> _routeAuthenticatedUser() async {
    if (_isRouting || !mounted) return;
    _isRouting = true;
    try {
      final user = ref.read(currentUserProvider);
      if (user == null) return;

      final security = await ref.read(userSecurityProvider.future);
      final verifiedPhone = security?.verifiedPhone?.trim() ?? "";
      if (verifiedPhone.isNotEmpty) {
        // FutureProvider caches trusted=false; after markDeviceTrusted the cache
        // would stay stale until uid/fingerprint change. Force a fresh Firestore read.
        ref.invalidate(currentDeviceTrustedProvider);
        ref.invalidate(otpRequiredProvider);
        final otpRequired = await ref.read(otpRequiredProvider.future);
        if (!mounted) return;
        if (otpRequired) {
          context.go(
            "/login-otp?phone=${Uri.encodeComponent(verifiedPhone)}",
          );
          return;
        }
      }

      final biometricEnabledForUser = await ref.read(
        biometricEnabledForCurrentUserProvider.future,
      );
      if (kDebugMode) {
        debugPrint(
          "[BIOMETRIC][AuthGate] user present. biometricEnabledForUser=$biometricEnabledForUser",
        );
      }
      if (!mounted) return;
      if (!biometricEnabledForUser) {
        if (kDebugMode) {
          debugPrint(
            "[BIOMETRIC][AuthGate] Biometric disabled. Navigating /investor",
          );
        }
        context.go("/investor");
        return;
      }

      final capability = await ref.read(biometricCapabilityProvider.future);
      if (kDebugMode) {
        debugPrint(
          "[BIOMETRIC][AuthGate] capability available=${capability.isAvailable}, availability=${capability.availability}",
        );
      }
      if (!mounted) return;
      if (!capability.isAvailable) {
        await ref.read(biometricControllerProvider.notifier).disable();
        if (!mounted) return;
        if (kDebugMode) {
          debugPrint(
            "[BIOMETRIC][AuthGate] Capability unavailable. Disabled biometric and going /login",
          );
        }
        context.go("/login");
        return;
      }

      final ok = await ref
          .read(biometricControllerProvider.notifier)
          .authenticate();
      if (kDebugMode) {
        debugPrint("[BIOMETRIC][AuthGate] authenticate() result=$ok");
      }
      if (!mounted) return;
      if (ok) {
        if (kDebugMode) {
          debugPrint("[BIOMETRIC][AuthGate] Success. Navigating /investor");
        }
        context.go("/investor");
        return;
      }

      await ref.read(authControllerProvider.notifier).logout();
      if (!mounted) return;
      if (kDebugMode) {
        debugPrint(
          "[BIOMETRIC][AuthGate] Failed/cancelled. Session logged out and navigating /login",
        );
      }
      context.go("/login");
    } finally {
      if (mounted) {
        _isRouting = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    return authState.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) =>
          Scaffold(body: Center(child: Text("Auth error: $error"))),
      data: (user) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          if (user == null) {
            if (kDebugMode) {
              debugPrint("[BIOMETRIC][AuthGate] user=null -> /login");
            }
            context.go("/login");
          } else {
            if (kDebugMode) {
              debugPrint("[BIOMETRIC][AuthGate] user=${user.uid} -> routing");
            }
            _routeAuthenticatedUser();
          }
        });
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}
