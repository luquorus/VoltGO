/// Notification category enum for EV user notifications
enum NotificationCategory {
  ALL,
  BOOKING,
  BATTERY_SWAP,
  STATION,
  SYSTEM;

  String get value {
    switch (this) {
      case NotificationCategory.ALL:
        return 'ALL';
      case NotificationCategory.BOOKING:
        return 'BOOKING';
      case NotificationCategory.BATTERY_SWAP:
        return 'BATTERY_SWAP';
      case NotificationCategory.STATION:
        return 'STATION';
      case NotificationCategory.SYSTEM:
        return 'SYSTEM';
    }
  }

  String get displayName {
    switch (this) {
      case NotificationCategory.ALL:
        return 'All';
      case NotificationCategory.BOOKING:
        return 'Booking';
      case NotificationCategory.BATTERY_SWAP:
        return 'Swap';
      case NotificationCategory.STATION:
        return 'Station';
      case NotificationCategory.SYSTEM:
        return 'System';
    }
  }

  static NotificationCategory fromString(String? value) {
    if (value == null) return NotificationCategory.ALL;
    return NotificationCategory.values.firstWhere(
      (e) => e.name.toUpperCase() == value.toUpperCase() || e.value == value.toUpperCase(),
      orElse: () => NotificationCategory.ALL,
    );
  }
}

/// Notification type enum for EV user notifications
enum NotificationType {
  // BOOKING
  BOOKING_CONFIRMED,
  BOOKING_EXPIRED,
  BOOKING_CANCELLED,
  BOOKING_REMINDER,
  PAYMENT_SUCCESS,
  PAYMENT_FAILED,

  // BATTERY_SWAP
  SWAP_RESERVED,
  SWAP_ARRIVED,
  SWAP_CODE_GENERATED,
  SWAP_COMPLETED,
  SWAP_REMINDER,
  SWAP_EXPIRED,

  // STATION
  ISSUE_REPORTED,
  ISSUE_ACKNOWLEDGED,
  ISSUE_RESOLVED,
  CR_SUBMITTED,
  CR_APPROVED,
  CR_REJECTED,
  CR_PUBLISHED,
  STATION_TRUST_LOW,

  // SYSTEM
  SYSTEM_ANNOUNCEMENT;

  static NotificationType fromString(String? value) {
    if (value == null) return NotificationType.SYSTEM_ANNOUNCEMENT;
    return NotificationType.values.firstWhere(
      (e) => e.name.toUpperCase() == value.toUpperCase(),
      orElse: () => NotificationType.SYSTEM_ANNOUNCEMENT,
    );
  }

  NotificationCategory get category {
    switch (this) {
      case BOOKING_CONFIRMED:
      case BOOKING_EXPIRED:
      case BOOKING_CANCELLED:
      case BOOKING_REMINDER:
      case PAYMENT_SUCCESS:
      case PAYMENT_FAILED:
        return NotificationCategory.BOOKING;
      case SWAP_RESERVED:
      case SWAP_ARRIVED:
      case SWAP_CODE_GENERATED:
      case SWAP_COMPLETED:
      case SWAP_REMINDER:
      case SWAP_EXPIRED:
        return NotificationCategory.BATTERY_SWAP;
      case ISSUE_REPORTED:
      case ISSUE_ACKNOWLEDGED:
      case ISSUE_RESOLVED:
      case CR_SUBMITTED:
      case CR_APPROVED:
      case CR_REJECTED:
      case CR_PUBLISHED:
      case STATION_TRUST_LOW:
        return NotificationCategory.STATION;
      case SYSTEM_ANNOUNCEMENT:
        return NotificationCategory.SYSTEM;
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
    final typeStr = json['type'] as String?;
    final type = NotificationType.fromString(typeStr);
    
    return NotificationItem(
      id: json['id'] as String,
      type: type,
      category: json['category'] != null 
          ? NotificationCategory.fromString(json['category'] as String?)
          : type.category,
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
      totalElements: (json['totalElements'] as num?)?.toInt() ?? 0,
      totalPages: json['totalPages'] as int? ?? 0,
      page: json['page'] as int? ?? 0,
      size: json['size'] as int? ?? 20,
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
    );
  }

  bool get hasMore => page < totalPages - 1;
}
