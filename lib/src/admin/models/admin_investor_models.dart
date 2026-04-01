import "package:cloud_firestore/cloud_firestore.dart";

class AdminInvestorSummary {
  const AdminInvestorSummary({
    required this.userId,
    required this.name,
    required this.email,
    required this.phone,
    required this.kycStatus,
    required this.createdAt,
    required this.role,
  });

  final String userId;
  final String name;
  final String email;
  final String phone;
  final String kycStatus;
  final DateTime? createdAt;
  final String role;

  factory AdminInvestorSummary.fromFirestore(
    String userId,
    Map<String, dynamic> data,
  ) {
    return AdminInvestorSummary(
      userId: userId,
      name: (data["name"] as String? ?? "").trim(),
      email: (data["email"] as String? ?? "").trim(),
      phone: (data["phone"] as String? ?? data["phoneNumber"] as String? ?? "")
          .trim(),
      kycStatus: (data["kycStatus"] as String? ?? "pending").trim(),
      createdAt: _parseTime(data["createdAt"]),
      role: (data["role"] as String? ?? "investor").trim(),
    );
  }
}

class AdminInvestorWalletSnapshot {
  const AdminInvestorWalletSnapshot({
    required this.totalDeposited,
    required this.totalWithdrawn,
    required this.totalProfit,
  });

  final double totalDeposited;
  final double totalWithdrawn;
  final double totalProfit;

  double get balance => totalDeposited + totalProfit - totalWithdrawn;

  factory AdminInvestorWalletSnapshot.fromFirestore(Map<String, dynamic> data) {
    return AdminInvestorWalletSnapshot(
      totalDeposited: _toDouble(data["totalDeposited"]),
      totalWithdrawn: _toDouble(data["totalWithdrawn"]),
      totalProfit: _toDouble(data["totalProfit"]),
    );
  }

  static const empty = AdminInvestorWalletSnapshot(
    totalDeposited: 0,
    totalWithdrawn: 0,
    totalProfit: 0,
  );
}

class AdminInvestorTransaction {
  const AdminInvestorTransaction({
    required this.id,
    required this.type,
    required this.status,
    required this.amount,
    required this.createdAt,
    this.notes,
  });

  final String id;
  final String type;
  final String status;
  final double amount;
  final DateTime? createdAt;
  final String? notes;

  factory AdminInvestorTransaction.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return AdminInvestorTransaction(
      id: id,
      type: (data["type"] as String? ?? "unknown").trim(),
      status: (data["status"] as String? ?? "unknown").trim(),
      amount: _toDouble(data["amount"]),
      createdAt: _parseTime(data["createdAt"]),
      notes: (data["notes"] as String?)?.trim(),
    );
  }
}

class AdminInvestorDetail {
  const AdminInvestorDetail({
    required this.summary,
    required this.wallet,
    required this.transactions,
  });

  final AdminInvestorSummary summary;
  final AdminInvestorWalletSnapshot wallet;
  final List<AdminInvestorTransaction> transactions;

  double get totalInvestedFromTransactions => transactions
      .where((t) => t.type.toLowerCase() == "deposit")
      .fold<double>(0, (total, t) => total + t.amount);
}

DateTime? _parseTime(dynamic v) {
  if (v == null) return null;
  if (v is Timestamp) return v.toDate();
  return DateTime.tryParse(v.toString());
}

double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? "") ?? 0;
}
