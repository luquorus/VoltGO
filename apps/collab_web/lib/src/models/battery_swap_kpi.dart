/// Battery Swap KPI Model for Collaborator Web
class BatterySwapKpi {
  final String month;
  final int completedCount;
  final int passedCount;
  final int failedCount;
  final int avgCompletionMinutes;
  final double accuracyRate;

  BatterySwapKpi({
    required this.month,
    required this.completedCount,
    required this.passedCount,
    required this.failedCount,
    required this.avgCompletionMinutes,
    required this.accuracyRate,
  });

  factory BatterySwapKpi.fromJson(Map<String, dynamic> json) {
    return BatterySwapKpi(
      month: json['month'] as String? ?? '',
      completedCount: (json['completedCount'] as num?)?.toInt() ?? 0,
      passedCount: (json['passedCount'] as num?)?.toInt() ?? 0,
      failedCount: (json['failedCount'] as num?)?.toInt() ?? 0,
      avgCompletionMinutes: (json['avgCompletionMinutes'] as num?)?.toInt() ?? 0,
      accuracyRate: (json['accuracyRate'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'month': month,
      'completedCount': completedCount,
      'passedCount': passedCount,
      'failedCount': failedCount,
      'avgCompletionMinutes': avgCompletionMinutes,
      'accuracyRate': accuracyRate,
    };
  }

  double get passRate {
    if (completedCount == 0) return 0.0;
    return (passedCount / completedCount) * 100;
  }

  double get failRate {
    if (completedCount == 0) return 0.0;
    return (failedCount / completedCount) * 100;
  }

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

  String get formattedAvgTime {
    if (avgCompletionMinutes < 60) {
      return '${avgCompletionMinutes}m';
    }
    final hours = avgCompletionMinutes ~/ 60;
    final minutes = avgCompletionMinutes % 60;
    if (minutes == 0) {
      return '${hours}h';
    }
    return '${hours}h ${minutes}m';
  }
}
