import "../../../core/common/value_enums.dart";

class KycEntity {
  const KycEntity({
    required this.userId,
    required this.cnicFrontUrl,
    required this.cnicBackUrl,
    required this.selfieUrl,
    required this.bankDetails,
    required this.nominee,
    required this.status,
  });

  final String userId;
  final String cnicFrontUrl;
  final String cnicBackUrl;
  final String selfieUrl;
  final String bankDetails;
  final String nominee;
  final KycStatus status;
}
