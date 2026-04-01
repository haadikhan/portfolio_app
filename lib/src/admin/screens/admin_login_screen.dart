import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../core/theme/app_colors.dart";
import "../../core/widgets/design_system_widgets.dart";
import "../../providers/auth_providers.dart";
import "../providers/admin_providers.dart";

class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  ConsumerState<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _tryResumeSession() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !mounted) return;
    final doc = await ref.read(firebaseFirestoreProvider).collection("users").doc(user.uid).get();
    final role = (doc.data()?["role"] as String? ?? "").toLowerCase();
    if (!mounted) return;
    if (role == "admin") {
      context.go("/dashboard");
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryResumeSession());
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(adminAuthControllerProvider.notifier).signInWithEmail(
          email: _email.text,
          password: _password.text,
        );
    if (!mounted) return;
    final s = ref.read(adminAuthControllerProvider);
    s.whenOrNull(
      error: (e, _) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      },
      data: (_) => context.go("/dashboard"),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authBusy = ref.watch(adminAuthControllerProvider).isLoading;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.backgroundTop, AppColors.backgroundBottom],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SoftCard(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        "Admin sign in",
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Wakalat Invest — KYC operations",
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: "Work email",
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (v) =>
                            (v == null || !v.contains("@")) ? "Valid email required" : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _password,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: "Password",
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        validator: (v) =>
                            (v == null || v.length < 6) ? "Min 6 characters" : null,
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: authBusy ? null : _submit,
                        child: authBusy
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text("Sign in"),
                      ),
                    ],
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
