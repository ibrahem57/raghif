import 'package:flutter_test/flutter_test.dart';
import 'package:raghif/data/receipt_store.dart';
import 'package:raghif/domain/models/purchase_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'moved receipt replaces date and retains postponement marker offline',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = ReceiptStore();
      const old = PurchaseModel(
        id: 'p',
        storeId: 's',
        userId: 'u',
        purchaseDate: '2026-10-27',
        batchNumber: 1,
        status: PurchaseStatus.notified,
        createdAtMillis: 1,
      );
      await store.save(old);
      final moved = old.copyWith(
        purchaseDate: '2026-10-28',
        status: PurchaseStatus.waiting,
        postponementCount: 1,
      );
      await store.save(moved);
      expect(await store.load(), moved);
      // A read started before the move may complete after the write.
      await store.save(old);
      expect(await store.load(), moved);
    },
  );
}
