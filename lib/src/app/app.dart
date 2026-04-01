import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

import "../core/config/app_config.dart";
import "../core/theme/app_theme.dart";
import "../features/admin/presentation/admin_dashboard_screen.dart";
import "../features/auth/presentation/auth_screen.dart";
import "../features/crm/presentation/crm_dashboard_screen.dart";
import "../features/home/presentation/home_screen.dart";
import "../features/investment/presentation/investor_dashboard_screen.dart";
import "../features/kyc/presentation/kyc_screen.dart";
import "../features/legal/presentation/legal_consent_screen.dart";
import "../features/admin/presentation/admin_finance_console_screen.dart";
import "../features/ledger/presentation/deposit_request_screen.dart";
import "../features/ledger/presentation/wallet_ledger_screen.dart";
import "../features/ledger/presentation/withdrawal_request_screen.dart";
import "../features/notifications/presentation/notifications_screen.dart";
import "../features/reports/presentation/reports_screen.dart";
import "../screens/auth_gate_screen.dart";
import "../screens/consent_gate_screen.dart";
import "../screens/kyc_approved_gate_screen.dart";
import "../screens/login_screen.dart";
import "../screens/signup_screen.dart";

class WakalatInvestApp extends StatelessWidget {
  const WakalatInvestApp({super.key, required this.config});

  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: "/",
      routes: <RouteBase>[
        GoRoute(path: "/", builder: (_, __) => const AuthGateScreen()),
        GoRoute(path: "/login", builder: (_, __) => const LoginScreen()),
        GoRoute(path: "/signup", builder: (_, __) => const SignupScreen()),
        GoRoute(path: "/home", redirect: (_, __) => "/investor"),
        GoRoute(path: "/landing", builder: (_, __) => const HomeScreen()),
        GoRoute(path: "/auth", builder: (_, __) => const AuthScreen()),
        GoRoute(path: "/kyc", builder: (_, __) => const KycScreen()),
        GoRoute(path: "/legal", builder: (_, __) => const LegalConsentScreen()),
        GoRoute(
          path: "/investor",
          builder: (_, __) => const ConsentGateScreen(
            child: InvestorDashboardScreen(),
          ),
        ),
        GoRoute(
          path: "/wallet-ledger",
          builder: (_, __) => const KycApprovedGateScreen(
            featureName: "wallet and withdrawals",
            child: WalletLedgerScreen(),
          ),
        ),
        GoRoute(
          path: "/wallet-ledger/deposit",
          builder: (_, __) => const KycApprovedGateScreen(
            featureName: "deposits",
            child: DepositRequestScreen(),
          ),
        ),
        GoRoute(
          path: "/wallet-ledger/withdraw",
          builder: (_, __) => const KycApprovedGateScreen(
            featureName: "withdrawals",
            child: WithdrawalRequestScreen(),
          ),
        ),
        GoRoute(
          path: "/reports",
          builder: (_, __) => const KycApprovedGateScreen(
            featureName: "reports",
            child: ReportsScreen(),
          ),
        ),
        GoRoute(
          path: "/notifications",
          builder: (_, __) => const KycApprovedGateScreen(
            featureName: "notifications",
            child: NotificationsScreen(),
          ),
        ),
        GoRoute(
          path: "/admin",
          builder: (_, __) => const AdminDashboardScreen(),
        ),
        GoRoute(
          path: "/admin/finance",
          builder: (_, __) => const AdminFinanceConsoleScreen(),
        ),
        GoRoute(path: "/crm", builder: (_, __) => const CrmDashboardScreen()),
      ],
    );

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: config.appName,
      theme: AppTheme.light(),
      routerConfig: router,
    );
  }
}
