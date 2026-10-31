import 'package:flutter_test/flutter_test.dart';
import 'package:raghif/data/repositories/supabase_notification_repository.dart';
import 'package:raghif/domain/repositories/notification_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('maps server timestamps, linked receipt and read state', () {
    final item = SupabaseNotificationRepository.notificationFromRow({
      'id': 'n1',
      'purchase_id': 'p1',
      'kind': 'ready',
      'title': 'حان دورك',
      'body': 'توجه إلى المخبز',
      'created_at': '2026-10-27T10:00:00Z',
      'read_at': null,
    });
    expect(item.purchaseId, 'p1');
    expect(item.kind, 'ready');
    expect(item.createdAt, DateTime.utc(2026, 10, 27, 10));
    expect(item.isRead, false);
  });
  test(
    'permission failure is unavailable, never an empty inbox or success',
    () {
      expect(
        SupabaseNotificationRepository.mapError(
          const PostgrestException(message: 'permission denied', code: '42501'),
        ),
        isA<NotificationUnavailableException>(),
      );
    },
  );
  test('missing authentication cannot read or mark notifications', () async {
    final client = SupabaseClient('https://example.supabase.co', 'key');
    final repo = SupabaseNotificationRepository(client: client);
    await expectLater(
      repo.fetchNotifications(),
      throwsA(isA<NotificationUnavailableException>()),
    );
    await expectLater(
      repo.markRead('another-user-notification'),
      throwsA(isA<NotificationUnavailableException>()),
    );
    await expectLater(
      repo.markAllRead(),
      throwsA(isA<NotificationUnavailableException>()),
    );
    await client.dispose();
  });
}
