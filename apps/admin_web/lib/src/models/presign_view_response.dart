/// PresignViewResponse model for presigned URL responses
class PresignViewResponse {
  final String viewUrl;
  final DateTime expiresAt;

  PresignViewResponse({
    required this.viewUrl,
    required this.expiresAt,
  });

  factory PresignViewResponse.fromJson(Map<String, dynamic> json) {
    return PresignViewResponse(
      viewUrl: json['viewUrl'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'viewUrl': viewUrl,
      'expiresAt': expiresAt.toIso8601String(),
    };
  }
}

