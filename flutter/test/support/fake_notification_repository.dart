import 'dart:async';

import 'package:raghif/domain/models/app_notification.dart';
import 'package:raghif/domain/repositories/notification_repository.dart';

class FakeNotificationRepository implements NotificationRepository {
  List<AppNotification> items = [];
  bool failRead = false;
  bool failSave = false;
  Completer<void>? readGate;
  Completer<void>? saveGate;
  final marked = <String>[];

  @override
  Future<List<AppNotification>> fetchNotifications() async {
    await readGate?.future;
    if (failRead) throw const NotificationUnavailableException();
    return List.of(items);
  }

  @override
  Future<void> markRead(String notificationId) async {
    await saveGate?.future;
    if (failSave) throw const NotificationUnavailableException();
    marked.add(notificationId);
    items = items
        .map((n) => n.id == notificationId ? n.asRead(DateTime.now()) : n)
        .toList();
  }

  @override
  Future<void> markAllRead() async {
    await saveGate?.future;
    if (failSave) throw const NotificationUnavailableException();
    marked.addAll(items.where((n) => !n.isRead).map((n) => n.id));
    items = items.map((n) => n.asRead(DateTime.now())).toList();
  }
}
