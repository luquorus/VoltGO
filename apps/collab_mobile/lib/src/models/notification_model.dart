/// Notification category enum
enum NotificationCategory {
  ALL,
  TASK,
  CONTRACT,
  STATION;

  String get value {
    switch (this) {
      case NotificationCategory.ALL:
        return 'ALL';
      case NotificationCategory.TASK:
        return 'TASK';
      case NotificationCategory.CONTRACT:
        return 'CONTRACT';
      case NotificationCategory.STATION:
        return 'STATION';
    }
  }

  static NotificationCategory fromString(String? value) {
    if (value == null) return NotificationCategory.ALL;
    return NotificationCategory.values.firstWhere(
      (e) => e.name == value || e.value == value,
      orElse: () => NotificationCategory.ALL,
    );
  }
}

/// Notification type enum
enum NotificationType {
  // Task related
  TASK_ASSIGNED,
  TASK_CHECKED_IN,
  TASK_SUBMITTED,
  TASK_REVIEWED_PASS,
  TASK_REVIEWED_FAIL,
  TASK_SLA_APPROACHING,
  TASK_SLA_OVERDUE,

  // Contract related
  CONTRACT_APPROVED,
  CONTRACT_CREATED,
  CONTRACT_UPDATED,
  CONTRACT_TERMINATED,
  CONTRACT_EXPIRING,
  CONTRACT_EXPIRED,

  // Station related
  STATION_ISSUE_REPORTED,
  STATION_ISSUE_RESOLVED,
  STATION_CHANGE_REQUEST_SUBMITTED,
  STATION_CHANGE_REQUEST_PUBLISHED,

  // System
  SYSTEM_ANNOUNCEMENT;

  static NotificationType fromString(String? value) {
    if (value == null) return NotificationType.SYSTEM_ANNOUNCEMENT;
    return NotificationType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => NotificationType.SYSTEM_ANNOUNCEMENT,
    );
  }

  NotificationCategory get category {
    switch (this) {
      case NotificationType.TASK_ASSIGNED:
      case NotificationType.TASK_CHECKED_IN:
      case NotificationType.TASK_SUBMITTED:
      case NotificationType.TASK_REVIEWED_PASS:
      case NotificationType.TASK_REVIEWED_FAIL:
      case NotificationType.TASK_SLA_APPROACHING:
      case NotificationType.TASK_SLA_OVERDUE:
        return NotificationCategory.TASK;
      case NotificationType.CONTRACT_APPROVED:
      case NotificationType.CONTRACT_CREATED:
      case NotificationType.CONTRACT_UPDATED:
      case NotificationType.CONTRACT_TERMINATED:
      case NotificationType.CONTRACT_EXPIRING:
      case NotificationType.CONTRACT_EXPIRED:
        return NotificationCategory.CONTRACT;
      case NotificationType.STATION_ISSUE_REPORTED:
      case NotificationType.STATION_ISSUE_RESOLVED:
      case NotificationType.STATION_CHANGE_REQUEST_SUBMITTED:
      case NotificationType.STATION_CHANGE_REQUEST_PUBLISHED:
        return NotificationCategory.STATION;
      case NotificationType.SYSTEM_ANNOUNCEMENT:
        return NotificationCategory.ALL;
    }
  }
}

/// Individual notification item
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

  NotificationItem({
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
      id: json['id'] as String,
      type: NotificationType.fromString(json['type'] as String?),
      category: NotificationCategory.fromString(json['category'] as String?),
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      data: json['data'] as Map<String, dynamic>?,
      isRead: json['isRead'] as bool? ?? false,
      referenceId: json['referenceId'] as String?,
      referenceType: json['referenceType'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  NotificationItem copyWith({
    String? id,
    NotificationType? type,
    NotificationCategory? category,
    String? title,
    String? body,
    Map<String, dynamic>? data,
    bool? isRead,
    String? referenceId,
    String? referenceType,
    DateTime? createdAt,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      type: type ?? this.type,
      category: category ?? this.category,
      title: title ?? this.title,
      body: body ?? this.body,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      referenceId: referenceId ?? this.referenceId,
      referenceType: referenceType ?? this.referenceType,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Paginated notification response
class NotificationPage {
  final List<NotificationItem> notifications;
  final int totalElements;
  final int totalPages;
  final int page;
  final int size;
  final int unreadCount;

  NotificationPage({
    required this.notifications,
    required this.totalElements,
    required this.totalPages,
    required this.page,
    required this.size,
    required this.unreadCount,
  });

  factory NotificationPage.fromJson(Map<String, dynamic> json) {
    return NotificationPage(
      notifications: (json['notifications'] as List<dynamic>?)
              ?.map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      totalElements: json['totalElements'] as int? ?? 0,
      totalPages: json['totalPages'] as int? ?? 0,
      page: json['number'] as int? ?? 0,
      size: json['size'] as int? ?? 20,
      unreadCount: json['unreadCount'] as int? ?? 0,
    );
  }

  bool get hasMore => page < totalPages - 1;
}
