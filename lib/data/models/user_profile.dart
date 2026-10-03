/// The small identity record stored on the remote backend (name/email/phone).
/// This is the ONLY data that leaves the device.
class UserProfile {
  const UserProfile({
    required this.name,
    required this.email,
    required this.phone,
  });

  final String name;
  final String email;
  final String phone;

  Map<String, Object?> toJson() => {
    'name': name,
    'email': email,
    'phone': phone,
  };

  factory UserProfile.fromJson(Map<String, Object?> json) => UserProfile(
    name: json['name'] as String? ?? '',
    email: json['email'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
  );
}
