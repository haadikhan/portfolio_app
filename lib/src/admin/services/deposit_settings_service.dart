import "package:cloud_firestore/cloud_firestore.dart";
import "package:firebase_auth/firebase_auth.dart";

/// Admin Firestore access for `settings/deposit_instructions`.
class DepositSettingsService {
  DepositSettingsService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  /// Saves company bank deposit instructions to Firestore (`merge: true`).
  Future<void> saveDepositInstructions({
    required String companyBankName,
    required String accountHolderName,
    required String ibanOrAccountNumber,
    String? branchName,
    String? instructions,
  }) async {
    final branch = branchName?.trim();
    final extra = instructions?.trim();

    await _firestore.collection("settings").doc("deposit_instructions").set(
      {
        "companyBankName": companyBankName.trim(),
        "accountHolderName": accountHolderName.trim(),
        "ibanOrAccountNumber": ibanOrAccountNumber.trim(),
        "branchName": branch == null || branch.isEmpty ? null : branch,
        "instructions": extra == null || extra.isEmpty ? null : extra,
        "updatedAt": FieldValue.serverTimestamp(),
        "updatedBy": _auth.currentUser?.uid ?? "admin",
      },
      SetOptions(merge: true),
    );
  }

  /// Returns document fields, or `null` if the doc does not exist.
  Future<Map<String, dynamic>?> loadDepositInstructions() async {
    final snap =
        await _firestore.collection("settings").doc("deposit_instructions").get();
    return snap.exists ? snap.data() : null;
  }
}
