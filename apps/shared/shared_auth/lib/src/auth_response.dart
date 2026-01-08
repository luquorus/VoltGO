/// AuthResponse model matching OpenAPI schema
/// 
/// Schema from openapi.yaml:
/// AuthResponse:
///   properties:
///     token: string (JWT)
///     userId: string (uuid)
///     email: string (email)
///     role: string
class AuthResponse {
  final String token;
  final String userId;
  final String email;
  final String role;

  AuthResponse({
    required this.token,
    required this.userId,
    required this.email,
    required this.role,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      token: json['token'] as String,
      userId: json['userId'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'userId': userId,
      'email': email,
      'role': role,
    };
  }
}

