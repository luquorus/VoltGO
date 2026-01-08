/// API Error model matching OpenAPI schema
/// 
/// Schema from openapi.yaml:
/// ApiError:
///   properties:
///     traceId: string (uuid)
///     code: string
///     message: string
///     details: object
///     timestamp: string (date-time)
class ApiError {
  final String traceId;
  final String code;
  final String message;
  final Map<String, dynamic>? details;
  final DateTime timestamp;

  ApiError({
    required this.traceId,
    required this.code,
    required this.message,
    this.details,
    required this.timestamp,
  });

  factory ApiError.fromJson(Map<String, dynamic> json) {
    return ApiError(
      traceId: json['traceId'] as String,
      code: json['code'] as String,
      message: json['message'] as String,
      details: json['details'] as Map<String, dynamic>?,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'traceId': traceId,
      'code': code,
      'message': message,
      if (details != null) 'details': details,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  @override
  String toString() => 'ApiError(code: $code, message: $message, traceId: $traceId)';
}

