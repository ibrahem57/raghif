import '../models/app_notification.dart';

abstract class NotificationRepository {
  Future<List<AppNotification>> fetchNotifications();
  Future<void> markRead(String notificationId);
  Future<void> markAllRead();
}

class NotificationUnavailableException implements Exception {
  const NotificationUnavailableException([this.cause]);
  final Object? cause;
}
