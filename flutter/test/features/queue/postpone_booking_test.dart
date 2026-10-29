import 'package:flutter_test/flutter_test.dart';
import 'package:raghif/domain/models/purchase_model.dart';
import 'package:raghif/features/queue/queue_controller.dart';
import 'package:raghif/features/queue/queue_logic.dart';
import 'package:raghif/features/queue/qr_payload.dart';
import 'package:raghif/features/queue/qr_redemption.dart';
import '../../support/fake_queue_repository.dart';

void main() {
  late FakeQueueRepository repository;
  late QueueController controller;
  final today = todayDateString();
  final tomorrow = DateTime.parse(
    today,
  ).add(const Duration(days: 1)).toIso8601String().substring(0, 10);
  setUp(() {
    repository = FakeQueueRepository.seeded();
    controller = QueueController(repository);
  });
  tearDown(() {
    controller.dispose();
    repository.dispose();
  });
  test(
    'postpone moves same paid booking to tomorrow, resets status and remains visible',
    () async {
      final old = repository.givenPurchase(
        userId: 'user-buyer',
        storeId: 'store-rimal',
        date: today,
        status: PurchaseStatus.notified,
      );
      final moved = await controller.postponePurchase(old.id);
      expect(moved.id, old.id);
      expect(moved.storeId, old.storeId);
      expect(moved.purchaseDate, tomorrow);
      expect(moved.status, PurchaseStatus.waiting);
      expect(moved.postponementCount, 1);
      expect(controller.cachedPurchase(old.id), moved);
      expect(
        await controller.currentOrUpcomingPurchase('user-buyer', today),
        moved,
      );
      expect(await repository.getBlockingPurchase('user-buyer', today), isNull);
      await expectLater(controller.postponePurchase(old.id), throwsA(anything));
    },
  );
  test(
    'tomorrow quota applies across bakeries without changing source order',
    () async {
      final old = repository.givenPurchase(
        userId: 'user-buyer',
        storeId: 'store-rimal',
        date: today,
      );
      repository.givenPurchase(
        userId: 'user-buyer',
        storeId: 'store-shati',
        date: tomorrow,
      );
      await expectLater(controller.postponePurchase(old.id), throwsA(anything));
      expect((await repository.getPurchaseById(old.id))!.purchaseDate, today);
    },
  );
  test('rejects collected, another buyer and past booking', () async {
    for (final p in [
      repository.givenPurchase(
        userId: 'user-buyer',
        storeId: 'store-rimal',
        date: today,
        status: PurchaseStatus.collected,
      ),
      repository.givenPurchase(
        userId: 'other',
        storeId: 'store-rimal',
        date: today,
      ),
      repository.givenPurchase(
        userId: 'user-buyer',
        storeId: 'store-rimal',
        date: '2020-01-01',
      ),
    ]) {
      await expectLater(controller.postponePurchase(p.id), throwsA(anything));
    }
  });
  test(
    'future collected rows do not hide earliest upcoming uncollected order',
    () async {
      repository.givenPurchase(
        userId: 'user-buyer',
        storeId: 'store-rimal',
        date: tomorrow,
        status: PurchaseStatus.collected,
      );
      expect(
        await controller.currentOrUpcomingPurchase('user-buyer', today),
        isNull,
      );
    },
  );
  test('old receipt date cannot redeem a moved booking even once notified', () {
    final p = repository.givenPurchase(
      userId: 'user-buyer',
      storeId: 'store-rimal',
      date: tomorrow,
      status: PurchaseStatus.notified,
    );
    final result = evaluateQrRedemption(
      payload: QrPayload(
        purchaseId: p.id,
        userName: '',
        storeName: '',
        purchaseDate: today,
      ),
      purchase: p,
      ownerStoreId: p.storeId,
    );
    expect(result.outcome, QrRedemptionOutcome.staleReceipt);
  });
}
