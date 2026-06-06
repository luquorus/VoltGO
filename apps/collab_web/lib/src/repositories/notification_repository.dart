import 'package:shared_api/shared_api.dart';
import '../models/notification_model.dart';

class NotificationRepository {
  final CollaboratorWebApiClient _apiClient;

  NotificationRepository(this._apiClient);

  Future<NotificationPage> getNotifications({
    NotificationCategory? category,
    bool? isRead,
    int page = 0,
    int size = 20,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'size': size,
    };

    if (category != null && category != NotificationCategory.all) {
      queryParams['category'] = category.name.toUpperCase();
    }
    if (isRead != null) {
      queryParams['isRead'] = isRead.toString();
    }

    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/collab/web/notifications',
      queryParameters: queryParams,
    );

    return NotificationPage.fromJson(response!);
  }

  Future<int> getUnreadCount() async {
    final response = await _apiClient.get<num>('/api/collab/web/notifications/unread-count');
    return response?.toInt() ?? 0;
  }

  Future<void> markAsRead(String id) async {
    await _apiClient.patch<void>('/api/collab/web/notifications/$id/read');
  }

  Future<void> markAllAsRead() async {
    await _apiClient.patch<void>('/api/collab/web/notifications/read-all');
  }

  Future<void> registerPushToken(String token, String deviceType) async {
    await _apiClient.post<void>(
      '/api/collab/web/notifications/push-token',
      data: {'token': token, 'deviceType': deviceType},
    );
  }

  Future<List<NotificationPreferenceItem>> getPreferences() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/collab/web/notifications/preferences',
    );
    if (response == null) return [];
    return NotificationPreferenceItem.fromJsonList(response);
  }

  Future<void> savePreferences(List<NotificationPreferenceItem> preferences) async {
    await _apiClient.put<void>(
      '/api/collab/web/notifications/preferences',
      data: {'preferences': preferences.map((e) => e.toJson()).toList()},
    );
  }
}
