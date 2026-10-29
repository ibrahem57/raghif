import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raghif/core/i18n/strings.dart';
import 'package:raghif/features/auth/demo_accounts.dart';
import 'package:raghif/features/payment/mock_jawwal_pay_service.dart';
import 'package:raghif/features/payment/payment_number_screen.dart';
import 'package:raghif/features/queue/confirmation_screen.dart';
import 'package:raghif/features/queue/purchase_screen.dart';
import 'package:raghif/features/queue/queue_logic.dart';

import '../../support/queue_test_harness.dart';

Widget wrapWithMaterial(Widget child) {
  return MaterialApp(
    home: Directionality(textDirection: TextDirection.rtl, child: child),
  );
}

void main() {
  group('Payment screen sequence', () {
    testWidgets(
      'number-confirm -> OTP screen shows code -> wrong entry shows error and stays put -> correct entry navigates to success',
      (tester) async {
        final service = MockJawwalPayService(initialCode: '7391');

        await tester.pumpWidget(
          wrapWithMaterial(
            PaymentNumberScreen(initialNumber: '0599111111', service: service),
          ),
        );

        // 1. Verify number-confirm screen renders
        expect(find.text(Strings.paymentTitle), findsOneWidget);
        expect(find.text('0599111111'), findsOneWidget);
        expect(find.text(Strings.proceedToOtp), findsOneWidget);

        // 2. Tap proceed to OTP
        await tester.ensureVisible(find.text(Strings.proceedToOtp));
        await tester.tap(find.text(Strings.proceedToOtp));
        await tester.pumpAndSettle();

        // 3. OTP screen shows the code on-screen
        expect(find.text(Strings.paymentOtpTitle), findsOneWidget);
        expect(find.text(Strings.demoOtpNotification('7391')), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);

        // 4. Enter wrong code and tap confirm payment
        await tester.enterText(find.byType(TextField), '0000');
        await tester.ensureVisible(find.text(Strings.confirmPaymentButton));
        await tester.tap(find.text(Strings.confirmPaymentButton));
        await tester.pumpAndSettle();

        // Verify wrong entry shows an error and stays on OTP screen
        expect(find.text(Strings.wrongOtpError), findsOneWidget);
        expect(find.text(Strings.paymentOtpTitle), findsOneWidget);
        expect(find.text(Strings.paymentSuccessTitle), findsNothing);

        // 5. Tap resend code — verifies same code is retained and error is cleared
        await tester.ensureVisible(find.text(Strings.resendCodeButton));
        await tester.tap(find.text(Strings.resendCodeButton));
        await tester.pumpAndSettle();
        expect(find.text(Strings.demoOtpNotification('7391')), findsOneWidget);
        expect(find.text(Strings.wrongOtpError), findsNothing);

        // 6. Enter correct code and tap confirm payment
        await tester.enterText(find.byType(TextField), '7391');
        await tester.ensureVisible(find.text(Strings.confirmPaymentButton));
        await tester.tap(find.text(Strings.confirmPaymentButton));
        await tester.pumpAndSettle();

        // 7. Verify navigation to success screen
        expect(
          find.text(Strings.paymentSuccessTitle),
          findsNWidgets(2),
        ); // AppBar + body
        expect(find.text(Strings.completeReservationButton), findsOneWidget);
      },
    );

    testWidgets('Number screen validation rejects empty phone number', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithMaterial(const PaymentNumberScreen(initialNumber: '')),
      );

      await tester.ensureVisible(find.text(Strings.proceedToOtp));

      await tester.tap(find.text(Strings.proceedToOtp));
      await tester.pumpAndSettle();

      expect(find.text(Strings.registerError), findsOneWidget);
      expect(find.text(Strings.paymentOtpTitle), findsNothing);
    });
  });

  group('PurchaseScreen Jawwal Pay integration', () {
    const testUser = DemoUser(
      id: seededBuyerId,
      phone: '0599111111',
      pin: '1234',
      role: UserRole.buyer,
      name: 'أحمد ناصر',
      jawwalPayNumber: '0599111111',
    );

    testWidgets(
      'tapping buy pushes payment flow; completing payment creates reservation',
      (tester) async {
        // Built inside the test body, not setUp() — setUp() runs outside
        // testWidgets' own FakeAsync zone, and a database built there can't
        // reliably deliver .watch() stream data inside the test body.
        // Not explicitly closed: this database is fresh and short-lived,
        // and unmounting the widget below already cancels its .watch()
        // subscriptions cleanly — an extra explicit controller
        // .dispose()/db.close() afterward re-touches an already-settled
        // stream and reliably hangs.
        final harness = buildQueueHarness();
        final repo = harness.repo;
        final controller = harness.controller;
        final store = (await repo.getStoreById(seededStoreId))!;

        await tester.pumpWidget(
          wrapWithMaterial(
            PurchaseScreen(
              controller: controller,
              storeId: store.id,
              currentUser: testUser,
            ),
          ),
        );

        // Verify on PurchaseScreen
        expect(find.text(Strings.purchaseTitle), findsOneWidget);
        expect(find.text(Strings.payButton), findsOneWidget);

        // Tap "ادفع 3 شيكل"
        await tester.ensureVisible(find.text(Strings.payButton));
        await tester.tap(find.text(Strings.payButton));
        await tester.pumpAndSettle();

        // Pushed number confirm screen
        expect(find.text(Strings.paymentTitle), findsOneWidget);
        expect(find.text(Strings.proceedToOtp), findsOneWidget);

        // Tap proceed to OTP
        await tester.ensureVisible(find.text(Strings.proceedToOtp));
        await tester.tap(find.text(Strings.proceedToOtp));
        await tester.pumpAndSettle();

        expect(find.text(Strings.paymentOtpTitle), findsOneWidget);

        // Find the generated OTP from the notification banner text
        final bannerFinder = find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              (widget.data?.contains('رمز التحقق (رسالة تجريبية): ') ?? false),
        );
        expect(bannerFinder, findsOneWidget);
        final bannerText = (tester.widget(bannerFinder) as Text).data!;
        final otp = bannerText.split(': ').last.trim();

        // Enter OTP and confirm
        await tester.enterText(find.byType(TextField), otp);
        await tester.ensureVisible(find.text(Strings.confirmPaymentButton));
        await tester.tap(find.text(Strings.confirmPaymentButton));
        await tester.pumpAndSettle();

        // Landed on PaymentSuccessScreen
        expect(find.text(Strings.completeReservationButton), findsOneWidget);

        // Tap complete reservation
        await tester.ensureVisible(
          find.text(Strings.completeReservationButton),
        );
        await tester.tap(find.text(Strings.completeReservationButton));
        // Pump to trigger pop cascade and the _pay() delayed future
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pumpAndSettle();

        // Verify that the reservation was created and we are now on ConfirmationScreen
        expect(find.byType(ConfirmationScreen), findsOneWidget);
        expect(find.text(Strings.confirmationTitle), findsOneWidget);

        // Verify reservation exists in QueueController
        final blocker = await controller.blockingPurchaseFor(
          testUser.id,
          todayDateString(),
        );
        expect(blocker, isNotNull);

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );

    testWidgets('canceling payment flow does not create reservation', (
      tester,
    ) async {
      final harness = buildQueueHarness();
      final repo = harness.repo;
      final controller = harness.controller;
      final store = (await repo.getStoreById(seededStoreId))!;

      await tester.pumpWidget(
        wrapWithMaterial(
          PurchaseScreen(
            controller: controller,
            storeId: store.id,
            currentUser: testUser,
          ),
        ),
      );

      // Tap "ادفع 3 شيكل"
      await tester.ensureVisible(find.text(Strings.payButton));
      await tester.tap(find.text(Strings.payButton));
      await tester.pumpAndSettle();

      // On number screen, tap back
      await tester.ensureVisible(find.text(Strings.back));
      await tester.tap(find.text(Strings.back));
      await tester.pumpAndSettle();

      // Back on PurchaseScreen
      expect(find.text(Strings.purchaseTitle), findsOneWidget);

      // Verify NO purchase was made
      final blocker = await controller.blockingPurchaseFor(
        testUser.id,
        todayDateString(),
      );
      expect(blocker, isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  });
}
