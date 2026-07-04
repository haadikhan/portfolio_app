import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:portfolio_app/src/features/investor/data/models/txn_item.dart";
import "package:portfolio_app/src/features/reports/services/report_pdf_builder.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel("plugins.flutter.io/path_provider"),
      (call) async => ".",
    );
  });

  test("buildInvestorReportPdf succeeds with sample transactions", () async {
    final txns = [
      TxnItem(
        id: "1",
        type: "deposit",
        status: "approved",
        amount: 1000,
        createdAt: DateTime(2026, 1, 15, 10, 30),
      ),
      TxnItem(
        id: "2",
        type: "withdrawal",
        status: "completed",
        amount: 500,
        createdAt: DateTime(2026, 2, 1),
        note: "completed_via_legacy_admin_approve",
      ),
      TxnItem(
        id: "3",
        type: "profit_entry",
        status: "approved",
        amount: 50,
        createdAt: DateTime(2026, 2, 10),
      ),
    ];

    const labels = ReportPdfLabels(
      documentTitle: "Transaction Report",
      headerAccountTitle: "Account Title",
      headerPortfolioNo: "Portfolio No.",
      headerReportType: "Report Type",
      reportTypeFiveMarket: "Five-Market Daily Profit Report",
      reportTypeMonthly: "Monthly Return Report",
      period: "Period",
      summary: "Summary",
      colTxnId: "Txn ID",
      colDate: "Date & Time",
      colDescription: "Transaction Description",
      colStatus: "Status",
      colDebit: "Debit (PKR)",
      colCredit: "Credit (PKR)",
      colBalance: "Balance (PKR)",
      colNote: "Remarks",
      totalDeposits: "Total Deposits (Approved)",
      totalWithdrawals: "Total Redemptions (Disbursed)",
      totalProfit: "Total Profit Credits (Approved)",
      totalManagementFees: "Total Management Fees (PKR)",
      footer: "Footer",
      transactionsHeading: "Transaction Ledger",
      letterheadPortfolioTitle: "Amanah Multi Asset Portfolio",
    );

    final bytes = await buildInvestorReportPdf(
      accountLabel: "Test User",
      portfolioNumber: "ABCD1234",
      reportType: ReportType.monthlyReturn,
      periodStart: DateTime(2026, 1, 1),
      periodEndInclusive: DateTime(2026, 2, 28),
      transactions: txns,
      labels: labels,
      isYearlyReport: false,
      openingBalance: 0.0,
    );

    expect(bytes.length, greaterThan(1000));
  });
}
