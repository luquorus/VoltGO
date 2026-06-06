/// AuthResponse model matching backend API response
///
/// Properties:
///   token: string (JWT)
///   userId: string (uuid)
///   email: string (email)
///   role: string (EV_USER, COLLABORATOR, ADMIN)
///   status: string (ACTIVE, PENDING_COLLABORATOR, BANNED)
class AuthResponse {
  final String token;
  final String userId;
  final String email;
  final String role;
  final String status;

  AuthResponse({
    required this.token,
    required this.userId,
    required this.email,
    required this.role,
    required this.status,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      token: json['token'] as String,
      userId: json['userId'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      status: json['status'] as String? ?? 'ACTIVE',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'userId': userId,
      'email': email,
      'role': role,
      'status': status,
    };
  }
}

