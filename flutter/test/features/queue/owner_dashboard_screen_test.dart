import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:raghif/core/i18n/strings.dart';
import 'package:raghif/core/theme/app_theme.dart';
import 'package:raghif/domain/models/user_model.dart';
import 'package:raghif/features/auth/bloc/auth_bloc.dart';
import 'package:raghif/features/queue/owner_dashboard_screen.dart';
import 'package:raghif/features/queue/queue_controller.dart';
import 'package:raghif/features/queue/queue_logic.dart';

import '../../support/fake_queue_repository.dart';
import '../../support/queue_test_harness.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

/// The owner's dashboard on top of the in-memory backend double.
///
/// Replaces the old `AppDatabase(NativeDatabase.memory()) +
/// QueueRepositoryImpl + ensureSeeded()` preamble: nothing seeds on-device any
/// more, so a test starts from a world the *server* could hand back. The
/// repository comes back too — states the owner UI cannot produce itself (a
/// low-but-nonzero stock level, an inverted window) have to be set there, the
/// way Postgres would be holding them.
///
/// Built from *inside* a testWidgets body: the fake emits on `onListen`, and a
/// controller built in `setUp()` can miss the first emission before the widget
/// subscribes.
({QueueController controller, FakeQueueRepository repository}) _buildTestEnv() {
  final harness = buildQueueHarness(actingAs: seededOwnerId);
  return (controller: harness.controller, repository: harness.repo);
}

