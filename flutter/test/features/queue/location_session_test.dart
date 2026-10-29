import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:raghif/domain/models/store_list_entry.dart';
import 'package:raghif/domain/models/store_model.dart';
import 'package:raghif/features/queue/queue_controller.dart';
import '../../support/fake_queue_repository.dart';

class _ContextRepo extends FakeQueueRepository {
  final a = StreamController<List<StoreListEntry>>.broadcast();
  final b = StreamController<List<StoreListEntry>>.broadcast();
  @override
  Stream<List<StoreListEntry>> watchStoreListForUser({
    required String userId,
    required String today,
  }) => userId == 'a' ? a.stream : b.stream;
}

class _OfflineStores extends FakeQueueRepository {
  bool available = false;
  @override
  Stream<List<StoreModel>> watchStores() => const Stream.empty();
  @override
  Future<List<StoreModel>> getStores() async {
    if (!available) throw Exception('offline');
    return [];
  }
}

void main() {
  test(
    'switching buyer clears old pins and ignores old stream; logout resets',
    () async {
      final repo = _ContextRepo();
      final controller = QueueController(repo);
      controller.watchStoreListFor('a');
      repo.a.add(const [
        StoreListEntry(
          store: StoreModel(
            id: 's',
            name: 'مخبز',
            isOpen: true,
            dailyBagLimit: 3,
            bagsRemaining: 2,
          ),
          pinned: true,
          todayPurchaseId: 'private-a',
        ),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(controller.storeList.single.pinned, isTrue);
      controller.watchStoreListFor('b');
      expect(controller.storeList, isEmpty);
      repo.a.add(const [
        StoreListEntry(
          store: StoreModel(
            id: 'secret',
            name: 'قديم',
            isOpen: true,
            dailyBagLimit: 1,
            bagsRemaining: 0,
          ),
        ),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(controller.storeList, isEmpty);
      controller.resetForSession();
      expect(controller.todayQueue, isEmpty);
      controller.dispose();
      repo.dispose();
      await repo.a.close();
      await repo.b.close();
    },
  );

  test(
    'cold store failure is explicit and retry can reach genuine empty state',
    () async {
      final repo = _OfflineStores();
      final controller = QueueController(repo);
      await controller.refreshStores();
      expect(controller.storesFailed, isTrue);
      expect(controller.storesLoaded, isFalse);
      repo.available = true;
      await controller.refreshStores();
      expect(controller.storesFailed, isFalse);
      expect(controller.storesLoaded, isTrue);
      controller.dispose();
      repo.dispose();
    },
  );
}
