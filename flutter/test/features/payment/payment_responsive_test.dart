import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raghif/core/i18n/strings.dart';
import 'package:raghif/core/theme/app_theme.dart';
import 'package:raghif/features/payment/mock_jawwal_pay_service.dart';
import 'package:raghif/features/payment/payment_number_screen.dart';
import 'package:raghif/features/payment/payment_otp_screen.dart';
import 'package:raghif/features/payment/payment_success_screen.dart';

void main() {
  for (final size in [const Size(320, 640), const Size(640, 320)]) {
    testWidgets('payment actions remain reachable at $size with large text', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Widget wrap(Widget screen) => MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.5),
            viewInsets: const EdgeInsets.only(bottom: 120),
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: child!,
          ),
        ),
        home: screen,
      );

      await tester.pumpWidget(
        wrap(const PaymentNumberScreen(initialNumber: '')),
      );
      await tester.ensureVisible(find.text(Strings.proceedToOtp));
      await tester.tap(find.text(Strings.proceedToOtp));
      await tester.pumpAndSettle();
      expect(find.text(Strings.registerError), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        wrap(
          PaymentOtpScreen(
            service: MockJawwalPayService(initialCode: '7391'),
            phoneNumber: '0599111111',
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), '0000');
      await tester.ensureVisible(find.text(Strings.confirmPaymentButton));
      await tester.tap(find.text(Strings.confirmPaymentButton));
      await tester.pumpAndSettle();
      expect(find.text(Strings.wrongOtpError), findsOneWidget);
      await tester.ensureVisible(find.text(Strings.resendCodeButton));
      await tester.tap(find.text(Strings.resendCodeButton));
      await tester.pumpAndSettle();
      expect(find.text(Strings.wrongOtpError), findsNothing);
      expect(find.text(Strings.demoOtpNotification('7391')), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(wrap(const PaymentSuccessScreen()));
      await tester.ensureVisible(find.text(Strings.completeReservationButton));
      expect(
        tester
            .getSize(
              find.widgetWithText(
                ElevatedButton,
                Strings.completeReservationButton,
              ),
            )
            .height,
        greaterThanOrEqualTo(48),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
