import 'dart:convert';

/// Audit Log Response Model
/// Represents an audit log entry with all details
class AuditLogResponse {
  final String id;
  final String actorId;
  final String actorRole;
  final String? actorEmail;
  final String action;
  final String entityType;
  final String? entityId;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  AuditLogResponse({
    required this.id,
    required this.actorId,
    required this.actorRole,
    this.actorEmail,
    required this.action,
    required this.entityType,
    this.entityId,
    required this.metadata,
    required this.createdAt,
  });

  factory AuditLogResponse.fromJson(Map<String, dynamic> json) {
    // Handle UUID which might come as String or already be converted
    String parseId(dynamic value) {
      if (value == null) return '';
      if (value is String) return value;
      return value.toString();
    }

    return AuditLogResponse(
      id: parseId(json['id']),
      actorId: parseId(json['actorId']),
      actorRole: json['actorRole'] as String? ?? '',
      actorEmail: json['actorEmail'] as String?,
      action: json['action'] as String? ?? '',
      entityType: json['entityType'] as String? ?? '',
      entityId: json['entityId'] != null ? parseId(json['entityId']) : null,
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'actorId': actorId,
      'actorRole': actorRole,
      if (actorEmail != null) 'actorEmail': actorEmail,
      'action': action,
      'entityType': entityType,
      if (entityId != null) 'entityId': entityId,
      'metadata': metadata,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Format metadata as pretty JSON string
  String get formattedMetadata {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(metadata);
  }
}
