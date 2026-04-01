import "../../../core/common/value_enums.dart";

class TransactionEntity {
  const TransactionEntity({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    required this.status,
    required this.createdAt,
    this.notes,
  });

  final String id;
  final String userId;
  final TransactionType type;
  final double amount;
  final TransactionStatus status;
  final DateTime createdAt;
  final String? notes;

  TransactionEntity copyWith({
    TransactionStatus? status,
    String? notes,
  }) {
    return TransactionEntity(
      id: id,
      userId: userId,
      type: type,
      amount: amount,
      status: status ?? this.status,
      createdAt: createdAt,
      notes: notes ?? this.notes,
    );
  }
}
