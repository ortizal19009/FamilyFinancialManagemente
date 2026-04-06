class UserSession {
  const UserSession({
    required this.token,
    required this.fullName,
    required this.email,
    required this.role,
  });

  final String token;
  final String fullName;
  final String email;
  final String role;
}
