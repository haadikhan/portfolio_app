import "dart:math";

/// A pending deposit or an unsettled withdrawal that blocks cash desk posting.
class CashDeskBlocker {
  const CashDeskBlocker({
    required this.kind,
    required this.id,
    required this.status,
  });

  final String kind;
  final String id;
  final String status;
}

/// Pure form rules for the admin Cash Desk screen.
class CashDeskFormLogic {
  static final _keyPattern = RegExp(r"^[A-Za-z0-9_-]{8,128}$");

  static List<CashDeskBlocker> blockersFromTransactions(
    Iterable<Map<String, dynamic>> docs,
  ) {
    final out = <CashDeskBlocker>[];
    for (final d in docs) {
      final type = (d["type"] ?? "").toString().toLowerCase();
      final status = (d["status"] ?? "").toString().toLowerCase();
      final id = (d["id"] ?? "").toString();
      if (type == "withdrawal" &&
          (status == "pending" || status == "approved")) {
        out.add(CashDeskBlocker(kind: "withdrawal", id: id, status: status));
      } else if (type == "deposit" && status == "pending") {
        out.add(CashDeskBlocker(kind: "deposit", id: id, status: status));
      }
    }
    return out;
  }

  /// Same rules as [findCashDeskBlockers] in admin_cash_desk.js.
  static List<CashDeskBlocker> mergeBlockers({
    required Iterable<Map<String, dynamic>> transactions,
    required Iterable<Map<String, dynamic>> withdrawalRequests,
    required Iterable<Map<String, dynamic>> depositRequests,
  }) {
    final blockers = <CashDeskBlocker>[];
    final seenTx = <String>{};
    final txStatus = <String, String>{};
    for (final d in transactions) {
      final id = (d["id"] ?? "").toString();
      if (id.isNotEmpty) {
        txStatus[id] = (d["status"] ?? "").toString().toLowerCase();
      }
    }

    for (final d in transactions) {
      final type = (d["type"] ?? "").toString().toLowerCase();
      final status = (d["status"] ?? "").toString().toLowerCase();
      final id = (d["id"] ?? "").toString();
      if (type == "withdrawal" &&
          (status == "pending" || status == "approved")) {
        blockers.add(CashDeskBlocker(kind: "withdrawal", id: id, status: status));
        if (id.isNotEmpty) seenTx.add(id);
      } else if (type == "deposit" && status == "pending") {
        blockers.add(CashDeskBlocker(kind: "deposit", id: id, status: status));
        if (id.isNotEmpty) seenTx.add(id);
      }
    }

    for (final d in withdrawalRequests) {
      final status = (d["status"] ?? "").toString().toLowerCase();
      if (status != "pending" && status != "approved") continue;
      final tid = (d["transactionId"] ?? "").toString();
      if (tid.isNotEmpty) {
        final linked = txStatus[tid];
        if (linked == "completed" || linked == "rejected") continue;
        if (seenTx.contains(tid)) continue;
      }
      blockers.add(CashDeskBlocker(
        kind: "withdrawal_request",
        id: (d["id"] ?? "").toString(),
        status: status,
      ));
    }

    for (final d in depositRequests) {
      final status = (d["status"] ?? "").toString().toLowerCase();
      if (status != "pending") continue;
      final tid = (d["transactionId"] ?? "").toString();
      if (tid.isNotEmpty) {
        final linked = txStatus[tid];
        if (linked != null && linked != "pending") continue;
        if (seenTx.contains(tid)) continue;
      }
      blockers.add(CashDeskBlocker(
        kind: "deposit_request",
        id: (d["id"] ?? "").toString(),
        status: status,
      ));
    }

    return blockers;
  }

  static String blockedMessage(List<CashDeskBlocker> blockers) {
    if (blockers.isEmpty) return "";
    final lines = blockers
        .map((b) => "${b.kind} ${b.id} (${b.status})")
        .join("\n");
    return "Resolve open requests first:\n$lines";
  }

  static bool actionsEnabled({
    required bool busy,
    required bool blocked,
    required bool hasInvestor,
    required bool walletReady,
  }) {
    return !busy && !blocked && hasInvestor && walletReady;
  }

  /// Null when [amount] can be posted against [available].
  static String? validateAmount({
    required double? amount,
    required double available,
  }) {
    if (amount == null || !amount.isFinite || amount <= 0) {
      return "Enter an amount greater than zero.";
    }
    final rounded = double.parse(amount.toStringAsFixed(2));
    final cap = double.parse(available.toStringAsFixed(2));
    if (rounded > cap) return "Amount exceeds available balance.";
    return null;
  }

  static String fullBalanceText(double available) {
    if (!available.isFinite || available <= 0) return "0.00";
    return available.toStringAsFixed(2);
  }

  static double balanceAfter({
    required double available,
    required double amount,
    required bool credit,
  }) {
    final next = credit ? available + amount : available - amount;
    return double.parse(next.toStringAsFixed(2));
  }

  static String newIdempotencyKey() {
    final micros = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final salt = Random().nextInt(0x7fffffff).toRadixString(16);
    final key = "cd$micros$salt";
    if (!_keyPattern.hasMatch(key)) {
      return "cd${micros.padRight(8, "0")}";
    }
    return key;
  }
}
