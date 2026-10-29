import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:raghif/core/i18n/strings.dart';
import 'package:raghif/core/theme/app_theme.dart';
import 'package:raghif/domain/models/store_list_entry.dart';
import 'package:raghif/features/auth/bloc/auth_bloc.dart';
import 'package:raghif/features/auth/demo_accounts.dart';
import 'package:raghif/features/auth/login_screen.dart';
import 'package:raghif/features/auth/registration_screen.dart';
import 'package:raghif/features/onboarding/onboarding_screen.dart';
import 'package:raghif/features/queue/buyer_home_screen.dart';
import 'package:raghif/features/queue/confirmation_screen.dart';
import 'package:raghif/features/queue/owner_dashboard_screen.dart';
import 'package:raghif/features/queue/queue_logic.dart';
import 'package:raghif/features/queue/receipt_card.dart';
import 'package:raghif/features/queue/store_details_screen.dart';
import 'package:raghif/features/queue/store_list_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../goldens/test_fonts.dart';
import '../support/fake_auth_repository.dart';
import '../support/queue_test_harness.dart';

const _buyer = DemoUser(
  id: seededBuyerId,
  phone: '0599111111',
  pin: '1234',
  role: UserRole.buyer,
  name: 'أحمد ناصر',
  jawwalPayNumber: '0599111111',
);

/// Optional local inspection artifacts from production widgets and fake data.
/// These are widget-test fixtures, not screenshots of a connected device.
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
    testWidgets('Stitch production screens: ${viewport.name}', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = viewport.size;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      await loadAppFonts(tester);

      final auth = AuthBloc(authRepository: FakeAuthRepository());
      addTearDown(auth.close);
      final harness = buildQueueHarness();
      final boundaryKey = GlobalKey();

      Future<void> show(Widget screen) async {
        // Unmount each production screen before showing the next so its
        // controllers, stream subscriptions and focus are disposed normally.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: BlocProvider<AuthBloc>.value(
              value: auth,
              child: MaterialApp(
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
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          await precacheImage(
            const AssetImage('assets/images/stitch_bread.png'),
            boundaryKey.currentContext!,
          );
        });
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: '${screen.runtimeType} at ${viewport.name}',
        );
      }

      Future<void> inspect(String name) async {
        expect(tester.takeException(), isNull, reason: name);
        if (viewport.name == 'phone') {
          await _capture(tester, boundaryKey, name);
        }
        // Also paint the lower content of long forms/cards at this viewport.
        final verticalScrolls = find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              axisDirectionToAxis(widget.axisDirection) == Axis.vertical,
        );
        if (verticalScrolls.evaluate().isNotEmpty) {
          await tester.drag(verticalScrolls.first, const Offset(0, -700));
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '$name after scrolling',
          );
        }
      }

      try {
        var onboardingCompletions = 0;
        await show(OnboardingScreen(onDone: () => onboardingCompletions++));
        final titles = [
          Strings.onboardingTitle1,
          Strings.onboardingTitle2,
          Strings.onboardingTitle3,
        ];
        for (var page = 0; page < 3; page++) {
          if (page > 0) {
            final dot = find.byKey(ValueKey('onboarding-dot-$page'));
            await tester.ensureVisible(dot);
            await tester.tap(dot);
            await tester.pumpAndSettle();
          }
          expect(find.text(titles[page]), findsOneWidget);
          expect(
            find.text(Strings.onboardingPageOf(page + 1, 3)),
            findsOneWidget,
          );
          expect(
            tester.takeException(),
            isNull,
            reason: 'onboarding page ${page + 1}',
          );
          if (viewport.name == 'phone') {
            await _capture(tester, boundaryKey, 'onboarding_${page + 1}');
          }
        }
        expect(find.text(Strings.onboardingGetStarted), findsOneWidget);
        expect(find.text(Strings.onboardingHaveAccount), findsOneWidget);
        expect(onboardingCompletions, 0);
        // Viewing/swiping the introduction must not mark it completed.
        final preferences = await SharedPreferences.getInstance();
        expect(preferences.getKeys(), isEmpty);

        await show(const LoginScreen());
        expect(find.text(Strings.personalIdLabel), findsOneWidget);
        expect(find.text(Strings.continueButton), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
        await inspect('login');

        await show(const RegistrationScreen());
        for (final label in [
          Strings.nameLabel,
          Strings.phoneLabel,
          Strings.personalIdLabel,
          Strings.pinLabel,
          Strings.confirmPinLabel,
          Strings.jawwalPayNumberLabel,
        ]) {
          expect(find.text(label), findsOneWidget);
        }
        expect(find.byType(TextFormField), findsNWidgets(6));
        expect(find.text(Strings.registerButton), findsOneWidget);
        await inspect('registration');

        await show(
          StoreListScreen(controller: harness.controller, currentUser: _buyer),
        );
        expect(find.text('مخبز الرمال'), findsWidgets);
        expect(find.byType(TextField), findsOneWidget);
        await inspect('store_list');

        final store = harness.controller.storeById(seededStoreId)!;
        await show(
          StoreDetailsScreen(
            controller: harness.controller,
            currentUser: _buyer,
            entry: StoreListEntry(store: store),
          ),
        );
        await tester.scrollUntilVisible(find.text(store.name), 150);
        await tester.pumpAndSettle();
        expect(find.text(store.name), findsWidgets);
        expect(find.text(Strings.reserveBagButton), findsOneWidget);
        await inspect('store_details');

        // This reserve call reaches only FakeQueueRepository, never Supabase.
        final purchase = await harness.controller.buy(
          storeId: seededStoreId,
          date: todayDateString(),
        );
        await show(
          BuyerHomeScreen(controller: harness.controller, currentUser: _buyer),
        );
        expect(find.text(store.name), findsWidgets);
        expect(find.text(Strings.statusWaiting), findsWidgets);
        await tester.scrollUntilVisible(
          find.text(Strings.showReceiptButton),
          150,
        );
        await tester.pumpAndSettle();
        expect(find.text(Strings.showReceiptButton), findsOneWidget);
        await inspect('buyer_current_order');

        await show(
          ConfirmationScreen(
            controller: harness.controller,
            purchaseId: purchase.id,
            currentUser: _buyer,
          ),
        );
        expect(find.byType(QrImageView), findsOneWidget);
        final receipt = tester.widget<ReceiptCard>(find.byType(ReceiptCard));
        final payload = jsonDecode(receipt.qrData) as Map<String, dynamic>;
        expect(payload['purchase_id'], purchase.id);
        expect(payload['store_id'], seededStoreId);
        await inspect('confirmation_qr');

        harness.repo.currentUserId = seededOwnerId;
        await show(
          OwnerDashboardScreen(
            controller: harness.controller,
            storeId: seededStoreId,
          ),
        );
        expect(find.text(store.name), findsWidgets);
        await tester.scrollUntilVisible(find.byType(Switch), 150);
        await tester.pumpAndSettle();
        expect(find.byType(Switch), findsOneWidget);
        expect(find.text(Strings.saveTodaySettings), findsNothing);
        expect(find.text(Strings.goToQueue), findsOneWidget);
        await inspect('owner_dashboard');
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        harness.controller.dispose();
        harness.repo.dispose();
        await tester.pump();
      }
    });
  }
}
