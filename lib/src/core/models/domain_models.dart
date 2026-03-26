enum UserRole { investor, admin, team }

enum TransactionType { deposit, withdrawal, profit, adjustment }

enum TransactionStatus { pending, approved, completed, rejected, cancelled }

class LedgerTransaction {
  const LedgerTransaction({
    required this.id,
    required this.userId,
    required this.type,
    required this.status,
    required this.amount,
    required this.createdAt,
    this.notes,
  });

  final String id;
  final String userId;
  final TransactionType type;
  final TransactionStatus status;
  final double amount;
  final DateTime createdAt;
  final String? notes;
}

class WalletSnapshot {
  const WalletSnapshot({
    required this.totalDeposited,
    required this.totalWithdrawn,
    required this.totalProfit,
    required this.reservedAmount,
  });

  final double totalDeposited;
  final double totalWithdrawn;
  final double totalProfit;
  final double reservedAmount;

  double get currentBalance =>
      totalDeposited + totalProfit - totalWithdrawn - reservedAmount;
}
