/// Dashboard Statistics Models
/// 
/// Contains all models for the Analytics Dashboard screen

class DashboardStats {
  final int stationCount;
  final int pendingCRs;
  final int openIssues;
  final int overdueTasks;
  final int activeCollaborators;

  DashboardStats({
    required this.stationCount,
    required this.pendingCRs,
    required this.openIssues,
    required this.overdueTasks,
    required this.activeCollaborators,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      stationCount: json['stationCount'] as int? ?? 0,
      pendingCRs: json['pendingCRs'] as int? ?? 0,
      openIssues: json['openIssues'] as int? ?? 0,
      overdueTasks: json['overdueTasks'] as int? ?? 0,
      activeCollaborators: json['activeCollaborators'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stationCount': stationCount,
      'pendingCRs': pendingCRs,
      'openIssues': openIssues,
      'overdueTasks': overdueTasks,
      'activeCollaborators': activeCollaborators,
    };
  }
}

class TrendDataPoint {
  final String date;
  final int count;

  TrendDataPoint({
    required this.date,
    required this.count,
  });

  factory TrendDataPoint.fromJson(Map<String, dynamic> json) {
    return TrendDataPoint(
      date: json['date'] as String? ?? '',
      count: json['count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'count': count,
    };
  }
}

class BookingStats {
  final int totalBookings;
  final double completionRate;
  final double cancellationRate;
  final double revenue;
  final double avgSessionDurationMinutes;

  BookingStats({
    required this.totalBookings,
    required this.completionRate,
    required this.cancellationRate,
    required this.revenue,
    required this.avgSessionDurationMinutes,
  });

  factory BookingStats.fromJson(Map<String, dynamic> json) {
    return BookingStats(
      totalBookings: json['totalBookings'] as int? ?? 0,
      completionRate: (json['completionRate'] as num?)?.toDouble() ?? 0.0,
      cancellationRate: (json['cancellationRate'] as num?)?.toDouble() ?? 0.0,
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0.0,
      avgSessionDurationMinutes: (json['avgSessionDurationMinutes'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalBookings': totalBookings,
      'completionRate': completionRate,
      'cancellationRate': cancellationRate,
      'revenue': revenue,
      'avgSessionDurationMinutes': avgSessionDurationMinutes,
    };
  }
}

class IssueCategoryCount {
  final String category;
  final int count;

  IssueCategoryCount({
    required this.category,
    required this.count,
  });

  factory IssueCategoryCount.fromJson(Map<String, dynamic> json) {
    return IssueCategoryCount(
      category: json['category'] as String? ?? '',
      count: json['count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'count': count,
    };
  }
}

class IssueStats {
  final List<IssueCategoryCount> issuesByCategory;
  final double avgResolutionTimeHours;
  final int openCount;

  IssueStats({
    required this.issuesByCategory,
    required this.avgResolutionTimeHours,
    required this.openCount,
  });

  factory IssueStats.fromJson(Map<String, dynamic> json) {
    final categoriesJson = json['issuesByCategory'] as List<dynamic>? ?? [];
    final categories = categoriesJson
        .map((e) => IssueCategoryCount.fromJson(e as Map<String, dynamic>))
        .toList();

    return IssueStats(
      issuesByCategory: categories,
      avgResolutionTimeHours: (json['avgResolutionTimeHours'] as num?)?.toDouble() ?? 0.0,
      openCount: json['openCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'issuesByCategory': issuesByCategory.map((e) => e.toJson()).toList(),
      'avgResolutionTimeHours': avgResolutionTimeHours,
      'openCount': openCount,
    };
  }
}

class TrustOverviewItem {
  final String stationId;
  final String name;
  final String address;
  final int trustScore;
  final String serviceType;

  TrustOverviewItem({
    required this.stationId,
    required this.name,
    required this.address,
    required this.trustScore,
    required this.serviceType,
  });

  factory TrustOverviewItem.fromJson(Map<String, dynamic> json) {
    return TrustOverviewItem(
      stationId: json['stationId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      trustScore: json['trustScore'] as int? ?? 0,
      serviceType: json['serviceType'] as String? ?? 'CHARGING',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stationId': stationId,
      'name': name,
      'address': address,
      'trustScore': trustScore,
      'serviceType': serviceType,
    };
  }
}

class StationStatusDistribution {
  final String status;
  final int count;

  StationStatusDistribution({
    required this.status,
    required this.count,
  });

  factory StationStatusDistribution.fromJson(Map<String, dynamic> json) {
    return StationStatusDistribution(
      status: json['status'] as String? ?? '',
      count: json['count'] as int? ?? 0,
    );
  }
}
