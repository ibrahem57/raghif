import 'package:flutter/material.dart';
import '../../core/widgets/offline_notice.dart';
import '../../domain/repositories/notification_repository.dart';
import '../auth/demo_accounts.dart';
import '../notifications/notifications_screen.dart';
import '../queue/confirmation_screen.dart';
import '../queue/queue_controller.dart';

void openInbox(
  BuildContext context,
  QueueController controller,
  DemoUser user,
  NotificationRepository? repository,
) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (inboxContext) {
        if (repository == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('الإشعارات')),
            body: const SafeArea(child: OfflineNotice()),
          );
        }
        return NotificationsScreen(
          repository: repository,
          onOpenPurchase: (id) {
            Navigator.of(inboxContext).push(
              MaterialPageRoute(
                builder: (_) => ConfirmationScreen(
                  controller: controller,
                  purchaseId: id,
                  currentUser: user,
                ),
              ),
            );
          },
        );
      },
    ),
  );
}
