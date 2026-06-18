/// Display-only labels for transaction type, status, and system notes.
/// Firestore values are unchanged; use these for PDF and in-app UI.
library;

import "package:flutter/material.dart";
import "package:intl/intl.dart";

import "../i18n/app_translations.dart";

final _txnAmountFormat = NumberFormat.currency(
  symbol: "PKR ",
  decimalDigits: 2,
);

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

/// True when this transaction adds money to the investor wallet (green).
bool isCredit(String type, [double? amount]) {
  final t = type.toLowerCase();
  return switch (t) {
    "deposit" => true,
    "profit_entry" || "profit" => (amount ?? 0) >= 0,
    "adjustment" => (amount ?? 0) >= 0,
    _ => false,
  };
}

/// Green for credits, red for debits (theme-aware).
Color transactionAmountColor(
  String type,
  BuildContext context, {
  double? amount,
}) {
  final scheme = Theme.of(context).colorScheme;
  return isCredit(type, amount) ? scheme.primary : scheme.error;
}

/// Signed PKR amount string; always uses absolute magnitude.
String formatTransactionAmount(String type, double amount) {
  final prefix = isCredit(type, amount) ? "+" : "-";
  return "$prefix${_txnAmountFormat.format(amount.abs())}";
}

/// User-facing transaction type label (English; PDF / non-UI).
String displayTransactionType(String type, {double? amount}) {
  switch (type.toLowerCase()) {
    case "deposit":
      return "Deposit";
    case "withdrawal":
      return "Redemption";
    case "profit":
    case "profit_entry":
      return (amount ?? 0) < 0 ? "Daily Loss" : "Daily Profit";
    case "management_fee":
      return "Management Fee";
    case "performance_fee":
      return "Performance Fee";
    case "front_end_load_fee":
      return "Front-End Load Fee";
    case "referral_fee":
      return "Referral Commission";
    default:
      if (type.toLowerCase().contains("fee")) {
        return "Fee";
      }
      return _titleCaseWords(type.replaceAll("_", " "));
  }
}

/// Localized transaction type label for in-app lists.
String localizedTransactionTypeLabel(
  BuildContext context,
  String type, {
  double? amount,
}) {
  switch (type.toLowerCase()) {
    case "deposit":
      return context.tr("txn_type_deposit");
    case "withdrawal":
      return context.tr("txn_type_withdrawal");
    case "profit":
    case "profit_entry":
      return (amount ?? 0) < 0
          ? context.tr("tx_label_daily_loss")
          : context.tr("tx_label_profit_entry");
    case "management_fee":
      return context.tr("tx_label_management_fee");
    case "performance_fee":
      return context.tr("tx_label_performance_fee");
    case "front_end_load_fee":
      return context.tr("tx_label_front_end_load_fee");
    case "referral_fee":
      return context.tr("tx_label_referral_fee");
    default:
      if (type.toLowerCase().contains("fee")) {
        return context.tr("tx_label_fee");
      }
      return _titleCaseWords(type.replaceAll("_", " "));
  }
}

/// Secondary line for transaction rows (notes → ref → period → id tail).
String transactionListSubtitle({
  required String id,
  String? notes,
  String? relatedTxId,
  String? periodKey,
  int maxNoteChars = 40,
}) {
  final trimmedNotes = notes?.trim();
  if (trimmedNotes != null && trimmedNotes.isNotEmpty) {
    if (trimmedNotes.length <= maxNoteChars) {
      return trimmedNotes;
    }
    return "${trimmedNotes.substring(0, maxNoteChars)}…";
  }

  final ref = relatedTxId?.trim();
  if (ref != null && ref.isNotEmpty) {
    final tail = ref.length <= 8 ? ref : ref.substring(ref.length - 8);
    return "Ref: $tail";
  }

  final pk = periodKey?.trim();
  if (pk != null && pk.isNotEmpty) {
    return pk;
  }

  return id.length <= 8 ? id : id.substring(id.length - 8);
}

/// Subtitle from a Firestore transaction document map.
String transactionListSubtitleFromMap({
  required String id,
  required Map<String, dynamic> data,
}) {
  final noteSingular = (data["note"] as String?)?.trim();
  final notePlural = (data["notes"] as String?)?.trim();
  final notes = noteSingular != null && noteSingular.isNotEmpty
      ? noteSingular
      : notePlural;
  final relatedTxId =
      (data["relatedTxId"] as String?)?.trim() ??
      (data["refId"] as String?)?.trim();
  final periodKey =
      (data["periodKey"] as String?)?.trim() ??
      (data["datePkt"] as String?)?.trim();

  return transactionListSubtitle(
    id: id,
    notes: notes,
    relatedTxId: relatedTxId,
    periodKey: periodKey,
  );
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

/// Returns a display-friendly transaction ID.
/// Custom IDs (ISC- / TXN-) are returned as-is.
/// Firestore auto-IDs (20 chars) are replaced with
/// a type-based prefix + last 8 chars of the ID.
String formatTransactionId(String id, String type) {
  if (id.startsWith("ISC-") || id.startsWith("TXN-")) {
    return id;
  }

  final suffix = id.length >= 8
      ? id.substring(id.length - 8).toUpperCase()
      : id.toUpperCase();

  final String prefix;
  switch (type.toLowerCase()) {
    case "profit":
    case "profit_entry":
    case "daily_profit":
      prefix = "ISC-PRF";
      break;
    case "management_fee":
    case "fee":
    case "admin_fee":
      prefix = "ISC-FEE";
      break;
    case "front_end_load":
    case "front_end_fee":
      prefix = "ISC-FEL";
      break;
    case "performance_fee":
      prefix = "ISC-PFF";
      break;
    case "referral":
    case "referral_fee":
      prefix = "ISC-REF";
      break;
    case "adjustment":
      prefix = "ISC-ADJ";
      break;
    case "deposit":
      prefix = "ISC-DEP";
      break;
    case "withdrawal":
    case "redemption":
      prefix = "ISC-WDR";
      break;
    default:
      prefix = "ISC-SYS";
      break;
  }

  return "$prefix-$suffix";
}
