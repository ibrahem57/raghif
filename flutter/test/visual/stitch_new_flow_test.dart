import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raghif/core/theme/app_theme.dart';
import 'package:raghif/domain/models/app_notification.dart';
import 'package:raghif/domain/models/user_model.dart';
import 'package:raghif/features/account/account_screen.dart';
import 'package:raghif/features/auth/bloc/auth_bloc.dart';
import 'package:raghif/features/locations/area_screen.dart';
import 'package:raghif/features/locations/governorate_screen.dart';
import 'package:raghif/features/locations/location_logic.dart';
import 'package:raghif/features/notifications/notifications_screen.dart';
import 'package:raghif/features/queue/postpone_booking_screen.dart';
import 'package:raghif/features/queue/queue_logic.dart';

import '../goldens/test_fonts.dart';
import '../support/fake_auth_repository.dart';
import '../support/fake_notification_repository.dart';
import '../support/queue_test_harness.dart';

const _user = UserModel(
  id: seededBuyerId,
  phone: '0599111111',
  nationalId: '900111222',
  name: 'أحمد ناصر',
  jawwalPayNumber: '0599333333',
  verificationStatus: VerificationStatus.verified,
);

Future<void> _capture(
  WidgetTester tester,
  GlobalKey boundaryKey,
  String name,
) async {
  final output = Platform.environment['STITCH_SCREENSHOT_DIR'];
  if (output == null || output.isEmpty) return;
  final boundary =
      boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('PNG encoding failed for $name');
      final directory = await Directory(output).create(recursive: true);
      await File(
        '${directory.path}${Platform.pathSeparator}$name.png',
      ).writeAsBytes(bytes.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

void main() {
  final viewports = [
    (name: 'phone', size: const Size(390, 884), scale: 1.0),
    (name: 'small_large_text', size: const Size(320, 640), scale: 1.5),
    (name: 'landscape', size: const Size(884, 390), scale: 1.0),
  ];

  for (final viewport in viewports) {
    testWidgets('Stitch new production flow: ${viewport.name}', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = viewport.size;
      addTearDown(tester.view.reset);
      await loadAppFonts(tester);

      final authRepository = FakeAuthRepository(
        users: [_user],
        sessionUserId: _user.id,
      );
      final auth = AuthBloc(authRepository: authRepository);
      // Close outside the fake-async body, after the mounted listeners detach.
      addTearDown(auth.close);
      auth.add(const CheckAuthSessionEvent());
      final harness = buildQueueHarness();
      final boundaryKey = GlobalKey();

      Future<void> paint() async {
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 100));
      }

      void check(String name) {
        expect(
          tester.takeException(),
          isNull,
          reason: '$name at ${viewport.name}',
        );
      }

      Future<void> show(Widget screen) async {
        await tester.pumpWidget(const SizedBox.shrink());
        await paint();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: BlocProvider<AuthBloc>.value(
              value: auth,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: AppTheme.light,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(viewport.scale)),
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: child!,
                  ),
                ),
                home: screen,
              ),
            ),
          ),
        );
        await paint();
        check('${screen.runtimeType} initial layout');
      }

      Future<void> capture(String name) async {
        check(name);
        if (viewport.name == 'phone') {
          await _capture(tester, boundaryKey, name);
        }
      }

      Future<void> reach(Finder target, String name) async {
        // Text entry queues EditableText's caret reveal after the frame. Let
        // that scroll finish before revealing another control in the same form.
        await paint();
        if (target.evaluate().isEmpty) {
          final verticalScrolls = find.byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                axisDirectionToAxis(widget.axisDirection) == Axis.vertical,
          );
          final sheet = find.byType(BottomSheet);
          final scrolls = sheet.evaluate().isEmpty
              ? verticalScrolls
              : find.descendant(of: sheet, matching: verticalScrolls);
          // A prior action may have left this list at its end. Start searching
          // from the beginning so lazily built controls above it are reachable.
          await tester.drag(scrolls.last, const Offset(0, 10000));
          await paint();
          await tester.scrollUntilVisible(
            target,
            160,
            scrollable: scrolls.last,
            maxScrolls: 50,
          );
        }
        await tester.ensureVisible(target);
        await paint();
        expect(target.hitTestable(), findsOneWidget, reason: name);
        check('$name after scrolling');
      }

      Future<void> tap(Finder target, String name) async {
        await reach(target, name);
        await tester.tap(target);
        await paint();
        check(name);
      }

      try {
        var browsed = 0;
        String? selectedGovernorate;
        String? selectedArea;
        void select(String governorate, String area) {
          selectedGovernorate = governorate;
          selectedArea = area;
        }

        await show(
          GovernorateScreen(
            controller: harness.controller,
            onSelected: select,
            onBrowseAll: () => browsed++,
          ),
        );
        expect(harness.controller.storesLoaded, isTrue);
        await capture('governorate');
        // Verify the final governorate and browse action remain reachable.
        await reach(find.text(governorates.last), 'last governorate');
        await tap(find.text('عرض جميع المخابز'), 'browse all governorates');
        expect(browsed, 1);
        await tap(find.text('غزة'), 'select Gaza governorate');
        expect(find.byType(AreaScreen), findsOneWidget);
        expect(find.text('محافظة غزة'), findsOneWidget);
        await capture('area');
        await reach(find.byType(TextField), 'area search');
        await tester.enterText(find.byType(TextField), 'منطقة غير مسجلة');
        tester.testTextInput.hide();
        await paint();
        expect(find.text('لم نجد المنطقة المطلوبة'), findsOneWidget);
        expect(selectedArea, isNull);
        await tap(find.text('عرض جميع المخابز'), 'browse after empty search');
        expect(browsed, 2);
        await reach(find.byType(TextField), 'refine area search');
        await tester.enterText(find.byType(TextField), 'الرمال');
        tester.testTextInput.hide();
        await paint();
        expect(find.text('الشاطئ'), findsNothing);
        await tap(find.widgetWithText(Card, 'الرمال'), 'select filtered area');
        expect(selectedGovernorate, 'غزة');
        expect(selectedArea, 'الرمال');

        final notifications = FakeNotificationRepository()
          ..items = [
            for (var i = 0; i < 3; i++)
              AppNotification(
                id: 'visual-notification-$i',
                purchaseId: 'visual-purchase-$i',
                kind: i == 0 ? 'booking_confirmed' : 'pickup_ready',
                title: switch (i) {
                  0 => 'تم تأكيد حجزك',
                  1 => 'اقترب موعد استلام الخبز',
                  _ => 'سجل حجزك السابق',
                },
                body:
                    'حجزك لدى مخبز الرمال جاهز للمتابعة. تابع موعد دفعتك هنا.',
                createdAt: DateTime(2026, 10, 27, 8, i * 10),
                readAt: i == 2 ? DateTime(2026, 10, 27, 9) : null,
              ),
          ];
        final openedPurchases = <String>[];
        await show(
          NotificationsScreen(
            repository: notifications,
            onOpenPurchase: openedPurchases.add,
          ),
        );
        // Landscape builds only the first card initially; unread state belongs
        // to the repository, while labels are built as their cards enter view.
        expect(notifications.items.where((item) => !item.isRead), hasLength(2));
        expect(find.text('غير مقروء'), findsWidgets);
        await capture('notifications');
        await tap(find.text('عرض الحجز').first, 'open unread booking');
        expect(openedPurchases, ['visual-purchase-0']);
        expect(notifications.marked, ['visual-notification-0']);
        expect(notifications.items.where((item) => !item.isRead), hasLength(1));
        await reach(
          find.text('اقترب موعد استلام الخبز'),
          'remaining unread notification',
        );
        expect(find.text('غير مقروء'), findsOneWidget);
        await tap(find.text('قراءة الكل'), 'mark remaining notifications read');
        expect(notifications.items.every((item) => item.isRead), isTrue);
        expect(find.text('غير مقروء'), findsNothing);
        expect(
          tester
              .widget<TextButton>(find.widgetWithText(TextButton, 'قراءة الكل'))
              .onPressed,
          isNull,
        );
        await reach(find.text('سجل حجزك السابق'), 'last notification');
        await tap(find.text('عرض الحجز').last, 'open final read booking');
        expect(openedPurchases.last, 'visual-purchase-2');

        await show(const AccountScreen());
        expect(auth.state, isA<Authenticated>());
        expect(find.text(_user.name), findsOneWidget);
        expect(find.text(_user.nationalId), findsOneWidget);
        await capture('account');
        await reach(find.text('تسجيل الخروج'), 'account logout action');
        await tap(find.text('تعديل البيانات'), 'open profile editor');
        await reach(find.byKey(const Key('profile-name')), 'profile name');
        await tester.enterText(
          find.byKey(const Key('profile-name')),
          'أحمد ناصر الجديد',
        );
        await paint();
        expect(tester.testTextInput.isVisible, isTrue);
        final editorScroll = find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                axisDirectionToAxis(widget.axisDirection) == Axis.vertical,
          ),
        );
        final editorPosition = tester
            .state<ScrollableState>(editorScroll)
            .position;
        if (editorPosition.maxScrollExtent > 0) {
          final beforeDrag = editorPosition.pixels;
          await tester.drag(editorScroll, const Offset(0, -120));
          await paint();
          expect(
            editorPosition.pixels,
            greaterThan(beforeDrag),
            reason: 'the active profile editor scrolls while editing',
          );
        }
        await reach(find.byKey(const Key('profile-phone')), 'profile phone');
        await tester.enterText(find.byKey(const Key('profile-phone')), '05');
        tester.testTextInput.hide();
        await tap(find.text('حفظ التغييرات'), 'validate profile edits');
        expect(find.text('أدخل رقم جوال صحيحاً من 10 أرقام'), findsOneWidget);
        // Validation retains the draft while leaving the authenticated user intact.
        expect(find.text('أحمد ناصر الجديد'), findsOneWidget);
        expect((auth.state as Authenticated).user, _user);
        await reach(find.byKey(const Key('profile-phone')), 'correct phone');
        await tester.enterText(
          find.byKey(const Key('profile-phone')),
          '0599444444',
        );
        tester.testTextInput.hide();
        await tap(find.text('حفظ التغييرات'), 'save corrected profile');
        expect(find.byType(TextFormField), findsNothing);
        final updated = (auth.state as Authenticated).user;
        expect(updated.name, 'أحمد ناصر الجديد');
        expect(updated.phone, '0599444444');
        expect(updated.nationalId, _user.nationalId);
        expect(updated.role, _user.role);
        expect(updated.verificationStatus, _user.verificationStatus);
        expect(updated.jawwalPayNumber, _user.jawwalPayNumber);
        expect(find.text(updated.name), findsOneWidget);
        check('profile saved with identity retained');

        final purchase = harness.repo.givenPurchase(
          userId: seededBuyerId,
          storeId: seededStoreId,
          date: todayDateString(),
        );
        final capacity = harness.controller
            .storeById(seededStoreId)!
            .bagsRemaining;
        await show(
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PostponeBookingScreen(
                        controller: harness.controller,
                        purchase: purchase,
                      ),
                    ),
                  ),
                  child: const Text('فتح التأجيل'),
                ),
              ),
            ),
          ),
        );
        await tap(find.text('فتح التأجيل'), 'open postpone confirmation');
        expect(
          find.text('الموعد الحالي: ${purchase.purchaseDate}'),
          findsOneWidget,
        );
        await capture('postpone_booking');
        await reach(find.text('تأكيد التأجيل'), 'postpone confirm action');
        await tap(find.text('الاحتفاظ بموعدي'), 'retain current booking');
        expect(find.byType(PostponeBookingScreen), findsNothing);
        expect(find.text('فتح التأجيل'), findsOneWidget);
        final unchanged = await harness.repo.getPurchaseById(purchase.id);
        expect(unchanged!.purchaseDate, purchase.purchaseDate);
        expect(unchanged.status, purchase.status);
        expect(unchanged.batchNumber, purchase.batchNumber);
        expect(
          harness.controller.storeById(seededStoreId)!.bagsRemaining,
          capacity,
        );
        check('cancel postponement keeps reservation and capacity');
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await paint();
        harness.controller.dispose();
        harness.repo.dispose();
        await tester.pump();
      }
    });
  }
}