void main() {
  late MockAuthBloc mockAuthBloc;

  setUp(() {
    mockAuthBloc = MockAuthBloc();
    when(() => mockAuthBloc.state).thenReturn(
      const Authenticated(
        UserModel(
          id: seededOwnerId,
          phone: '0599000002',
          nationalId: '900333444',
          name: 'صاحب المخبز',
          role: UserRole.owner,
          verificationStatus: VerificationStatus.verified,
        ),
      ),
    );
  });

  Future<QueueController> pumpDashboard(
    WidgetTester tester,
    String storeId, {
    ({QueueController controller, FakeQueueRepository repository})? env,
    TextScaler textScaler = TextScaler.noScaling,
  }) async {
    final resolved = env ?? _buildTestEnv();
    await tester.pumpWidget(
      BlocProvider<AuthBloc>.value(
        value: mockAuthBloc,
        child: MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: child!,
          ),
          home: OwnerDashboardScreen(
            controller: resolved.controller,
            storeId: storeId,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return resolved.controller;
  }

  testWidgets(
    "shows the store's existing purchase window on the picker buttons",
    (tester) async {
      // مخبز الرمال — seeded 08:00-10:00.
      await pumpDashboard(tester, seededStoreId);

      expect(find.text(Strings.openTimeLabel), findsOneWidget);
      expect(find.text(Strings.closeTimeLabel), findsOneWidget);
      expect(find.text('08:00'), findsOneWidget);
      expect(find.text('10:00'), findsOneWidget);
    },
  );

  testWidgets('settings remain reachable on a narrow screen with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpDashboard(
      tester,
      seededStoreId,
      textScaler: TextScaler.linear(1.5),
    );

    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(Strings.saveTodaySettings));
    await tester.pumpAndSettle();
    expect(find.text(Strings.unsavedSettingsNote), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'shows "not set" on the picker buttons when the store has no window yet',
    (tester) async {
      // مخبز النصيرات — closed, and no window set.
      await pumpDashboard(tester, seededClosedStoreId);

      expect(find.text(Strings.openTimeLabel), findsOneWidget);
      expect(find.text(Strings.closeTimeLabel), findsOneWidget);
      expect(find.text(Strings.notSetLabel), findsNWidgets(2));
    },
  );

  testWidgets('saving the day\u2019s settings keeps the purchase window', (
    tester,
  ) async {
    final controller = await pumpDashboard(tester, seededStoreId);

    // No edits yet, so there is nothing to save and the card says so.
    expect(find.text(Strings.saveTodaySettings), findsNothing);
    expect(find.text(Strings.savedSettingsNote), findsOneWidget);

    // The settings card sits below the fold on a short screen, so scroll to
    // the stepper before tapping it — a missed tap silently no-ops.
    await tester.ensureVisible(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text(Strings.unsavedSettingsNote), findsOneWidget);

    await tester.ensureVisible(find.text(Strings.saveTodaySettings));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Strings.saveTodaySettings));
    await tester.pumpAndSettle();

    final store = controller.storeById(seededStoreId);
    expect(store?.openTime, '08:00');
    expect(store?.closeTime, '10:00');
    // One tap on + moves the allocation by 10, not 1 (300 -> 310).
    expect(store?.dailyBagLimit, 310);
    // The save belongs to the server: remaining comes back recomputed from the
    // allocation (limit minus today's sales), not shifted by a local delta.
    expect(store?.bagsRemaining, 310);
    // Saved again: the action is gone and the card confirms the state.
    expect(find.text(Strings.saveTodaySettings), findsNothing);
    expect(find.text(Strings.savedSettingsNote), findsOneWidget);
  });

  testWidgets('shows the live paid-but-not-picked count', (tester) async {
    await pumpDashboard(tester, seededStoreId);

    expect(find.text(Strings.pendingPickupLabel), findsOneWidget);
    // Nothing sold yet in a fresh store.
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('reports a sold-out store and the fix, not a low-stock nag', (
    tester,
  ) async {
    final env = _buildTestEnv();
    // One bag sold today, then today's allocation cut to just that one:
    // remaining lands on 0, the state the owner has to act on mid-crowd.
    await env.repository.reserveBag(
      storeId: seededStoreId,
      date: todayDateString(),
    );
    await env.repository.saveStoreAllocation(
      seededStoreId,
      dailyLimit: 1,
      batchSize: 20,
      date: todayDateString(),
    );
    final controller = await pumpDashboard(tester, seededStoreId, env: env);

    expect(controller.storeById(seededStoreId)!.bagsRemaining, 0);
    expect(find.text(Strings.outOfStockNotice), findsOneWidget);
    // Sold out replaces the low-stock warning rather than stacking with it.
    expect(find.text(Strings.lowStockWarning(0)), findsNothing);
  });

  testWidgets('warns in-app when the store is low but not sold out', (
    tester,
  ) async {
    final env = _buildTestEnv();
    // Sell 30 of the seeded 45 bags straight through the repository: no owner
    // UI path produces a low-but-nonzero level on a fresh store. One bag per
    // national ID per day is enforced, so each purchase needs its own date —
    // the bags-remaining counter is per store, not per day.
    final today = DateTime.now();
    for (var i = 0; i < 30; i++) {
      await env.repository.reserveBag(
        storeId: seededStoreId,
        date: todayDateString(today.subtract(Duration(days: i + 1))),
      );
    }
    final controller = await pumpDashboard(tester, seededStoreId, env: env);

    expect(controller.storeById(seededStoreId)!.bagsRemaining, 15);
    expect(find.text(Strings.lowStockWarning(15)), findsOneWidget);
    expect(find.text(Strings.outOfStockNotice), findsNothing);
  });

  testWidgets('the open/close gate writes through to the store', (
    tester,
  ) async {
    final controller = await pumpDashboard(tester, seededStoreId);
    expect(controller.storeById(seededStoreId)!.isOpen, isTrue);

    await tester.ensureVisible(find.text(Strings.storeOpenSwitchLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Strings.storeOpenSwitchLabel));
    await tester.pumpAndSettle();
    // Closing stops every buyer, so it asks first.
    await tester.tap(find.text(Strings.closeStoreConfirmAction));
    await tester.pumpAndSettle();

    expect(controller.storeById(seededStoreId)!.isOpen, isFalse);
    expect(find.text(Strings.storeOpenOffHelper), findsOneWidget);
    // The same flag buyers read, so this is what actually stops selling.
    expect(controller.storeById(seededStoreId)!.canPurchase, isFalse);
  });

  testWidgets('cancelling the close-bakery confirmation leaves it open', (
    tester,
  ) async {
    final controller = await pumpDashboard(tester, seededStoreId);

    await tester.ensureVisible(find.text(Strings.storeOpenSwitchLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Strings.storeOpenSwitchLabel));
    await tester.pumpAndSettle();
    expect(find.text(Strings.closeStoreConfirmTitle), findsOneWidget);
    await tester.tap(find.text(Strings.cancelLabel));
    await tester.pumpAndSettle();

    expect(controller.storeById(seededStoreId)!.isOpen, isTrue);
  });

  testWidgets(
    'refuses to publish a purchase window that ends before it starts',
    (tester) async {
      final env = _buildTestEnv();
      // Seed the impossible range through the repository: the screen loads its
      // edit fields once, so this is the state the owner opens into.
      await env.repository.saveStoreAllocation(
        seededStoreId,
        dailyLimit: 300,
        batchSize: 20,
        date: todayDateString(),
        openTime: '09:00',
        closeTime: '07:00',
      );
      await pumpDashboard(tester, seededStoreId, env: env);

      expect(find.text(Strings.windowOrderError), findsOneWidget);

      // An edit makes the save action appear, but it stays inert while the
      // window is inverted — buyers would otherwise see 09:00 - 07:00.
      await tester.ensureVisible(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      final saveButton = tester.widget<OutlinedButton>(
        find.ancestor(
          of: find.text(Strings.saveTodaySettings),
          matching: find.byType(OutlinedButton),
        ),
      );
      expect(saveButton.onPressed, isNull);

      await tester.ensureVisible(find.text(Strings.saveTodaySettings));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Strings.saveTodaySettings));
      await tester.pumpAndSettle();
      expect(env.controller.storeById(seededStoreId)!.dailyBagLimit, 300);
    },
  );
}
