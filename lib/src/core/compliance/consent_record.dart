class ConsentRecord {
  const ConsentRecord({
    required this.userId,
    required this.acceptedAt,
    required this.disclaimerText,
  });

  final String userId;
  final DateTime acceptedAt;
  final String disclaimerText;
}
