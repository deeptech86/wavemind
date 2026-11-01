/// A Wavemind user account as returned by the `/auth/*` endpoints.
///
/// This is the authenticated sailor's identity record — the only data that
/// leaves the device. It never carries the password (the backend only ever
/// returns the public projection).
class Account {
  const Account({
    required this.id,
    required this.name,
    required this.email,
    required this.age,
    required this.sex,
    this.fleetName,
    required this.createdAt,
  });

  final int id;
  final String name;
  final String email;
  final int age;
  final String sex;

  /// Optional, free-text fleet/vessel the sailor sails with. May be null.
  final String? fleetName;
  final String createdAt;

  factory Account.fromJson(Map<String, Object?> json) => Account(
    id: (json['id'] as num?)?.toInt() ?? 0,
    name: json['name'] as String? ?? '',
    email: json['email'] as String? ?? '',
    age: (json['age'] as num?)?.toInt() ?? 0,
    sex: json['sex'] as String? ?? '',
    fleetName: json['fleet_name'] as String?,
    createdAt: json['created_at'] as String? ?? '',
  );
}

/// The envelope `/auth/signup` and `/auth/login` return: a session [token]
/// plus the authenticated [account].
class AuthResult {
  const AuthResult({required this.token, required this.account});

  final String token;
  final Account account;

  factory AuthResult.fromJson(Map<String, Object?> json) => AuthResult(
    token: json['token'] as String? ?? '',
    account: Account.fromJson(
      (json['user'] as Map<String, Object?>?) ?? const {},
    ),
  );
}
