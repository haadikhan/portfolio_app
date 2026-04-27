import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../core/i18n/app_translations.dart";
import "../core/theme/app_colors.dart";
import "../core/widgets/app_error_dialog.dart";
import "../providers/auth_providers.dart";
import "../providers/biometric_providers.dart";

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(authControllerProvider.notifier)
        .login(
          email: _emailController.text,
          password: _passwordController.text,
        );
    if (!mounted) return;
    final state = ref.read(authControllerProvider);
    if (state.hasError && state.error != null) {
      await showAppErrorDialog(context, state.error!);
      return;
    }
    if (state.hasValue) {
      // Route through AuthGate to avoid post-login stream churn/flicker.
      context.go("/");
    }
  }

  Future<void> _loginWithFingerprint() async {
    final currentUser = ref.read(currentUserProvider);
    if (kDebugMode) {
      debugPrint(
        "[BIOMETRIC][LoginScreen] Fingerprint tap. currentUser=${currentUser?.uid ?? "null"}",
      );
    }
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "No active session found. Please login with email/password first.",
          ),
        ),
      );
      return;
    }

    final capability = await ref.read(biometricCapabilityProvider.future);
    if (!mounted) return;
    if (kDebugMode) {
      debugPrint(
        "[BIOMETRIC][LoginScreen] Capability available=${capability.isAvailable}, types=${capability.types}",
      );
    }
    if (!capability.isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr("fingerprint_not_setup"))),
      );
      return;
    }

    final ok = await ref
        .read(biometricControllerProvider.notifier)
        .authenticate();
    if (!mounted) return;
    if (kDebugMode) {
      debugPrint("[BIOMETRIC][LoginScreen] authenticate() result=$ok");
    }
    if (ok) {
      context.go("/");
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr("biometric_auth_failed"))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final canUseBiometricAsync = ref.watch(biometricEnabledProvider);
    final capabilityAsync = ref.watch(biometricCapabilityProvider);
    final canShowBiometricButton =
        canUseBiometricAsync.valueOrNull == true &&
        capabilityAsync.valueOrNull?.isAvailable == true;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xFF121212), Color(0xFF171A1A), Color(0xFF121212)]
              : const [AppColors.backgroundTop, AppColors.backgroundBottom],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: Text(context.tr("sign_in"))),
        body: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 32,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1F2223)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF343A3A)
                            : AppColors.border,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.28 : 0.05,
                          ),
                          blurRadius: 22,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr("welcome_back"),
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.tr("sign_in_subtitle"),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 18),
                          TextFormField(
                            controller: _emailController,
                            decoration: InputDecoration(
                              labelText: context.tr("email"),
                            ),
                            validator: (v) => (v == null || !v.contains("@"))
                                ? context.tr("enter_valid_email")
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: context.tr("password"),
                              suffixIcon: IconButton(
                                tooltip: _obscurePassword
                                    ? context.tr("password_visibility_show")
                                    : context.tr("password_visibility_hide"),
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                              ),
                            ),
                            validator: (v) => (v == null || v.length < 6)
                                ? context.tr("password_min_chars")
                                : null,
                          ),
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: TextButton(
                              onPressed: isLoading
                                  ? null
                                  : () => context.push("/forgot-password"),
                              child: Text(context.tr("forgot_password_link")),
                            ),
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: isLoading ? null : _submit,
                              child: isLoading
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(context.tr("login_btn")),
                            ),
                          ),
                          if (canShowBiometricButton) ...[
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: isLoading
                                    ? null
                                    : _loginWithFingerprint,
                                icon: const Icon(Icons.fingerprint_rounded),
                                label: Text(
                                  context.tr("login_with_fingerprint"),
                                ),
                              ),
                            ),
                          ],
                          if (authState.hasError) ...[
                            const SizedBox(height: 12),
                            Text(
                              formatAppErrorMessage(context, authState.error!),
                              style: const TextStyle(color: AppColors.error),
                            ),
                          ],
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () => context.go("/signup"),
                            child: Text(context.tr("create_new_account")),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
