/// Contract Model
class Contract {
  final String id;
  final String collaboratorId;
  final String? region;
  final DateTime startDate;
  final DateTime endDate;
  final ContractStatus status;
  final String? note;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Contract({
    required this.id,
    required this.collaboratorId,
    this.region,
    required this.startDate,
    required this.endDate,
    required this.status,
    this.note,
    required this.createdAt,
    this.updatedAt,
  });

  factory Contract.fromJson(Map<String, dynamic> json) {
    return Contract(
      id: json['id'] as String,
      collaboratorId: json['collaboratorId'] as String,
      region: json['region'] as String?,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      status: ContractStatus.fromString(json['status'] as String),
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  bool get isActive =>
      status == ContractStatus.active &&
      endDate.isAfter(DateTime.now());
}

/// Contract Status
enum ContractStatus {
  active,
  terminated,
  expired;

  static ContractStatus fromString(String value) {
    switch (value.toUpperCase()) {
      case 'ACTIVE':
        return ContractStatus.active;
      case 'TERMINATED':
        return ContractStatus.terminated;
      case 'EXPIRED':
        return ContractStatus.expired;
      default:
        throw ArgumentError('Unknown contract status: $value');
    }
  }

  String get displayName {
    switch (this) {
      case ContractStatus.active:
        return 'Active';
      case ContractStatus.terminated:
        return 'Terminated';
      case ContractStatus.expired:
        return 'Expired';
    }
  }
}
