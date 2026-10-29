import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/app_notification.dart';
import '../../domain/repositories/notification_repository.dart';

class SupabaseNotificationRepository implements NotificationRepository {
  SupabaseNotificationRepository({required SupabaseClient client})
    : _client = client;

  final SupabaseClient _client;

  static NotificationUnavailableException mapError(Object error) =>
      NotificationUnavailableException(error);

  static AppNotification notificationFromRow(Map<String, dynamic> row) =>
      AppNotification(
        id: row['id'] as String,
        purchaseId: row['purchase_id'] as String,
        kind: row['kind'] as String,
        title: row['title'] as String,
        body: row['body'] as String,
        createdAt: DateTime.parse(row['created_at'] as String),
        readAt: row['read_at'] == null
            ? null
            : DateTime.parse(row['read_at'] as String),
      );

  Future<T> _authenticated<T>(Future<T> Function(String userId) action) async {
    final userId = _client.auth.currentUser?.id;
    if (_client.auth.currentSession == null || userId == null) {
      throw const NotificationUnavailableException();
    }
    try {
      final value = await action(userId);
      // A response from a signed-out/replaced session must not enter its inbox.
      if (_client.auth.currentUser?.id != userId) {
        throw const NotificationUnavailableException();
      }
      return value;
    } catch (error) {
      throw mapError(error);
    }
  }

  @override
  Future<List<AppNotification>> fetchNotifications() =>
      _authenticated((id) async {
        final rows = await _client
            .from('notification_inbox')
            .select('id,purchase_id,kind,title,body,created_at,read_at')
            .eq('user_id', id)
            .order('created_at', ascending: false)
            .order('id', ascending: false);
        return rows.map(notificationFromRow).toList();
      });

  @override
  Future<void> markRead(String notificationId) => _authenticated((_) async {
    await _client.rpc(
      'mark_notification_read',
      params: {'p_notification_id': notificationId},
    );
  });

  @override
  Future<void> markAllRead() => _authenticated((_) async {
    await _client.rpc('mark_all_notifications_read');
  });
}
