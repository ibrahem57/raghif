import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raghif/core/theme/app_theme.dart';
import 'package:raghif/features/queue/postpone_booking_screen.dart';
import 'package:raghif/features/queue/queue_controller.dart';
import 'package:raghif/features/queue/queue_logic.dart';
import '../../support/fake_queue_repository.dart';

void main() {
  testWidgets(
    'cancel leaves booking unchanged; offline confirmation stays on screen',
    (tester) async {
      final repo = FakeQueueRepository.seeded();
      final controller = QueueController(repo);
      addTearDown(() {
        controller.dispose();
        repo.dispose();
      });
      final p = repo.givenPurchase(
        userId: 'user-buyer',
        storeId: 'store-rimal',
        date: todayDateString(),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: PostponeBookingScreen(controller: controller, purchase: p),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('لن يتم خصم أي مبلغ إضافي'), findsOneWidget);
      repo.online = false;
      await tester.ensureVisible(find.text('تأكيد التأجيل'));
      await tester.tap(find.text('تأكيد التأجيل'));
      await tester.pumpAndSettle();
      expect(
        find.text('تعذر تأجيل الحجز. تحقق من الاتصال وحاول مجدداً.'),
        findsOneWidget,
      );
      expect((await repo.getPurchaseById(p.id))!.purchaseDate, p.purchaseDate);
      expect(find.text('تأكيد التأجيل'), findsOneWidget);
    },
  );
}
