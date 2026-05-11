import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter/foundation.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../providers/auth_providers.dart";

class DepositInstructions {
  const DepositInstructions({
    required this.companyBankName,
    required this.accountHolderName,
    required this.ibanOrAccountNumber,
    this.branchName,
    this.instructions,
  });

  factory DepositInstructions.fromFirestore(Map<String, dynamic> data) {
    return DepositInstructions(
      companyBankName: _readString(data["companyBankName"]),
      accountHolderName: _readString(data["accountHolderName"]),
      ibanOrAccountNumber: _readString(data["ibanOrAccountNumber"]),
      branchName: _readOptionalString(data["branchName"]),
      instructions: _readOptionalString(data["instructions"]),
    );
  }

  factory DepositInstructions.empty() => const DepositInstructions(
        companyBankName: "",
        accountHolderName: "",
        ibanOrAccountNumber: "",
        branchName: null,
        instructions: null,
      );

  /// Same dummy copy as `firebase/scripts/seed_deposit_instructions.js` — only
  /// used in [kDebugMode] when Firestore has no usable doc so the UI can be
  /// verified without seeding production.
  factory DepositInstructions.dummyDev() => const DepositInstructions(
        companyBankName: "NOT REAL BANK (Dummy HBL)",
        accountHolderName: "FAKE — Wakalat Test Holder",
        ibanOrAccountNumber: "PK00DUMMY0000000000000001",
        branchName: "Dummy Branch — Main Boulevard",
        instructions:
            "This text is test-only. Do not transfer real money to any dummy account.",
      );

  static String _readString(dynamic value) {
    if (value == null) return "";
    return value.toString().trim();
  }

  static String? _readOptionalString(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    return s.isEmpty ? null : s;
  }

  final String companyBankName;
  final String accountHolderName;
  final String ibanOrAccountNumber;
  final String? branchName;
  final String? instructions;

  bool get isEmpty =>
      accountHolderName.isEmpty && ibanOrAccountNumber.isEmpty;
}

final depositInstructionsProvider =
    StreamProvider<DepositInstructions>((ref) {
  return ref
      .read(firebaseFirestoreProvider)
      .collection("settings")
      .doc("deposit_instructions")
      .snapshots()
      .map((DocumentSnapshot<Map<String, dynamic>> snap) {
        final doc = snap.exists && snap.data() != null
            ? DepositInstructions.fromFirestore(snap.data()!)
            : DepositInstructions.empty();
        if (kDebugMode && doc.isEmpty) {
          return DepositInstructions.dummyDev();
        }
        return doc;
      });
});
