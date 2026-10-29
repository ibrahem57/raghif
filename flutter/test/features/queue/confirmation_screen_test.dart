import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:raghif/core/i18n/strings.dart';
import 'package:raghif/features/auth/demo_accounts.dart';
import 'package:raghif/features/queue/confirmation_screen.dart';
import 'package:raghif/domain/models/purchase_model.dart';
import 'package:raghif/features/queue/receipt_card.dart';

import '../../support/queue_test_harness.dart';

Widget wrapWithMaterial(Widget child) {
  return MaterialApp(
    home: Directionality(textDirection: TextDirection.rtl, child: child),
  );
}

void main() {
  const testUser = DemoUser(
    id: seededBuyerId,
    phone: '0599111111',
    pin: '1234',
    role: UserRole.buyer,
    name: 'أحمد محمود',
    jawwalPayNumber: '0599111111',
  );

  group('ConfirmationScreen QR Receipt', () {
    testWidgets('receipt wraps real long metadata on a narrow screen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: const Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                body: SingleChildScrollView(
                  child: ReceiptCard(
                    storeName: 'مخبز الحي ومركز توزيع الخبز في المنطقة',
                    purchaseId: 'ad50b96f-6904-42d7-903f-a19eb8ff420b',
                    purchaseDate: '2026-10-17',
                    batchNumber: 12,
                    userName: 'أحمد محمود عبد الرحمن',
                    status: PurchaseStatus.collected,
                    qrData: 'real-payload-preserved',
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('#ad50b96f-6904-42d7-903f-a19eb8ff420b'), findsOneWidget);
      expect(find.text(Strings.statusCollectedShort), findsOneWidget);
      expect(find.text(Strings.paidBadge), findsNothing);
    });

    testWidgets('collected receipt does not announce ready for pickup', (
      tester,
    ) async {
      final harness = buildQueueHarness();
      final purchase = await harness.controller.buy(
        storeId: seededStoreId,
        date: '2026-09-03',
      );
      harness.repo.currentUserId = seededOwnerId;
      await harness.controller.notifyNextBatch(seededStoreId, '2026-09-03');
      await harness.controller.collectPurchase(purchase.id);
      harness.repo.currentUserId = seededBuyerId;
      await tester.pumpWidget(
        wrapWithMaterial(
          ConfirmationScreen(
            controller: harness.controller,
            purchaseId: purchase.id,
            currentUser: testUser,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(Strings.statusCollectedShort), findsWidgets);
      expect(find.text(Strings.statusNotified), findsNothing);
      expect(find.text(Strings.waitingReassurance), findsNothing);
      expect(find.byType(QrImageView), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });

    testWidgets('renders QR code and receipt info once purchase is present', (
      tester,
    ) async {
      // Built inside the test body, not setUp() — setUp() runs outside
      // testWidgets' own FakeAsync zone, and a controller/database built
      // there can't reliably deliver .watch() stream data inside the test
      // body (see owner_customers_screen_test.dart for the full story).
      // An explicit, awaited-seed repository is used instead of bare
      // buildQueueHarness().controller — its own no-DI fallback fires ensureSeeded()
      // unawaited, so buy() below could race ahead of the seed data.
      final harness = buildQueueHarness();
      final repo = harness.repo;
      final controller = harness.controller;
      final store = (await repo.getStoreById(seededStoreId))!;
      final purchase = await controller.buy(
        storeId: store.id,
        date: '2026-09-03',
      );

      await tester.pumpWidget(
        wrapWithMaterial(
          ConfirmationScreen(
            controller: controller,
            purchaseId: purchase.id,
            currentUser: testUser,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify receipt titles and share/save buttons are visible
      expect(find.text(Strings.receiptQrTitle), findsOneWidget);
      expect(find.text(Strings.receiptQrSubtitle), findsOneWidget);
      expect(find.text(Strings.shareQrButton), findsOneWidget);
      expect(find.text(Strings.saveQrButton), findsOneWidget);

      // Verify QrImageView is rendered
      expect(find.byType(QrImageView), findsOneWidget);

      // Verify reassurance message is displayed and fake estimated time clock is NOT shown
      expect(find.text(Strings.statusWaiting), findsOneWidget);
      expect(find.text(Strings.waitingReassurance), findsOneWidget);
      expect(find.text(Strings.estimatedTime), findsNothing);

      // Verify queue position and batch chips
      expect(find.textContaining(Strings.queuePosition), findsOneWidget);
      expect(
        find.text(Strings.batchLabel(purchase.batchNumber)),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });

    testWidgets('shows statusNotified when purchase is notified', (
      tester,
    ) async {
      final harness = buildQueueHarness();
      final repo = harness.repo;
      final controller = harness.controller;
      final store = (await repo.getStoreById(seededStoreId))!;
      final purchase = await controller.buy(
        storeId: store.id,
        date: '2026-09-03',
      );

      // Releasing a batch is owner-only server-side.
      repo.currentUserId = seededOwnerId;
      await controller.notifyNextBatch(store.id, '2026-09-03');
      repo.currentUserId = seededBuyerId;

      await tester.pumpWidget(
        wrapWithMaterial(
          ConfirmationScreen(
            controller: controller,
            purchaseId: purchase.id,
            currentUser: testUser,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(Strings.statusNotified), findsOneWidget);
      expect(find.text(Strings.statusWaiting), findsNothing);
      expect(find.text(Strings.waitingReassurance), findsNothing);
      expect(find.text(Strings.estimatedTime), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });

    testWidgets('renders empty shrink when purchase is not found', (
      tester,
    ) async {
      final controller = buildQueueHarness().controller;
      await tester.pumpWidget(
        wrapWithMaterial(
          ConfirmationScreen(
            controller: controller,
            purchaseId: 'non_existent_id',
            currentUser: testUser,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(QrImageView), findsNothing);
      expect(find.text(Strings.receiptQrTitle), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  });
}
