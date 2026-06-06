enum NotificationCategory {
  all,
  task,
  contract,
  station;

  String get displayName {
    switch (this) {
      case NotificationCategory.all:
        return 'All';
      case NotificationCategory.task:
        return 'Task';
      case NotificationCategory.contract:
        return 'Contract';
      case NotificationCategory.station:
        return 'Station';
    }
  }

  static NotificationCategory fromString(String? value) {
    if (value == null) return NotificationCategory.all;
    switch (value.toUpperCase()) {
      case 'TASK':
        return NotificationCategory.task;
      case 'CONTRACT':
        return NotificationCategory.contract;
      case 'STATION':
        return NotificationCategory.station;
      default:
        return NotificationCategory.all;
    }
  }
}

enum NotificationType {
  taskAssigned,
  taskCheckedIn,
  taskSubmitted,
  taskReviewedPass,
  taskReviewedFail,
  taskSlaApproaching,
  taskSlaOverdue,
  contractApproved,
  contractCreated,
  contractUpdated,
  contractTerminated,
  contractExpiring,
  contractExpired,
  stationIssueReported,
  stationIssueResolved,
  stationChangeRequestSubmitted,
  stationChangeRequestPublished,
  systemAnnouncement;

  static NotificationType fromString(String? value) {
    if (value == null) return NotificationType.systemAnnouncement;
    try {
      return NotificationType.values.firstWhere(
        (e) => e.name.toUpperCase() == value!.toUpperCase(),
      );
    } catch (_) {
      return NotificationType.systemAnnouncement;
    }
  }
}

class NotificationItem {
  final String id;
  final NotificationType type;
  final NotificationCategory category;
  final String title;
  final String body;
  final Map<String, dynamic>? data;
  final bool isRead;
  final String? referenceId;
  final String? referenceType;
  final DateTime createdAt;

  const NotificationItem({
    required this.id,
    required this.type,
    required this.category,
    required this.title,
    required this.body,
    this.data,
    required this.isRead,
    this.referenceId,
    this.referenceType,
    required this.createdAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id']?.toString() ?? '',
      type: NotificationType.fromString(json['type']?.toString()),
      category: NotificationCategory.fromString(json['category']?.toString()),
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      data: json['data'] as Map<String, dynamic>?,
      isRead: json['isRead'] as bool? ?? false,
      referenceId: json['referenceId']?.toString(),
      referenceType: json['referenceType'] as String?,
      createdAt: _parseDateTime(json['createdAt']),
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }
}

class NotificationPage {
  final List<NotificationItem> notifications;
  final int totalElements;
  final int totalPages;
  final int page;
  final int size;
  final int unreadCount;

  const NotificationPage({
    required this.notifications,
    required this.totalElements,
    required this.totalPages,
    required this.page,
    required this.size,
    required this.unreadCount,
  });

  factory NotificationPage.fromJson(Map<String, dynamic> json) {
    final notificationsList = json['notifications'] as List<dynamic>? ?? [];
    return NotificationPage(
      notifications: notificationsList
          .map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalElements: json['totalElements'] as int? ?? 0,
      totalPages: json['totalPages'] as int? ?? 0,
      page: json['page'] as int? ?? 0,
      size: json['size'] as int? ?? 20,
      unreadCount: json['unreadCount'] as int? ?? 0,
    );
  }

  bool get isFirst => page == 0;
  bool get isLast => page >= totalPages - 1;
}

class NotificationPreferenceItem {
  final NotificationCategory category;
  final bool emailEnabled;
  final bool pushEnabled;
  final bool inAppEnabled;

  const NotificationPreferenceItem({
    required this.category,
    required this.emailEnabled,
    required this.pushEnabled,
    required this.inAppEnabled,
  });

  factory NotificationPreferenceItem.fromJson(Map<String, dynamic> json) {
    return NotificationPreferenceItem(
      category: NotificationCategory.fromString(json['category']?.toString()),
      emailEnabled: json['emailEnabled'] as bool? ?? false,
      pushEnabled: json['pushEnabled'] as bool? ?? false,
      inAppEnabled: json['inAppEnabled'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category': category.name.toUpperCase(),
      'emailEnabled': emailEnabled,
      'pushEnabled': pushEnabled,
      'inAppEnabled': inAppEnabled,
    };
  }

  static List<NotificationPreferenceItem> fromJsonList(Map<String, dynamic> json) {
    final prefs = json['preferences'] as List<dynamic>? ?? [];
    return prefs
        .map((e) => NotificationPreferenceItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
