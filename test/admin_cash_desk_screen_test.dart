import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_localizations/flutter_localizations.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:portfolio_app/src/admin/models/admin_investor_models.dart";
import "package:portfolio_app/src/admin/providers/admin_cash_desk_providers.dart";
import "package:portfolio_app/src/admin/providers/admin_providers.dart";
import "package:portfolio_app/src/admin/screens/admin_cash_desk_screen.dart";
import "package:portfolio_app/src/admin/services/admin_cash_desk_service.dart";
import "package:portfolio_app/src/admin/widgets/admin_shell.dart";
import "package:portfolio_app/src/admin/cash_desk/cash_desk_logic.dart";
import "package:portfolio_app/src/features/notifications/providers/notification_providers.dart";

const _investor = AdminInvestorSummary(
  userId: "u1",
  name: "Amina",
  email: "amina@example.com",
  phone: "0300",
  kycStatus: "approved",
  createdAt: null,
  role: "investor",
);

const _wallet = <String, dynamic>{
  "totalDeposited": 1000.0,
  "totalProfit": 0.0,
  "totalAdjustments": 0.0,
  "totalFees": 0.0,
  "totalWithdrawn": 0.0,
  "reservedAmount": 0.0,
  "availableBalance": 1000.0,
};

class _FakeCaller implements CashDeskCaller {
  _FakeCaller({this.error, this.gate});

  final Object? error;
  final Completer<void>? gate;

  @override
  Future<CashDeskResult> credit({
    required String userId,
    required double amount,
    String? reference,
    String? note,
    required String idempotencyKey,
  }) {
    return _finish(amount);
  }

  @override
  Future<CashDeskResult> withdraw({
    required String userId,
    required double amount,
    String? reference,
    String? note,
    required String idempotencyKey,
  }) {
    return _finish(amount);
  }

  Future<CashDeskResult> _finish(double amount) async {
    if (gate != null) await gate!.future;
    if (error != null) throw error!;
    return CashDeskResult(
      replayed: false,
      transactionId: "ISC-TEST",
      requestId: null,
      balanceBefore: 1000,
      balanceAfter: 1000 + amount,
      amount: amount,
    );
  }
}

Future<void> _pumpDesk(
  WidgetTester tester, {
  String? initialUserId,
  List<CashDeskBlocker> blockers = const [],
  CashDeskCaller? caller,
}) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        filteredInvestorsProvider.overrideWith(
          (ref) => const AsyncData([_investor]),
        ),
        cashDeskRecentProvider.overrideWith(
          (ref) => Stream.value(const <CashDeskEntry>[]),
        ),
        cashDeskWalletProvider.overrideWith(
          (ref, uid) => Stream.value(_wallet),
        ),
        cashDeskBlockersProvider.overrideWith(
          (ref, uid) => Stream.value(blockers),
        ),
        cashDeskPortfolioNumberProvider.overrideWith(
          (ref, uid) async => "AMAPISCPK-100",
        ),
        if (caller != null)
          adminCashDeskServiceProvider.overrideWith((ref) => caller),
      ],
      child: MaterialApp(
        locale: const Locale("en"),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: AdminCashDeskScreen(initialUserId: initialUserId),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets("shows a prompt when no investor is selected", (tester) async {
    await _pumpDesk(tester);
    expect(find.text("Select an investor."), findsOneWidget);
    expect(find.text("Cash Withdrawal (Debit)"), findsNothing);
  });

  testWidgets("shows the ledger balance once an investor is selected", (
    tester,
  ) async {
    await _pumpDesk(tester, initialUserId: "u1");
    expect(find.textContaining("Available balance: PKR 1000.00"), findsOneWidget);
    expect(
      find.textContaining("Today's profit not yet credited is excluded"),
      findsOneWidget,
    );
    expect(find.text("Amina"), findsWidgets);
  });

  testWidgets("withdraw full balance fills the amount field", (tester) async {
    await _pumpDesk(tester, initialUserId: "u1");
    await tester.tap(find.text("Withdraw full balance"));
    await tester.pump();
    final field = tester.widget<TextField>(find.byKey(const Key("cash_desk_amount")));
    expect(field.controller!.text, "1000.00");
  });

  testWidgets("blocked state lists the open request and disables posting", (
    tester,
  ) async {
    await _pumpDesk(
      tester,
      initialUserId: "u1",
      blockers: const [
        CashDeskBlocker(kind: "withdrawal", id: "w9", status: "pending"),
      ],
    );
    expect(find.byKey(const Key("cash_desk_blocked")), findsOneWidget);
    expect(find.textContaining("withdrawal w9 (pending)"), findsOneWidget);
    final debit = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, "Cash Withdrawal (Debit)"),
    );
    final credit = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, "Cash Credit"),
    );
    expect(debit.onPressed, isNull);
    expect(credit.onPressed, isNull);
  });

  testWidgets("disables buttons while a post is in flight, then shows success", (
    tester,
  ) async {
    final gate = Completer<void>();
    await _pumpDesk(
      tester,
      initialUserId: "u1",
      caller: _FakeCaller(gate: gate),
    );
    await tester.enterText(find.byKey(const Key("cash_desk_amount")), "25");
    await tester.tap(find.widgetWithText(FilledButton, "Cash Credit"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Confirm"));
    await tester.pump();
    await tester.pump();
    final credit = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, "Cash Credit"),
    );
    expect(credit.onPressed, isNull);
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key("cash_desk_success")), findsOneWidget);
    expect(find.textContaining("Cash Credit posted"), findsOneWidget);
  });

  testWidgets("shows an error when the callable fails", (tester) async {
    await _pumpDesk(
      tester,
      initialUserId: "u1",
      caller: _FakeCaller(error: Exception("cash desk failed")),
    );
    await tester.enterText(find.byKey(const Key("cash_desk_amount")), "25");
    await tester.tap(find.widgetWithText(FilledButton, "Cash Credit"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Confirm"));
    await tester.pumpAndSettle();
    expect(find.textContaining("cash desk failed"), findsOneWidget);
  });

  testWidgets("admin nav shows Cash Desk and CRM nav does not", (tester) async {
    tester.view.physicalSize = const Size(1400, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> pumpShell(String role, String location) async {
      final router = GoRouter(
        initialLocation: location,
        routes: [
          ShellRoute(
            builder: (_, __, child) => AdminShell(child: child),
            routes: [
              GoRoute(
                path: "/dashboard",
                builder: (_, __) => const SizedBox(),
              ),
              GoRoute(path: "/crm", builder: (_, __) => const SizedBox()),
              GoRoute(
                path: "/notifications",
                builder: (_, __) => const SizedBox(),
              ),
              GoRoute(path: "/login", builder: (_, __) => const Text("login")),
              GoRoute(
                path: "/cash-desk",
                builder: (_, __) => const SizedBox(),
              ),
            ],
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          key: ValueKey(role),
          overrides: [
            adminRoleProvider.overrideWith((ref) => Stream.value(role)),
            unreadNotificationCountProvider.overrideWith(
              (ref) => Stream.value(0),
            ),
          ],
          child: MaterialApp.router(
            locale: const Locale("en"),
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpShell("admin", "/dashboard");
    expect(find.text("Cash Desk"), findsWidgets);

    await pumpShell("crm", "/crm");
    expect(find.text("Cash Desk"), findsNothing);
  });
}
