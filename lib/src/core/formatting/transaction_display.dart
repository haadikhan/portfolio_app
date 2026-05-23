/// Display-only labels for transaction type, status, and system notes.
/// Firestore values are unchanged; use these for PDF and in-app UI.
library;

const _kFeeTypes = <String>{
  "front_end_load_fee",
  "referral_fee",
  "management_fee",
  "performance_fee",
};

/// True when the raw type is a withdrawal (shown as Redemption).
bool isRedemptionType(String type) => type.toLowerCase() == "withdrawal";

/// True when the raw type is a portfolio fee line item.
bool isFeeType(String type) => _kFeeTypes.contains(type.toLowerCase());

/// True when the raw type is profit or profit_entry.
bool isProfitCreditType(String type) {
  final t = type.toLowerCase();
  return t == "profit" || t == "profit_entry";
}

/// User-facing transaction type label.
String displayTransactionType(String type) {
  switch (type.toLowerCase()) {
    case "deposit":
      return "Deposit";
    case "withdrawal":
      return "Redemption";
    case "profit":
    case "profit_entry":
      return "Profit Credit";
    default:
      return _titleCaseWords(type.replaceAll("_", " "));
  }
}

/// User-facing status label (`completed` → Approved).
String displayTransactionStatus(String status) {
  switch (status.toLowerCase()) {
    case "pending":
      return "Pending";
    case "approved":
      return "Approved";
    case "completed":
      return "Approved";
    case "rejected":
      return "Rejected";
    default:
      return _titleCaseWords(status.replaceAll("_", " "));
  }
}

/// User-facing note; maps known system strings to finance wording.
String displayTransactionNote(String? note) {
  if (note == null || note.trim().isEmpty) return "—";
  final n = note.trim();
  final lower = n.toLowerCase();

  if (lower == "completed_via_legacy_admin_approve" ||
      lower == "completed_via_repairapprovedwithdrawals" ||
      lower == "completed") {
    return "Disbursed";
  }
  if (lower.startsWith("settlement:")) {
    return "Disbursed";
  }

  return _titleCaseFirstWordOnly(n);
}

String _titleCaseWords(String s) {
  if (s.isEmpty) return s;
  return s
      .split(RegExp(r"\s+"))
      .map((w) => w.isEmpty ? w : _capitalizeWord(w))
      .join(" ");
}

String _capitalizeWord(String w) {
  if (w.isEmpty) return w;
  return w[0].toUpperCase() + w.substring(1).toLowerCase();
}

/// Capitalize only the first character; preserve rest of user note.
String _titleCaseFirstWordOnly(String s) {
  if (s.isEmpty) return s;
  return s[0].toUpperCase() + s.substring(1);
}
