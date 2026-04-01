import "package:flutter/material.dart";
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:portfolio_app/src/app/app.dart';
import 'package:portfolio_app/src/core/config/app_config.dart';

void main() {
  testWidgets("shows auth gate entry state", (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: WakalatInvestApp(
          config: AppConfig(
            appName: "Wakalat Invest",
            environment: "test",
            enableAnalytics: false,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
