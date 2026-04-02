import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/material.dart";
import "package:flutter_localizations/flutter_localizations.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../core/i18n/language_provider.dart";
import "../core/theme/app_theme.dart";
import "../core/theme/theme_provider.dart";
import "screens/admin_dashboard_screen.dart";
import "screens/admin_deposits_queue_screen.dart";
import "screens/admin_investor_detail_screen.dart";
import "screens/admin_investor_list_screen.dart";
import "screens/admin_kyc_detail_screen.dart";
import "screens/admin_kyc_list_screen.dart";
import "screens/admin_login_screen.dart";
import "screens/admin_broadcast_screen.dart";
import "screens/admin_returns_screen.dart";
import "screens/admin_withdrawals_queue_screen.dart";
import "widgets/admin_shell.dart";

/// Drives [GoRouter] refresh when Firebase auth session changes.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh() {
    FirebaseAuth.instance.authStateChanges().listen((_) => notifyListeners());
  }
}

final _authRefresh = _AuthRefresh();

/// Admin web app router (KYC review).
final adminRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: "/login",
    refreshListenable: _authRefresh,
    redirect: (context, state) {
      final user = FirebaseAuth.instance.currentUser;
      final loc = state.matchedLocation;
      final loggingIn = loc == "/login";
      if (user == null && !loggingIn) {
        return "/login";
      }
      return null;
    },
    routes: [
      GoRoute(path: "/login", builder: (_, __) => const AdminLoginScreen()),
      ShellRoute(
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(
            path: "/dashboard",
            builder: (_, __) => const AdminDashboardScreen(),
          ),
          GoRoute(path: "/kyc", builder: (_, __) => const AdminKycListScreen()),
          GoRoute(
            path: "/deposits",
            builder: (_, __) => const AdminDepositsQueueScreen(),
          ),
          GoRoute(
            path: "/withdrawals",
            builder: (_, __) => const AdminWithdrawalsQueueScreen(),
          ),
          GoRoute(
            path: "/investors",
            builder: (_, __) => const AdminInvestorListScreen(),
          ),
          GoRoute(
            path: "/returns",
            builder: (_, __) => const AdminReturnsScreen(),
          ),
          GoRoute(
            path: "/broadcast",
            builder: (_, __) => const AdminBroadcastScreen(),
          ),
          GoRoute(
            path: "/investors/:userId",
            builder: (_, state) => AdminInvestorDetailScreen(
              userId: state.pathParameters["userId"] ?? "",
            ),
          ),
          GoRoute(
            path: "/kyc/:userId",
            builder: (_, state) => AdminKycDetailScreen(
              userId: state.pathParameters["userId"] ?? "",
            ),
          ),
        ],
      ),
    ],
  );
});

class WakalatAdminApp extends ConsumerWidget {
  const WakalatAdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(adminRouterProvider);
    final themeMode = ref.watch(themeProvider).valueOrNull ?? ThemeMode.light;
    final locale =
        ref.watch(languageProvider).valueOrNull ?? const Locale("en");
    final useUrduFont = locale.languageCode == "ur";
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: "Wakalat Invest — Admin",
      theme: AppTheme.light(useUrduFont: useUrduFont),
      darkTheme: AppTheme.dark(useUrduFont: useUrduFont),
      themeMode: themeMode,
      locale: locale,
      supportedLocales: const [Locale("en"), Locale("ur")],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}
