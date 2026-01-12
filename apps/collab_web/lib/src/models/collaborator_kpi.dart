/// Collaborator KPI Model
class CollaboratorKpi {
  final String month; // Format: YYYY-MM
  final int reviewedCount;
  final int passCount;
  final int failCount;

  CollaboratorKpi({
    required this.month,
    required this.reviewedCount,
    required this.passCount,
    required this.failCount,
  });

  factory CollaboratorKpi.fromJson(Map<String, dynamic> json) {
    return CollaboratorKpi(
      month: json['month'] as String? ?? '',
      reviewedCount: (json['reviewedCount'] as num?)?.toInt() ?? 0,
      passCount: (json['passCount'] as num?)?.toInt() ?? 0,
      failCount: (json['failCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'month': month,
      'reviewedCount': reviewedCount,
      'passCount': passCount,
      'failCount': failCount,
    };
  }

  /// Get pass rate as percentage
  double get passRate {
    if (reviewedCount == 0) return 0.0;
    return (passCount / reviewedCount) * 100;
  }

  /// Get fail rate as percentage
  double get failRate {
    if (reviewedCount == 0) return 0.0;
    return (failCount / reviewedCount) * 100;
  }

  /// Format month for display (e.g., "2026-01" -> "January 2026")
  String get formattedMonth {
    if (month.isEmpty || !month.contains('-')) return month;
    final parts = month.split('-');
    if (parts.length != 2) return month;
    
    final year = parts[0];
    final monthNum = int.tryParse(parts[1]);
    if (monthNum == null) return month;
    
    final monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    
    if (monthNum >= 1 && monthNum <= 12) {
      return '${monthNames[monthNum - 1]} $year';
    }
    return month;
  }
}

