/// Collaborator Performance Models
/// 
/// Contains models for collaborator performance tracking

class CollaboratorPerformance {
  final String collaboratorId;
  final String fullName;
  final int totalTasks;
  final double passRate;
  final double avgCompletionTimeHours;
  final double avgDistanceMeters;
  final double slaComplianceRate;
  final int totalChangeRequests;
  final int publishedChangeRequests;
  final int rejectedChangeRequests;
  final double changeRequestPublishRate;

  CollaboratorPerformance({
    required this.collaboratorId,
    required this.fullName,
    required this.totalTasks,
    required this.passRate,
    required this.avgCompletionTimeHours,
    required this.avgDistanceMeters,
    required this.slaComplianceRate,
    this.totalChangeRequests = 0,
    this.publishedChangeRequests = 0,
    this.rejectedChangeRequests = 0,
    this.changeRequestPublishRate = 0.0,
  });

  factory CollaboratorPerformance.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      throw Exception('Performance data is null');
    }
    return CollaboratorPerformance(
      collaboratorId: (json['collaboratorId'] as String?) ?? '',
      fullName: (json['fullName'] as String?) ?? '',
      totalTasks: json['totalTasks'] as int? ?? 0,
      passRate: (json['passRate'] as num?)?.toDouble() ?? 0.0,
      avgCompletionTimeHours: (json['avgCompletionTimeHours'] as num?)?.toDouble() ?? 0.0,
      avgDistanceMeters: (json['avgDistanceMeters'] as num?)?.toDouble() ?? 0.0,
      slaComplianceRate: (json['slaComplianceRate'] as num?)?.toDouble() ?? 0.0,
      totalChangeRequests: json['totalChangeRequests'] as int? ?? 0,
      publishedChangeRequests: json['publishedChangeRequests'] as int? ?? 0,
      rejectedChangeRequests: json['rejectedChangeRequests'] as int? ?? 0,
      changeRequestPublishRate:
          (json['changeRequestPublishRate'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'collaboratorId': collaboratorId,
      'fullName': fullName,
      'totalTasks': totalTasks,
      'passRate': passRate,
      'avgCompletionTimeHours': avgCompletionTimeHours,
      'avgDistanceMeters': avgDistanceMeters,
      'slaComplianceRate': slaComplianceRate,
      'totalChangeRequests': totalChangeRequests,
      'publishedChangeRequests': publishedChangeRequests,
      'rejectedChangeRequests': rejectedChangeRequests,
      'changeRequestPublishRate': changeRequestPublishRate,
    };
  }
}

class CollaboratorPerformanceDetail extends CollaboratorPerformance {
  final List<MonthlyBreakdown> monthlyBreakdown;

  CollaboratorPerformanceDetail({
    required super.collaboratorId,
    required super.fullName,
    required super.totalTasks,
    required super.passRate,
    required super.avgCompletionTimeHours,
    required super.avgDistanceMeters,
    required super.slaComplianceRate,
    super.totalChangeRequests,
    super.publishedChangeRequests,
    super.rejectedChangeRequests,
    super.changeRequestPublishRate,
    required this.monthlyBreakdown,
  });

  factory CollaboratorPerformanceDetail.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      throw Exception('Performance detail data is null');
    }
    final monthlyJson = json['monthlyBreakdown'] as List<dynamic>? ?? [];
    final monthly = monthlyJson
        .map((e) => MonthlyBreakdown.fromJson(e as Map<String, dynamic>))
        .toList();

    return CollaboratorPerformanceDetail(
      collaboratorId: (json['collaboratorId'] as String?) ?? '',
      fullName: (json['fullName'] as String?) ?? '',
      totalTasks: json['totalTasks'] as int? ?? 0,
      passRate: (json['passRate'] as num?)?.toDouble() ?? 0.0,
      avgCompletionTimeHours: (json['avgCompletionTimeHours'] as num?)?.toDouble() ?? 0.0,
      avgDistanceMeters: (json['avgDistanceMeters'] as num?)?.toDouble() ?? 0.0,
      slaComplianceRate: (json['slaComplianceRate'] as num?)?.toDouble() ?? 0.0,
      totalChangeRequests: json['totalChangeRequests'] as int? ?? 0,
      publishedChangeRequests: json['publishedChangeRequests'] as int? ?? 0,
      rejectedChangeRequests: json['rejectedChangeRequests'] as int? ?? 0,
      changeRequestPublishRate:
          (json['changeRequestPublishRate'] as num?)?.toDouble() ?? 0.0,
      monthlyBreakdown: monthly,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'monthlyBreakdown': monthlyBreakdown.map((e) => e.toJson()).toList(),
    };
  }
}

class MonthlyBreakdown {
  final String month; // Format: YYYY-MM
  final int passedTasks;
  final int failedTasks;
  final double passRate;

  MonthlyBreakdown({
    required this.month,
    required this.passedTasks,
    required this.failedTasks,
    required this.passRate,
  });

  int get totalTasks => passedTasks + failedTasks;

  factory MonthlyBreakdown.fromJson(Map<String, dynamic> json) {
    return MonthlyBreakdown(
      month: (json['month'] as String?) ?? '',
      passedTasks: json['passedTasks'] as int? ?? 0,
      failedTasks: json['failedTasks'] as int? ?? 0,
      passRate: (json['passRate'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'month': month,
      'passedTasks': passedTasks,
      'failedTasks': failedTasks,
      'passRate': passRate,
    };
  }

  String get displayMonth {
    if (month.isEmpty) return '';
    final parts = month.split('-');
    if (parts.length != 2) return month;
    final year = parts[0];
    final monthNum = int.tryParse(parts[1]) ?? 1;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[monthNum - 1]} $year';
  }
}
