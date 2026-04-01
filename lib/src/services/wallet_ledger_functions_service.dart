import "package:cloud_functions/cloud_functions.dart";

/// Callable HTTPS functions (region must match [firebase/functions/wallet_ledger.js]).
class WalletLedgerFunctionsService {
  WalletLedgerFunctionsService({FirebaseFunctions? functions})
      : _f = functions ??
            FirebaseFunctions.instanceFor(region: "us-central1");

  final FirebaseFunctions _f;

  Future<Map<String, dynamic>> createDepositRequest({
    required double amount,
    required String paymentMethod,
    String? proofUrl,
  }) async {
    final result = await _f.httpsCallable("createDepositRequest").call(<String, dynamic>{
      "amount": amount,
      "paymentMethod": paymentMethod,
      if (proofUrl != null && proofUrl.isNotEmpty) "proofUrl": proofUrl,
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<Map<String, dynamic>> createWithdrawalRequest({
    required double amount,
  }) async {
    final result = await _f.httpsCallable("createWithdrawalRequest").call(<String, dynamic>{
      "amount": amount,
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<void> approveDeposit({
    required String requestId,
    String? note,
  }) async {
    await _f.httpsCallable("approveDeposit").call(<String, dynamic>{
      "requestId": requestId,
      if (note != null && note.isNotEmpty) "note": note,
    });
  }

  Future<void> rejectDeposit({
    required String requestId,
    String? reason,
  }) async {
    await _f.httpsCallable("rejectDeposit").call(<String, dynamic>{
      "requestId": requestId,
      if (reason != null && reason.isNotEmpty) "reason": reason,
    });
  }

  Future<void> approveWithdrawal({
    required String requestId,
    String? note,
  }) async {
    await _f.httpsCallable("approveWithdrawal").call(<String, dynamic>{
      "requestId": requestId,
      if (note != null && note.isNotEmpty) "note": note,
    });
  }

  Future<void> completeWithdrawal({
    required String requestId,
    String? settlementRef,
  }) async {
    await _f.httpsCallable("completeWithdrawal").call(<String, dynamic>{
      "requestId": requestId,
      if (settlementRef != null && settlementRef.isNotEmpty)
        "settlementRef": settlementRef,
    });
  }

  Future<void> rejectWithdrawal({
    required String requestId,
    String? reason,
  }) async {
    await _f.httpsCallable("rejectWithdrawal").call(<String, dynamic>{
      "requestId": requestId,
      if (reason != null && reason.isNotEmpty) "reason": reason,
    });
  }

  Future<Map<String, dynamic>> addProfitEntry({
    required String userId,
    required double amount,
    String? note,
  }) async {
    final result = await _f.httpsCallable("addProfitEntry").call(<String, dynamic>{
      "userId": userId,
      "amount": amount,
      if (note != null && note.isNotEmpty) "note": note,
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<Map<String, dynamic>> addAdjustmentEntry({
    required String userId,
    required double amount,
    required String note,
  }) async {
    final result = await _f.httpsCallable("addAdjustmentEntry").call(<String, dynamic>{
      "userId": userId,
      "amount": amount,
      "note": note,
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<void> recalculateWalletForUser(String userId) async {
    await _f.httpsCallable("recalculateWalletForUser").call(<String, dynamic>{
      "userId": userId,
    });
  }
}
