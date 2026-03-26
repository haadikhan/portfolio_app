class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.name,
    required this.createdAt,
  });

  final String id;
  final String email;
  final String name;
  final DateTime createdAt;

  Map<String, dynamic> toMap() {
    return {
      "email": email,
      "name": name,
      "createdAt": createdAt.toIso8601String(),
    };
  }

  factory AppUser.fromMap(String id, Map<String, dynamic> map) {
    final created = map["createdAt"];
    return AppUser(
      id: id,
      email: map["email"] as String? ?? "",
      name: map["name"] as String? ?? "",
      createdAt: DateTime.tryParse(created?.toString() ?? "") ?? DateTime.now(),
    );
  }
}
