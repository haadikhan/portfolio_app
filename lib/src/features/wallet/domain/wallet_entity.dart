class WalletEntity {
  const WalletEntity({
    required this.userId,
    required this.totalDeposited,
    required this.totalWithdrawn,
    required this.totalProfit,
  });

  final String userId;
  final double totalDeposited;
  final double totalWithdrawn;
  final double totalProfit;

  double get balance => totalDeposited + totalProfit - totalWithdrawn;

  WalletEntity copyWith({
    double? totalDeposited,
    double? totalWithdrawn,
    double? totalProfit,
  }) {
    return WalletEntity(
      userId: userId,
      totalDeposited: totalDeposited ?? this.totalDeposited,
      totalWithdrawn: totalWithdrawn ?? this.totalWithdrawn,
      totalProfit: totalProfit ?? this.totalProfit,
    );
  }
}
