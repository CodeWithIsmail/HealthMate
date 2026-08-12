/// The user embedded in `AuthResult` (`/auth/login`, `/auth/signup`) and
/// returned by `/auth/me`.
class SessionUser {
  const SessionUser({required this.id, required this.username, required this.email, this.imageUrl});

  final String id;
  final String username;
  final String email;
  final String? imageUrl;

  factory SessionUser.fromJson(Map<String, dynamic> json) => SessionUser(
    id: json['id'] as String,
    username: json['username'] as String,
    email: json['email'] as String,
    imageUrl: json['imageUrl'] as String?,
  );
}
