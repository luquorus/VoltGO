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

  CollaboratorPerformance({
    required this.collaboratorId,
    required this.fullName,
    required this.totalTasks,
    required this.passRate,
    required this.avgCompletionTimeHours,
    required this.avgDistanceMeters,
    required this.slaComplianceRate,
  });

  factory CollaboratorPerformance.fromJson(Map<String, dynamic> json) {
    return CollaboratorPerformance(
      collaboratorId: (json['collaboratorId'] as String?) ?? '',
      fullName: (json['fullName'] as String?) ?? '',
      totalTasks: json['totalTasks'] as int? ?? 0,
      passRate: (json['passRate'] as num?)?.toDouble() ?? 0.0,
      avgCompletionTimeHours: (json['avgCompletionTimeHours'] as num?)?.toDouble() ?? 0.0,
      avgDistanceMeters: (json['avgDistanceMeters'] as num?)?.toDouble() ?? 0.0,
      slaComplianceRate: (json['slaComplianceRate'] as num?)?.toDouble() ?? 0.0,
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
    required this.monthlyBreakdown,
  });

  factory CollaboratorPerformanceDetail.fromJson(Map<String, dynamic> json) {
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
  final int tasksCompleted;
  final double passRate;

  MonthlyBreakdown({
    required this.month,
    required this.tasksCompleted,
    required this.passRate,
  });

  factory MonthlyBreakdown.fromJson(Map<String, dynamic> json) {
    return MonthlyBreakdown(
      month: (json['month'] as String?) ?? '',
      tasksCompleted: json['tasksCompleted'] as int? ?? 0,
      passRate: (json['passRate'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'month': month,
      'tasksCompleted': tasksCompleted,
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
