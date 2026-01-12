/// Contract Model
class Contract {
  final String id;
  final String collaboratorId;
  final DateTime startDate;
  final DateTime endDate;
  final bool active;

  Contract({
    required this.id,
    required this.collaboratorId,
    required this.startDate,
    required this.endDate,
    required this.active,
  });

  factory Contract.fromJson(Map<String, dynamic> json) {
    return Contract(
      id: json['id'] as String? ?? '',
      collaboratorId: json['collaboratorId'] as String? ?? '',
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      active: json['active'] as bool? ?? 
              json['isEffectivelyActive'] as bool? ?? 
              false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'collaboratorId': collaboratorId,
      'startDate': startDate.toIso8601String().split('T')[0],
      'endDate': endDate.toIso8601String().split('T')[0],
      'active': active,
    };
  }

  /// Format date range as "MMM dd, yyyy - MMM dd, yyyy"
  String get dateRange {
    final start = _formatDate(startDate);
    final end = _formatDate(endDate);
    return '$start - $end';
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

