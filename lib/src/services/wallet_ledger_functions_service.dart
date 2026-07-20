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
    String? mpin,
  }) async {
    final result = await _f
        .httpsCallable("createWithdrawalRequest")
        .call(<String, dynamic>{
          "amount": amount,
          if (mpin != null && mpin.isNotEmpty) "mpin": mpin,
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

  /// Profit entry with optional backdated effectiveDate.
  /// effectiveDate null = today (serverTimestamp on server).
  Future<void> addProfitEntryWithDate({
    required String userId,
    required double amount,
    String? note,
    DateTime? effectiveDate,
  }) async {
    await _f.httpsCallable("addProfitEntry").call(<String, dynamic>{
      "userId": userId,
      "amount": amount,
      if (note != null && note.isNotEmpty) "note": note,
      if (effectiveDate != null)
        "effectiveDate":
            "${effectiveDate.year.toString().padLeft(4, '0')}"
            "-${effectiveDate.month.toString().padLeft(2, '0')}"
            "-${effectiveDate.day.toString().padLeft(2, '0')}",
    });
  }

  /// Adjustment entry with optional backdated effectiveDate.
  Future<void> addAdjustmentEntryWithDate({
    required String userId,
    required double amount,
    required String note,
    DateTime? effectiveDate,
  }) async {
    await _f.httpsCallable("addAdjustmentEntry").call(<String, dynamic>{
      "userId": userId,
      "amount": amount,
      "note": note,
      if (effectiveDate != null)
        "effectiveDate":
            "${effectiveDate.year.toString().padLeft(4, '0')}"
            "-${effectiveDate.month.toString().padLeft(2, '0')}"
            "-${effectiveDate.day.toString().padLeft(2, '0')}",
    });
  }

  /// Admin-created deposit (bypasses investor request flow).
  Future<void> adminCreateDeposit({
    required String userId,
    required double amount,
    String? note,
    String? paymentMethod,
    DateTime? effectiveDate,
  }) async {
    await _f.httpsCallable("adminCreateDeposit").call(<String, dynamic>{
      "userId": userId,
      "amount": amount,
      if (note != null && note.isNotEmpty) "note": note,
      if (paymentMethod != null && paymentMethod.isNotEmpty)
        "paymentMethod": paymentMethod,
      if (effectiveDate != null)
        "effectiveDate":
            "${effectiveDate.year.toString().padLeft(4, '0')}"
            "-${effectiveDate.month.toString().padLeft(2, '0')}"
            "-${effectiveDate.day.toString().padLeft(2, '0')}",
    });
  }

  /// Set account opening date for an investor.
  Future<void> setAccountOpeningDate({
    required String userId,
    required DateTime openingDate,
  }) async {
    await _f.httpsCallable("setAccountOpeningDate").call(<String, dynamic>{
      "userId": userId,
      "openingDate":
          "${openingDate.year.toString().padLeft(4, '0')}"
          "-${openingDate.month.toString().padLeft(2, '0')}"
          "-${openingDate.day.toString().padLeft(2, '0')}",
    });
  }

  /// Admin: write one historical return-history entry to
  /// portfolios/{userId}/returnHistory and update portfolios/{userId}.currentValue.
  Future<void> adminAddReturnHistoryEntry({
    required String userId,
    required double returnPct,
    required double profitAmount,
    required double previousValue,
    DateTime? effectiveDate,
  }) async {
    await _f.httpsCallable("adminAddReturnHistoryEntry").call(<String, dynamic>{
      "userId": userId,
      "returnPct": returnPct,
      "profitAmount": profitAmount,
      "previousValue": previousValue,
      if (effectiveDate != null)
        "effectiveDate":
            "${effectiveDate.year.toString().padLeft(4, '0')}"
            "-${effectiveDate.month.toString().padLeft(2, '0')}"
            "-${effectiveDate.day.toString().padLeft(2, '0')}",
    });
  }

  /// Admin: write one historical fee statement to
  /// users/{userId}/fee_statements/{periodKey}.
  /// periodKey format: "yyyy-MM" e.g. "2024-11"
  Future<void> adminAddFeeStatement({
    required String userId,
    required String periodKey,
    required double grossProfit,
    required double netProfit,
    double managementFee = 0,
    double performanceFee = 0,
    double principalAtStart = 0,
    double depositsThisMonth = 0,
    double withdrawalsThisMonth = 0,
  }) async {
    await _f.httpsCallable("adminAddFeeStatement").call(<String, dynamic>{
      "userId": userId,
      "periodKey": periodKey,
      "grossProfit": grossProfit,
      "netProfit": netProfit,
      "managementFee": managementFee,
      "performanceFee": performanceFee,
      "principalAtStart": principalAtStart,
      "depositsThisMonth": depositsThisMonth,
      "withdrawalsThisMonth": withdrawalsThisMonth,
    });
  }
}
