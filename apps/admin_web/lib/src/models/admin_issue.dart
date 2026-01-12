/// Admin Issue Model
class AdminIssue {
  final String id;
  final String stationId;
  final String? stationName;
  final String reporterId;
  final String reporterEmail;
  final IssueCategory category;
  final String description;
  final IssueStatus status;
  final DateTime createdAt;
  final DateTime? decidedAt;
  final String? adminNote;

  AdminIssue({
    required this.id,
    required this.stationId,
    this.stationName,
    required this.reporterId,
    required this.reporterEmail,
    required this.category,
    required this.description,
    required this.status,
    required this.createdAt,
    this.decidedAt,
    this.adminNote,
  });

  factory AdminIssue.fromJson(Map<String, dynamic> json) {
    return AdminIssue(
      id: json['id']?.toString() ?? '',
      stationId: json['stationId']?.toString() ?? '',
      stationName: json['stationName']?.toString(),
      reporterId: json['reporterId']?.toString() ?? '',
      reporterEmail: json['reporterEmail']?.toString() ?? '',
      category: IssueCategory.fromString(json['category']?.toString() ?? 'OTHER'),
      description: json['description']?.toString() ?? '',
      status: IssueStatus.fromString(json['status']?.toString() ?? 'OPEN'),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString()).toLocal()
          : DateTime.now(),
      decidedAt: json['decidedAt'] != null
          ? DateTime.parse(json['decidedAt'].toString()).toLocal()
          : null,
      adminNote: json['adminNote']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'stationId': stationId,
      'stationName': stationName,
      'reporterId': reporterId,
      'reporterEmail': reporterEmail,
      'category': category.name,
      'description': description,
      'status': status.name,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'decidedAt': decidedAt?.toUtc().toIso8601String(),
      'adminNote': adminNote,
    };
  }

  // Helper methods
  bool get canAcknowledge => status == IssueStatus.open;
  bool get canResolve => status == IssueStatus.open || status == IssueStatus.acknowledged;
  bool get canReject => status == IssueStatus.open || status == IssueStatus.acknowledged;
}

enum IssueStatus {
  open,
  acknowledged,
  resolved,
  rejected;

  static IssueStatus fromString(String value) {
    switch (value.toUpperCase()) {
      case 'OPEN':
        return IssueStatus.open;
      case 'ACKNOWLEDGED':
        return IssueStatus.acknowledged;
      case 'RESOLVED':
        return IssueStatus.resolved;
      case 'REJECTED':
        return IssueStatus.rejected;
      default:
        return IssueStatus.open;
    }
  }

  String get displayName {
    switch (this) {
      case IssueStatus.open:
        return 'Open';
      case IssueStatus.acknowledged:
        return 'Acknowledged';
      case IssueStatus.resolved:
        return 'Resolved';
      case IssueStatus.rejected:
        return 'Rejected';
    }
  }

  String get name {
    switch (this) {
      case IssueStatus.open:
        return 'OPEN';
      case IssueStatus.acknowledged:
        return 'ACKNOWLEDGED';
      case IssueStatus.resolved:
        return 'RESOLVED';
      case IssueStatus.rejected:
        return 'REJECTED';
    }
  }
}

enum IssueCategory {
  locationWrong,
  priceWrong,
  hoursWrong,
  portsWrong,
  other;

  static IssueCategory fromString(String value) {
    switch (value.toUpperCase().replaceAll('_', '')) {
      case 'LOCATIONWRONG':
      case 'LOCATION_WRONG':
        return IssueCategory.locationWrong;
      case 'PRICEWRONG':
      case 'PRICE_WRONG':
        return IssueCategory.priceWrong;
      case 'HOURSWRONG':
      case 'HOURS_WRONG':
        return IssueCategory.hoursWrong;
      case 'PORTSWRONG':
      case 'PORTS_WRONG':
        return IssueCategory.portsWrong;
      default:
        return IssueCategory.other;
    }
  }

  String get displayName {
    switch (this) {
      case IssueCategory.locationWrong:
        return 'Location Wrong';
      case IssueCategory.priceWrong:
        return 'Price Wrong';
      case IssueCategory.hoursWrong:
        return 'Hours Wrong';
      case IssueCategory.portsWrong:
        return 'Ports Wrong';
      case IssueCategory.other:
        return 'Other';
    }
  }

  String get name {
    switch (this) {
      case IssueCategory.locationWrong:
        return 'LOCATION_WRONG';
      case IssueCategory.priceWrong:
        return 'PRICE_WRONG';
      case IssueCategory.hoursWrong:
        return 'HOURS_WRONG';
      case IssueCategory.portsWrong:
        return 'PORTS_WRONG';
      case IssueCategory.other:
        return 'OTHER';
    }
  }
}

