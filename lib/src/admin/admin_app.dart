import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/material.dart";
import "package:flutter_localizations/flutter_localizations.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../core/i18n/language_provider.dart";
import "../core/theme/app_theme.dart";
import "../core/theme/theme_provider.dart";
import "admin_role_refresh.dart";
import "crm/crm_dashboard_screen.dart";
import "crm/crm_investor_detail_screen.dart";
import "crm/crm_investor_list_screen.dart";
import "crm/crm_team_screen.dart";
import "screens/admin_dashboard_screen.dart";
import "screens/admin_deposits_queue_screen.dart";
import "screens/admin_investor_detail_screen.dart";
import "screens/admin_investor_list_screen.dart";
import "screens/admin_kyc_detail_screen.dart";
import "screens/admin_kyc_list_screen.dart";
import "screens/admin_login_screen.dart";
import "screens/admin_broadcast_screen.dart";
import "../features/notifications/presentation/notifications_screen.dart";
import "screens/admin_returns_screen.dart";
import "screens/admin_upload_reports_screen.dart";
import "screens/admin_withdrawals_queue_screen.dart";
import "widgets/admin_shell.dart";

bool _crmMustRedirect(String loc) {
  if (loc.startsWith("/crm/team")) return true;
  if (loc.startsWith("/crm")) return false;
  if (loc.startsWith("/notifications")) return false;
  if (loc == "/login") return false;
  return true;
}

class _RoleReadyGate extends StatelessWidget {
  const _RoleReadyGate({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: adminRoleRefresh,
      builder: (context, _) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null && !adminRoleRefresh.ready) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return child;
      },
    );
  }
}

/// Admin web app router (KYC review + CRM).
final adminRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: "/login",
    refreshListenable: adminRoleRefresh,
    redirect: (context, state) {
      final user = FirebaseAuth.instance.currentUser;
      final loc = state.matchedLocation;
      final loggingIn = loc == "/login";

      if (user == null) {
        if (!loggingIn) return "/login";
        return null;
      }

      if (!adminRoleRefresh.ready) {
        return null;
      }

      final role = (adminRoleRefresh.role ?? "").toLowerCase();
      if (role != "admin" && role != "crm") {
        return "/login";
      }

      if (loggingIn) {
        return role == "crm" ? "/crm" : "/dashboard";
      }

      if (role == "crm" && _crmMustRedirect(loc)) {
        return "/crm";
      }

      return null;
    },
    routes: [
      GoRoute(path: "/login", builder: (_, __) => const AdminLoginScreen()),
      ShellRoute(
        builder: (context, state, child) => _RoleReadyGate(
          child: AdminShell(child: child),
        ),
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
            path: "/upload-reports",
            builder: (_, __) => const AdminUploadReportsScreen(),
          ),
          GoRoute(
            path: "/notifications",
            builder: (_, __) => const NotificationsScreen(
              shell: NotificationShellKind.admin,
            ),
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
          GoRoute(
            path: "/crm",
            builder: (_, __) => const CrmDashboardScreen(),
          ),
          GoRoute(
            path: "/crm/investors",
            builder: (_, __) => const CrmInvestorListScreen(),
          ),
          GoRoute(
            path: "/crm/investors/:userId",
            builder: (_, state) => CrmInvestorDetailScreen(
              userId: state.pathParameters["userId"] ?? "",
            ),
          ),
          GoRoute(
            path: "/crm/team",
            builder: (_, __) => const CrmTeamScreen(),
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
      builder: (context, child) {
        final code = Localizations.localeOf(context).languageCode;
        return Directionality(
          textDirection: code == "ur" ? TextDirection.rtl : TextDirection.ltr,
          child: child ?? const SizedBox.shrink(),
        );
      },
      routerConfig: router,
    );
  }
}
