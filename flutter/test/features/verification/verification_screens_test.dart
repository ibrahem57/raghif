import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raghif/core/i18n/strings.dart';
import 'package:raghif/core/theme/app_theme.dart';
import 'package:raghif/features/verification/photo_capture_screen.dart';
import 'package:raghif/features/verification/waiting_for_verification_screen.dart';

void main() {
  for (final size in [const Size(320, 640), const Size(640, 320)]) {
    for (final kind in PhotoCaptureKind.values) {
      testWidgets('$kind stays scrollable at $size with large text', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          _app(
            PhotoCaptureScreen(
              kind: kind,
              onContinue: () => fail('Continue must require a captured photo'),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.text(Strings.capturePrompt), findsOneWidget);
        final continueButton = find.widgetWithText(
          ElevatedButton,
          Strings.continueLabel,
        );
        await tester.ensureVisible(continueButton);
        expect(tester.widget<ElevatedButton>(continueButton).onPressed, isNull);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('verification timer reveals reachable continue at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_app(const WaitingForVerificationScreen()));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(Strings.continueToApp), findsNothing);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text(Strings.continueToApp), findsNothing);
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      final continueButton = find.widgetWithText(
        ElevatedButton,
        Strings.continueToApp,
      );
      await tester.ensureVisible(continueButton);
      expect(
        tester.widget<ElevatedButton>(continueButton).onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    });
  }
}

Widget _app(Widget home) => MaterialApp(
  theme: AppTheme.light,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: const TextScaler.linear(1.5)),
    child: Directionality(textDirection: TextDirection.rtl, child: child!),
  ),
  home: home,
);
