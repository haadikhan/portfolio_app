import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../providers/auth_providers.dart";

/// One investor monthly fee statement (mirrors the Cloud Function payload
/// written to `users/{uid}/fee_statements/{periodKey}`).
class FeeStatement {
  const FeeStatement({
    required this.periodKey,
    required this.principalAtStart,
    required this.depositsThisMonth,
    required this.withdrawalsThisMonth,
    required this.grossProfit,
    required this.netProfit,
    required this.managementFee,
    required this.performanceFee,
    required this.frontEndLoadFee,
    required this.referralFee,
    required this.totalFees,
    required this.effectiveFeeRatePct,
    required this.generatedAt,
  });

  final String periodKey;
  final double principalAtStart;
  final double depositsThisMonth;
  final double withdrawalsThisMonth;
  final double grossProfit;
  final double netProfit;
  final double managementFee;
  final double performanceFee;
  final double frontEndLoadFee;
  final double referralFee;
  final double totalFees;
  final double effectiveFeeRatePct;
  final DateTime? generatedAt;

  factory FeeStatement.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? {};
    double n(dynamic v) => (v as num?)?.toDouble() ?? 0;
    DateTime? t(dynamic v) {
      if (v is Timestamp) return v.toDate();
      return null;
    }

    return FeeStatement(
      periodKey: (d["periodKey"] as String?) ?? doc.id,
      principalAtStart: n(d["principalAtStart"]),
      depositsThisMonth: n(d["depositsThisMonth"]),
      withdrawalsThisMonth: n(d["withdrawalsThisMonth"]),
      grossProfit: n(d["grossProfit"]),
      netProfit: n(d["netProfit"]),
      managementFee: n(d["managementFee"]),
      performanceFee: n(d["performanceFee"]),
      frontEndLoadFee: n(d["frontEndLoadFee"]),
      referralFee: n(d["referralFee"]),
      totalFees: n(d["totalFees"]),
      effectiveFeeRatePct: n(d["effectiveFeeRatePct"]),
      generatedAt: t(d["generatedAt"]),
    );
  }
}

/// Streams the signed-in investor's monthly fee statements (newest first).
final userFeeStatementsProvider =
    StreamProvider<List<FeeStatement>>((ref) {
  return authBoundFirestoreStream<List<FeeStatement>>(
    ref,
    whenSignedOut: const [],
    body: (user) => ref
        .read(firebaseFirestoreProvider)
        .collection("users")
        .doc(user.uid)
        .collection("fee_statements")
        .orderBy("periodKey", descending: true)
        .limit(36)
        .snapshots()
        .map((snap) =>
            snap.docs.map(FeeStatement.fromDoc).toList()),
  );
});
