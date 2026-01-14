/// Contract Model
/// 
/// Represents a contract for a collaborator
class Contract {
  final String id;
  final String collaboratorId;
  final String? collaboratorName;
  final String? region;
  final DateTime? startDate;
  final DateTime? endDate;
  final ContractStatus status;
  final DateTime? createdAt;
  final DateTime? terminatedAt;
  final String? note;
  final bool? isEffectivelyActive;

  Contract({
    required this.id,
    required this.collaboratorId,
    this.collaboratorName,
    this.region,
    this.startDate,
    this.endDate,
    required this.status,
    this.createdAt,
    this.terminatedAt,
    this.note,
    this.isEffectivelyActive,
  });

  factory Contract.fromJson(Map<String, dynamic> json) {
    return Contract(
      id: json['id'] as String,
      collaboratorId: json['collaboratorId'] as String,
      collaboratorName: json['collaboratorName'] as String?,
      region: json['region'] as String?,
      startDate: json['startDate'] != null
          ? DateTime.parse(json['startDate'] as String)
          : null,
      endDate: json['endDate'] != null
          ? DateTime.parse(json['endDate'] as String)
          : null,
      status: ContractStatus.fromString(json['status'] as String),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      terminatedAt: json['terminatedAt'] != null
          ? DateTime.parse(json['terminatedAt'] as String)
          : null,
      note: json['note'] as String?,
      isEffectivelyActive: json['isEffectivelyActive'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'collaboratorId': collaboratorId,
      if (collaboratorName != null) 'collaboratorName': collaboratorName,
      if (region != null) 'region': region,
      if (startDate != null) 'startDate': startDate!.toIso8601String().split('T')[0],
      if (endDate != null) 'endDate': endDate!.toIso8601String().split('T')[0],
      'status': status.value,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (terminatedAt != null) 'terminatedAt': terminatedAt!.toIso8601String(),
      if (note != null) 'note': note,
      if (isEffectivelyActive != null) 'isEffectivelyActive': isEffectivelyActive,
    };
  }
}

/// Contract Status Enum
enum ContractStatus {
  active('ACTIVE'),
  terminated('TERMINATED');

  final String value;

  const ContractStatus(this.value);

  static ContractStatus fromString(String value) {
    switch (value.toUpperCase()) {
      case 'ACTIVE':
        return ContractStatus.active;
      case 'TERMINATED':
        return ContractStatus.terminated;
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
    }
  }
}

/// Create Contract Request Model
class CreateContractDTO {
  final String collaboratorId;
  final String? region;
  final DateTime startDate;
  final DateTime endDate;
  final String? note;

  CreateContractDTO({
    required this.collaboratorId,
    this.region,
    required this.startDate,
    required this.endDate,
    this.note,
  });

  Map<String, dynamic> toJson() {
    return {
      'collaboratorId': collaboratorId,
      if (region != null && region!.isNotEmpty) 'region': region,
      'startDate': startDate.toIso8601String().split('T')[0],
      'endDate': endDate.toIso8601String().split('T')[0],
      if (note != null && note!.isNotEmpty) 'note': note,
    };
  }
}

/// Update Contract Request Model
class UpdateContractDTO {
  final String? region;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? note;

  UpdateContractDTO({
    this.region,
    this.startDate,
    this.endDate,
    this.note,
  });

  Map<String, dynamic> toJson() {
    return {
      if (region != null) 'region': region,
      if (startDate != null) 'startDate': startDate!.toIso8601String().split('T')[0],
      if (endDate != null) 'endDate': endDate!.toIso8601String().split('T')[0],
      if (note != null) 'note': note,
    };
  }
}

