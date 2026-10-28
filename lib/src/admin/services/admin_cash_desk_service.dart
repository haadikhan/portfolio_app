import "package:cloud_functions/cloud_functions.dart";

class CashDeskResult {
  const CashDeskResult({
    required this.replayed,
    required this.transactionId,
    required this.requestId,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.amount,
  });

  final bool replayed;
  final String transactionId;
  final String? requestId;
  final double balanceBefore;
  final double balanceAfter;
  final double amount;

  factory CashDeskResult.fromMap(Map<String, dynamic> data) {
    return CashDeskResult(
      replayed: data["replayed"] == true,
      transactionId: (data["transactionId"] ?? "").toString(),
      requestId: data["requestId"]?.toString(),
      balanceBefore: (data["balanceBefore"] as num?)?.toDouble() ?? 0,
      balanceAfter: (data["balanceAfter"] as num?)?.toDouble() ?? 0,
      amount: (data["amount"] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Server calls for the admin Cash Desk. The screen depends on this type so
/// tests can substitute a fake without initializing Firebase.
abstract class CashDeskCaller {
  Future<CashDeskResult> withdraw({
    required String userId,
    required double amount,
    String? reference,
    String? note,
    required String idempotencyKey,
  });

  Future<CashDeskResult> credit({
    required String userId,
    required double amount,
    String? reference,
    String? note,
    required String idempotencyKey,
  });
}

class AdminCashDeskService implements CashDeskCaller {
  AdminCashDeskService({FirebaseFunctions? functions})
      : _f = functions ?? FirebaseFunctions.instanceFor(region: "us-central1");

  final FirebaseFunctions _f;

  @override
  Future<CashDeskResult> withdraw({
    required String userId,
    required double amount,
    String? reference,
    String? note,
    required String idempotencyKey,
  }) {
    return _call(
      "adminCashWithdraw",
      userId: userId,
      amount: amount,
      reference: reference,
      note: note,
      idempotencyKey: idempotencyKey,
    );
  }

  @override
  Future<CashDeskResult> credit({
    required String userId,
    required double amount,
    String? reference,
    String? note,
    required String idempotencyKey,
  }) {
    return _call(
      "adminCashCredit",
      userId: userId,
      amount: amount,
      reference: reference,
      note: note,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<CashDeskResult> _call(
    String name, {
    required String userId,
    required double amount,
    String? reference,
    String? note,
    required String idempotencyKey,
  }) async {
    final result = await _f.httpsCallable(name).call(<String, dynamic>{
      "userId": userId,
      "amount": amount,
      "idempotencyKey": idempotencyKey,
      if (reference != null && reference.trim().isNotEmpty)
        "reference": reference.trim(),
      if (note != null && note.trim().isNotEmpty) "note": note.trim(),
    });
    return CashDeskResult.fromMap(Map<String, dynamic>.from(result.data as Map));
  }
}
