import "package:cloud_firestore/cloud_firestore.dart";
import "package:cloud_functions/cloud_functions.dart";

import "../../features/investment/domain/five_market_models.dart";

/// Maps [PkHoliday] to Firestore array elements (extension lives here per Phase 6).
extension PkHolidayMapper on PkHoliday {
  Map<String, dynamic> toMap() => {
        "date": date,
        "name": name,
        "isIslamicHoliday": isIslamicHoliday,
        "estimatedDate": estimatedDate,
      };
}

/// Admin HTTPS callables for five-market daily config, overrides, and ledger.
class FiveMarketAdminService {
  FiveMarketAdminService(this._functions, this._firestore);

  final FirebaseFunctions _functions;
  final FirebaseFirestore _firestore;

  Future<void> saveConfig({
    Map<String, num>? allocations,
    Map<String, num>? rates,
  }) async {
    if (allocations == null && rates == null) return;
    await _functions.httpsCallable("saveFiveMarketConfig").call(<String, dynamic>{
      if (allocations != null) "allocations": allocations,
      if (rates != null) "rates": rates,
    });
  }

  Future<void> saveDayOverride({
    required String date,
    required bool forceClosedAll,
    required bool forceOpenDailyProfits,
    required String reason,
  }) async {
    await _functions.httpsCallable("saveFiveMarketDayOverride").call({
      "date": date,
      "forceClosedAll": forceClosedAll,
      "forceOpenDailyProfits": forceOpenDailyProfits,
      "reason": reason.trim(),
    });
  }

  Future<void> setDailyLedger({
    required String userId,
    required bool enabled,
  }) async {
    await _functions.httpsCallable("setFiveMarketDailyLedger").call({
      "userId": userId,
      "enabled": enabled,
    });
  }

  /// Replaces the `holidays` array on `settings/pakistan_holidays` (admin rules).
  Future<void> saveHolidays({required List<PkHoliday> holidays}) async {
    await _firestore.collection("settings").doc("pakistan_holidays").set(
      {
        "holidays": holidays.map((h) => h.toMap()).toList(),
      },
      SetOptions(merge: true),
    );
  }
}

/// Maps [FirebaseFunctionsException] to a short admin-facing message.
String fiveMarketAdminCallableErrorMessage(FirebaseFunctionsException e) {
  final detail = e.message?.trim();
  return switch (e.code) {
    "unauthenticated" => "Sign in as an admin to continue.",
    "permission-denied" => "Admin permission required.",
    "invalid-argument" =>
      detail?.isNotEmpty == true ? detail! : "Invalid input. Check values and try again.",
    "internal" || "not-found" || "unavailable" =>
      "Server is unavailable. Deploy or restart Cloud Functions and try again.",
    _ => detail?.isNotEmpty == true ? detail! : e.code,
  };
}
