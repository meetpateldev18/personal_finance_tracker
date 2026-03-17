class UserModel {
  const UserModel({
    required this.id,
    required this.email,
    required this.username,
    required this.fullName,
    required this.role,
    required this.isEmailVerified,
  });

  final String id;
  final String email;
  final String username;
  final String fullName;
  final String role;
  final bool isEmailVerified;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      username: json['username'] as String,
      fullName: json['fullName'] as String,
      role: json['role'] as String? ?? 'USER',
      isEmailVerified: json['isEmailVerified'] as bool? ?? false,
    );
  }
}

class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final UserModel user;

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}
