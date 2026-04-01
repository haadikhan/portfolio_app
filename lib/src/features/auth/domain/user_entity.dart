import "../../../core/common/value_enums.dart";

class UserEntity {
  const UserEntity({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String phone;
  final UserRole role;
  final UserStatus status;
  final DateTime createdAt;
}
