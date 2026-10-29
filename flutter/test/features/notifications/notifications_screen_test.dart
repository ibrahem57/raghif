import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raghif/core/theme/app_theme.dart';
import 'package:raghif/domain/models/app_notification.dart';
import 'package:raghif/features/notifications/notifications_screen.dart';
import '../../support/fake_notification_repository.dart';

void main() {
  late FakeNotificationRepository repo;
  final opened = <String>[];
  setUp(() {
    opened.clear();
    repo = FakeNotificationRepository()
      ..items = [
        AppNotification(
          id: 'n1',
          purchaseId: 'p1',
          kind: 'confirmed',
          title: 'تم تأكيد الحجز',
          body: 'حجزك جاهز للعرض',
          createdAt: DateTime.utc(2026, 10, 27),
        ),
      ];
  });
  Widget app({double scale = 1}) => MaterialApp(
    theme: AppTheme.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: Directionality(textDirection: TextDirection.rtl, child: child!),
    ),
    home: NotificationsScreen(repository: repo, onOpenPurchase: opened.add),
  );
  testWidgets('pending fetch shows loading rather than a false empty state', (
    tester,
  ) async {
    repo.readGate = Completer<void>();
    await tester.pumpWidget(app());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('لا توجد إشعارات بعد'), findsNothing);
    repo.readGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('تم تأكيد الحجز'), findsOneWidget);
  });
  testWidgets('read write disables actions and opens once after completion', (
    tester,
  ) async {
    repo.saveGate = Completer<void>();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('عرض الحجز'));
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    final button = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'عرض الحجز'),
    );
    expect(button.onPressed, isNull);
    expect(opened, isEmpty);
    repo.saveGate!.complete();
    await tester.pumpAndSettle();
    expect(opened, ['p1']);
    expect(find.text('غير مقروء'), findsNothing);
  });
  testWidgets('pull refresh fetches updated server state', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    repo.items = [];
    await tester.drag(find.byType(ListView), const Offset(0, 350));
    await tester.pumpAndSettle();
    expect(find.text('لا توجد إشعارات بعد'), findsOneWidget);
  });
  testWidgets('opens the actual receipt and persists its read state', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('غير مقروء'), findsOneWidget);
    await tester.tap(find.text('عرض الحجز'));
    await tester.pumpAndSettle();
    expect(opened, ['p1']);
    expect(repo.marked, ['n1']);
    expect(find.text('غير مقروء'), findsNothing);
  });
  testWidgets(
    'save failure remains unread, reports failure and still opens receipt',
    (tester) async {
      repo.failSave = true;
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('عرض الحجز'));
      await tester.pumpAndSettle();
      expect(opened, ['p1']);
      expect(find.text('غير مقروء'), findsOneWidget);
      expect(
        find.text('تعذر حفظ حالة القراءة. حاول مرة أخرى.'),
        findsOneWidget,
      );
    },
  );
  testWidgets('unavailable is distinct from empty and retry recovers', (
    tester,
  ) async {
    repo.failRead = true;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('تعذر تحميل الإشعارات'), findsOneWidget);
    expect(find.text('لا توجد إشعارات بعد'), findsNothing);
    repo.failRead = false;
    repo.items = [];
    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pumpAndSettle();
    expect(find.text('لا توجد إشعارات بعد'), findsOneWidget);
  });
  for (final size in [const Size(320, 640), const Size(640, 320)]) {
    testWidgets('read all and linked action fit $size with large text', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(app(scale: 1.8));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('قراءة الكل'));
      await tester.pumpAndSettle();
      expect(find.text('قراءة الكل').hitTestable(), findsOneWidget);
      await tester.tap(find.text('قراءة الكل'));
      await tester.pumpAndSettle();
      expect(find.text('غير مقروء'), findsNothing);
      await tester.ensureVisible(find.text('عرض الحجز'));
      await tester.pumpAndSettle();
      expect(find.text('عرض الحجز').hitTestable(), findsOneWidget);
      await tester.tap(find.text('عرض الحجز'));
      await tester.pumpAndSettle();
      expect(opened, ['p1']);
      expect(tester.takeException(), isNull);
    });
  }
}
