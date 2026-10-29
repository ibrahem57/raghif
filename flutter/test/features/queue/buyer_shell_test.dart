import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raghif/core/theme/app_theme.dart';
import 'package:raghif/domain/models/user_model.dart';
import 'package:raghif/features/auth/bloc/auth_bloc.dart';
import 'package:raghif/features/auth/demo_accounts.dart';
import 'package:raghif/features/navigation/buyer_shell.dart';
import 'package:raghif/features/queue/store_list_screen.dart';
import '../../support/fake_auth_repository.dart';
import '../../support/fake_notification_repository.dart';
import '../../support/queue_test_harness.dart';

void main() {
  testWidgets(
    'home geographic selection filters existing list; tabs retain auth',
    (tester) async {
      final harness = buildQueueHarness();
      final bloc = AuthBloc(
        authRepository: FakeAuthRepository(
          users: const [
            UserModel(
              id: seededBuyerId,
              name: 'أحمد ناصر',
              phone: '0599111111',
              nationalId: '900111222',
              verificationStatus: VerificationStatus.verified,
            ),
          ],
          sessionUserId: seededBuyerId,
        ),
      );
      addTearDown(bloc.close);
      bloc.add(const CheckAuthSessionEvent());
      await tester.pumpWidget(
        BlocProvider.value(
          value: bloc,
          child: MaterialApp(
            theme: AppTheme.light,
            builder: (_, child) =>
                Directionality(textDirection: TextDirection.rtl, child: child!),
            home: BuyerShell(
              controller: harness.controller,
              currentUser: const DemoUser(
                id: seededBuyerId,
                name: 'أحمد ناصر',
                phone: '0599111111',
                pin: '',
                role: UserRole.buyer,
              ),
              notifications: FakeNotificationRepository(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('اختار المحافظة'), findsOneWidget);
      await tester.tap(find.text('غزة'));
      await tester.pumpAndSettle();
      expect(find.text('اختار المنطقة'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'الرمال');
      await tester.pumpAndSettle();
      expect(find.text('الشاطئ'), findsNothing);
      await tester.tap(find.widgetWithText(Card, 'الرمال'));
      await tester.pumpAndSettle();
      expect(find.byType(StoreListScreen), findsOneWidget);
      expect(find.text('مخبز الرمال'), findsOneWidget);
      expect(find.text('مخبز الشاطئ'), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('حجزي'));
      await tester.pumpAndSettle();
      expect(find.text('لا يوجد طلب اليوم'), findsOneWidget);
      await tester.tap(find.text('حسابي').last);
      await tester.pumpAndSettle();
      expect(find.text('900111222'), findsOneWidget);
      expect(bloc.state, isA<Authenticated>());
      await tester.pumpWidget(const SizedBox.shrink());
      harness.controller.dispose();
      harness.repo.dispose();
    },
  );
}
