import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raghif/core/i18n/strings.dart';
import 'package:raghif/core/theme/app_theme.dart';
import 'package:raghif/domain/models/purchase_model.dart';
import 'package:raghif/features/queue/owner_queue_screen.dart';
import 'package:raghif/features/queue/queue_logic.dart';

import '../../support/queue_test_harness.dart';

Widget wrapWithMaterial(Widget child) {
  return MaterialApp(
    home: Directionality(textDirection: TextDirection.rtl, child: child),
  );
}

void main() {
  for (final size in [const Size(320, 640), const Size(640, 320)]) {
    testWidgets('queue actions remain reachable at $size with large text', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final harness = buildQueueHarness(actingAs: seededOwnerId);
      final repo = harness.repo;
      repo.addUser(
        'long-name',
        name: 'أحمد محمد محمود عبد الرحمن النجار',
        phone: '0599999999',
        nationalId: '900999999',
      );
      final received = repo.givenPurchase(
        userId: 'long-name',
        storeId: seededStoreId,
        date: todayDateString(),
        status: PurchaseStatus.notified,
      );
      repo.givenPurchase(
        userId: seededBuyerId,
        storeId: seededStoreId,
        date: todayDateString(),
        batchNumber: 2,
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
          home: OwnerQueueScreen(
            controller: harness.controller,
            storeId: seededStoreId,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text(Strings.markReceived),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text(Strings.markReceived).hitTestable(), findsOneWidget);
      await tester.tap(find.text(Strings.markReceived));
      await tester.pumpAndSettle();
      expect(
        (await repo.getPurchaseById(received.id))!.status,
        PurchaseStatus.collected,
      );
      await tester.scrollUntilVisible(
        find.text(Strings.undoReceived),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(Strings.undoReceived));
      await tester.pumpAndSettle();
      // collect_purchase is idempotent; the existing legacy undo-labelled
      // action still calls collectPurchase and cannot reverse server pickup.
      expect(
        (await repo.getPurchaseById(received.id))!.status,
        PurchaseStatus.collected,
      );
      await tester.scrollUntilVisible(
        find.text(Strings.notifyNextBatch(2)),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(Strings.notifyNextBatch(2)));
      await tester.pumpAndSettle();
      expect(find.text(Strings.notifyConfirmTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(Strings.cancelLabel));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      harness.controller.dispose();
      repo.dispose();
    });
  }

  group('OwnerQueueScreen pickup helpers', () {
    testWidgets('shows national ID + phone on buyer rows and filters by ID '
        'suffix while hiding the notify button during a search', (
      tester,
    ) async {
      final harness = buildQueueHarness();
      final repo = harness.repo;
      final controller = harness.controller;

      final store = (await repo.getStoreById(seededStoreId))!;
      const buyer = (
        id: seededBuyerId,
        nationalId: '900111222',
        phone: '0599111111',
      );
      final date = todayDateString();
      final purchase = await controller.buy(storeId: store.id, date: date);
      expect(purchase.userNationalId, buyer.nationalId);

      await tester.pumpWidget(
        wrapWithMaterial(
          OwnerQueueScreen(controller: controller, storeId: store.id),
        ),
      );
      await tester.pumpAndSettle();

      // Row carries the buyer's national ID so pickup identity can be verified.
      expect(find.textContaining(buyer.nationalId), findsOneWidget);
      expect(find.textContaining(buyer.phone), findsOneWidget);
      // A waiting buyer means the next batch can be notified — button visible.
      expect(find.textContaining(Strings.notifyNextBatch(1)), findsOneWidget);
      // Scan entry point is present.
      expect(find.byIcon(Icons.qr_code_scanner), findsOneWidget);

      // Searching by ID suffix keeps the matching row…
      await tester.enterText(
        find.byType(TextField),
        buyer.nationalId.substring(buyer.nationalId.length - 3),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining(buyer.nationalId), findsOneWidget);
      // …but the notify action is hidden while searching, so a lookup
      // can never accidentally release a batch.
      expect(find.textContaining(Strings.notifyNextBatch(1)), findsNothing);

      // A non-matching suffix shows the no-results state and no rows.
      await tester.enterText(find.byType(TextField), '000');
      await tester.pumpAndSettle();
      expect(find.text(Strings.buyerSearchNoResults), findsOneWidget);
      expect(find.textContaining(buyer.nationalId), findsNothing);

      // Clearing the search restores the full queue and the notify button.
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      expect(find.textContaining(buyer.nationalId), findsOneWidget);
      expect(find.textContaining(Strings.notifyNextBatch(1)), findsOneWidget);

      repo.dispose();
    });

    testWidgets(
      'shows per-batch progress and asks for confirmation before notifying',
      (tester) async {
        final harness = buildQueueHarness();
        final repo = harness.repo;
        final controller = harness.controller;

        final store = (await repo.getStoreById(seededStoreId))!;
        final date = todayDateString();
        final purchase = await controller.buy(storeId: store.id, date: date);
        // notify_next_batch is owner-only server-side; act as the owner now.
        repo.currentUserId = seededOwnerId;

        await tester.pumpWidget(
          wrapWithMaterial(
            OwnerQueueScreen(controller: controller, storeId: store.id),
          ),
        );
        await tester.pumpAndSettle();

        // Batch header tallies: nothing picked yet, one buyer not called.
        expect(find.text(Strings.batchSummary(0, 0, 1)), findsOneWidget);

        // Notifying is a confirmation, not a single tap.
        await tester.tap(find.textContaining(Strings.notifyNextBatch(1)));
        await tester.pumpAndSettle();
        expect(find.text(Strings.notifyConfirmTitle), findsOneWidget);
        expect(find.text(Strings.notifyConfirmBody(1)), findsOneWidget);

        // Backing out leaves the batch untouched.
        await tester.tap(find.text(Strings.cancelLabel));
        await tester.pumpAndSettle();
        expect(
          (await repo.getPurchaseById(purchase.id))!.status,
          PurchaseStatus.waiting,
        );

        // Confirming it actually calls the batch.
        await tester.tap(find.textContaining(Strings.notifyNextBatch(1)));
        await tester.pumpAndSettle();
        await tester.tap(find.text(Strings.notifyConfirmAction));
        await tester.pumpAndSettle();
        expect(
          (await repo.getPurchaseById(purchase.id))!.status,
          PurchaseStatus.notified,
        );

        repo.dispose();
      },
    );
  });
}
