import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:raghif/core/i18n/strings.dart';
import 'package:raghif/core/theme/app_theme.dart';
import 'package:raghif/domain/models/user_model.dart';
import 'package:raghif/features/auth/bloc/auth_bloc.dart';
import 'package:raghif/features/auth/demo_accounts.dart';
import 'package:raghif/features/queue/owner_customers_screen.dart';
import 'package:raghif/features/queue/owner_dashboard_screen.dart';
import 'package:raghif/features/queue/queue_controller.dart';

import '../../support/fake_queue_repository.dart';
import '../../support/queue_test_harness.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

Widget wrapWithMaterial(Widget child) {
  return MaterialApp(
    home: Directionality(textDirection: TextDirection.rtl, child: child),
  );
}

class _TestEnv {
  _TestEnv(this.repo, this.controller);

  final FakeQueueRepository repo;
  final QueueController controller;
}

/// Builds a fresh in-memory backend double + controller. Must be called
/// from *inside* a testWidgets body, not from setUp(): setUp() runs outside
/// testWidgets' own FakeAsync zone, and streams created there don't
/// reliably deliver inside the test body.
Future<_TestEnv> _buildTestEnv({String actingAs = seededOwnerId}) async {
  final harness = buildQueueHarness(actingAs: actingAs);
  final repo = harness.repo;
  final controller = harness.controller;
  return _TestEnv(repo, controller);
}

void main() {
  for (final size in [const Size(320, 640), const Size(640, 320)]) {
    testWidgets('customer metadata scrolls at $size with large text', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final env = await _buildTestEnv();
      env.repo.addUser(
        'long-name',
        name: 'أحمد محمد محمود عبد الرحمن النجار',
        phone: '0599999999',
        nationalId: '900999999',
      );
      env.repo.givenPurchase(
        userId: 'long-name',
        storeId: seededStoreId,
        date: '2026-09-02',
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(1.5)),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: child!,
            ),
          ),
          home: OwnerCustomersScreen(
            controller: env.controller,
            storeId: seededStoreId,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(Strings.totalPurchasesCount(1)),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(Strings.lastPurchaseDate('2026-09-02')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      env.controller.dispose();
      env.repo.dispose();
    });
  }

  group('OwnerCustomersScreen', () {
    testWidgets('displays empty state when no purchases exist', (tester) async {
      final env = await _buildTestEnv();

      await tester.pumpWidget(
        wrapWithMaterial(
          OwnerCustomersScreen(
            controller: env.controller,
            storeId: seededStoreId,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(Strings.customersTitle), findsOneWidget);
      expect(find.text(Strings.customersEmpty), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });

    testWidgets('displays customer info when purchases exist', (tester) async {
      final env = await _buildTestEnv();

      env.repo.addUser(
        'user-khaled',
        name: 'خالد محمود',
        phone: '0599888777',
        nationalId: '988877766',
      );
      env.repo.givenPurchase(
        userId: 'user-khaled',
        storeId: seededStoreId,
        date: '2026-09-02',
      );

      await tester.pumpWidget(
        wrapWithMaterial(
          OwnerCustomersScreen(
            controller: env.controller,
            storeId: seededStoreId,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(Strings.customersTitle), findsOneWidget);
      expect(find.text('خالد محمود'), findsOneWidget);
      expect(find.text('0599888777'), findsOneWidget);
      expect(find.text(Strings.totalPurchasesCount(1)), findsOneWidget);
      expect(find.text(Strings.lastPurchaseDate('2026-09-02')), findsOneWidget);
      expect(find.text(Strings.customersEmpty), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });

    testWidgets('OwnerDashboardScreen navigates to OwnerCustomersScreen', (
      tester,
    ) async {
      final env = await _buildTestEnv();
      final mockAuthBloc = MockAuthBloc();
      when(() => mockAuthBloc.state).thenReturn(
        const Authenticated(
          UserModel(
            id: seededOwnerId,
            phone: demoOwnerPhone,
            nationalId: demoOwnerNationalId,
            name: demoOwnerName,
            role: UserRole.owner,
            verificationStatus: VerificationStatus.verified,
          ),
        ),
      );

      await tester.pumpWidget(
        BlocProvider<AuthBloc>.value(
          value: mockAuthBloc,
          child: wrapWithMaterial(
            OwnerDashboardScreen(
              controller: env.controller,
              storeId: seededStoreId,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(Strings.customersButton), findsOneWidget);

      await tester.ensureVisible(find.text(Strings.customersButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Strings.customersButton));
      await tester.pumpAndSettle();

      expect(find.byType(OwnerCustomersScreen), findsOneWidget);
      expect(find.text(Strings.customersTitle), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  });
}
