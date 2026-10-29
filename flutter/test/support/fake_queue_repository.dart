import 'dart:async';

import 'package:raghif/domain/models/customer_summary_model.dart';
import 'package:raghif/domain/models/purchase_model.dart';
import 'package:raghif/domain/models/scan_event_model.dart';
import 'package:raghif/domain/models/store_day_summary.dart';
import 'package:raghif/domain/models/store_list_entry.dart';
import 'package:raghif/domain/models/store_model.dart';
import 'package:raghif/domain/repositories/queue_repository.dart';

/// In-memory stand-in for the backend.
///
/// Widget tests used to drive a real drift database through
/// `QueueRepositoryImpl`, which worked while the app owned its own rules.
/// Those rules live in Postgres now, so tests need something that behaves
/// like the server rather than like a local table: this enforces the same
/// invariants the RPCs do — batch numbers assigned at reserve time,
/// sold-out and one-bag-per-day refusals, owner-only writes — without a
/// network.
///
/// It is deliberately not a mock: the screens under test care about the
/// consequences of these rules, not about which method was called.
class FakeQueueRepository implements QueueRepository {
  FakeQueueRepository({
    List<StoreModel>? stores,
    Map<String, ({String name, String phone, String nationalId})>? users,
  }) : _stores = [...?stores],
       _users = {...?users};

  /// A default pilot world: one owned store plus a buyer, mirroring what
  /// `seed_demo_*` puts in Postgres.
  factory FakeQueueRepository.seeded() {
    return FakeQueueRepository(
      stores: const [
        StoreModel(
          id: 'store-rimal',
          name: 'مخبز الرمال',
          isOpen: true,
          dailyBagLimit: 300,
          bagsRemaining: 45,
          ownerId: 'user-owner',
          batchSize: 3,
          openTime: '08:00',
          closeTime: '10:00',
          area: 'الرمال',
        ),
        StoreModel(
          id: 'store-shati',
          name: 'مخبز الشاطئ',
          isOpen: true,
          dailyBagLimit: 300,
          bagsRemaining: 120,
          batchSize: 3,
          area: 'الشاطئ',
        ),
        StoreModel(
          id: 'store-nusseirat',
          name: 'مخبز النصيرات',
          isOpen: false,
          dailyBagLimit: 300,
          bagsRemaining: 0,
          batchSize: 3,
          area: 'النصيرات',
        ),
      ],
      users: const {
        'user-buyer': (
          name: 'أحمد ناصر',
          phone: '0599111111',
          nationalId: '900111222',
        ),
        'user-owner': (
          name: 'صاحب المخبز',
          phone: '0599222222',
          nationalId: '900333444',
        ),
      },
    );
  }

  final List<StoreModel> _stores;
  final Map<String, ({String name, String phone, String nationalId})> _users;
  final List<PurchaseModel> _purchases = [];
  final List<ScanEventModel> _scans = [];
  final Set<String> _pins = {};

  int _idSeq = 0;
  String _nextId(String prefix) => '$prefix-${++_idSeq}';

  final _storesCtrl = StreamController<List<StoreModel>>.broadcast();
  final _purchasesCtrl = StreamController<void>.broadcast();

  /// The signed-in user, as the Supabase session would report it. Writes
  /// that the server attributes to `auth.uid()` use this.
  String currentUserId = 'user-buyer';

  /// Set false to make every write fail the way an unreachable backend does.
  bool online = true;

  void dispose() {
    _storesCtrl.close();
    _purchasesCtrl.close();
  }

  // --- test helpers -------------------------------------------------------

  void addUser(
    String id, {
    required String name,
    required String phone,
    required String nationalId,
  }) {
    _users[id] = (name: name, phone: phone, nationalId: nationalId);
  }

  /// Inserts a purchase directly, bypassing the reserve rules — for setting
  /// up a queue state a test wants to start from.
  PurchaseModel givenPurchase({
    required String userId,
    required String storeId,
    required String date,
    int batchNumber = 1,
    PurchaseStatus status = PurchaseStatus.waiting,
  }) {
    final purchase = _decorate(
      PurchaseModel(
        id: _nextId('purchase'),
        storeId: storeId,
        userId: userId,
        purchaseDate: date,
        batchNumber: batchNumber,
        status: status,
        createdAtMillis:
            DateTime.now().millisecondsSinceEpoch + _purchases.length,
      ),
    );
    _purchases.add(purchase);
    _emit();
    return purchase;
  }

  void _emit() {
    if (!_storesCtrl.isClosed) _storesCtrl.add(List.of(_stores));
    if (!_purchasesCtrl.isClosed) _purchasesCtrl.add(null);
  }

  void _requireOnline() {
    if (!online) throw const BackendUnavailableException('test: offline');
  }

  void _requireOwner(String storeId) {
    final store = _stores.firstWhere((s) => s.id == storeId);
    if (store.ownerId != currentUserId) {
      throw StateError('not the store owner');
    }
  }

  PurchaseModel _decorate(PurchaseModel p) {
    final user = _users[p.userId];
    final store = _stores.where((s) => s.id == p.storeId).firstOrNull;
    return p.copyWith(
      userName: user?.name,
      userPhone: user?.phone,
      userNationalId: user?.nationalId,
      storeName: store?.name,
    );
  }

  void _replaceStore(StoreModel store) {
    final i = _stores.indexWhere((s) => s.id == store.id);
    if (i >= 0) _stores[i] = store;
  }

  /// Re-emits on every change so watch* streams behave like drift's.
  ///
  /// Deliberately not an `async*` generator: one of those yields its
  /// initial value and only *then* subscribes to the source, so anything
  /// emitted in between is dropped. Subscribing in `onListen` closes that
  /// gap, which matters because tests routinely mutate state right after
  /// building the controller.
  Stream<T> _watch<T>(T Function() read) {
    late StreamController<T> out;
    StreamSubscription<void>? sub;
    out = StreamController<T>(
      onListen: () {
        out.add(read());
        sub = _purchasesCtrl.stream.listen((_) => out.add(read()));
      },
      onCancel: () => sub?.cancel(),
    );
    return out.stream;
  }

  // --- writes -------------------------------------------------------------

  @override
  Future<PurchaseModel> reserveBag({
    required String storeId,
    required String date,
  }) async {
    _requireOnline();
    final store = _stores.firstWhere((s) => s.id == storeId);
    if (!store.isOpen || store.bagsRemaining <= 0) {
      throw StoreSoldOutException();
    }
    if (_purchases.any(
      (p) => p.userId == currentUserId && p.purchaseDate == date,
    )) {
      throw StateError('already reserved a bag today');
    }

    final sameDay = _purchases.where(
      (p) => p.storeId == storeId && p.purchaseDate == date,
    );
    final batch = (sameDay.length ~/ store.batchSize) + 1;

    _replaceStore(store.copyWith(bagsRemaining: store.bagsRemaining - 1));
    final purchase = _decorate(
      PurchaseModel(
        id: _nextId('purchase'),
        storeId: storeId,
        userId: currentUserId,
        purchaseDate: date,
        batchNumber: batch,
        status: PurchaseStatus.waiting,
        createdAtMillis:
            DateTime.now().millisecondsSinceEpoch + _purchases.length,
      ),
    );
    _purchases.add(purchase);
    _emit();
    return purchase;
  }

  @override
  Future<PurchaseModel> postponePurchase(String purchaseId) async {
    _requireOnline();
    final i = _purchases.indexWhere((p) => p.id == purchaseId);
    if (i < 0 || _purchases[i].userId != currentUserId) {
      throw const PostponeRejectedException('not your booking');
    }
    final p = _purchases[i];
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (p.postponementCount > 0) {
      throw const PostponeRejectedException('already postponed');
    }
    if (p.purchaseDate != today || p.status == PurchaseStatus.collected) {
      throw const PostponeRejectedException(
        'only today uncollected booking may be postponed',
      );
    }
    final tomorrow = DateTime.parse(
      today,
    ).add(const Duration(days: 1)).toIso8601String().substring(0, 10);
    if (_purchases.any(
      (p) => p.userId == currentUserId && p.purchaseDate == tomorrow,
    )) {
      throw const PostponeRejectedException('already reserved a bag tomorrow');
    }
    final store = _stores.firstWhere((s) => s.id == p.storeId);
    final future = _purchases
        .where((p) => p.storeId == store.id && p.purchaseDate == tomorrow)
        .length;
    if (future >= store.dailyBagLimit) {
      throw const PostponeRejectedException('tomorrow capacity exhausted');
    }
    final moved = p.copyWith(
      purchaseDate: tomorrow,
      postponementCount: 1,
      status: PurchaseStatus.waiting,
      batchNumber: future ~/ store.batchSize + 1,
    );
    _purchases[i] = moved;
    final sold = _purchases
        .where((p) => p.storeId == store.id && p.purchaseDate == today)
        .length;
    _replaceStore(
      store.copyWith(
        bagsRemaining: (store.bagsRemaining + 1).clamp(
          0,
          (store.dailyBagLimit - sold).clamp(0, store.dailyBagLimit),
        ),
      ),
    );
    _emit();
    return moved;
  }

  @override
  Future<PurchaseModel?> currentOrUpcomingPurchase(
    String userId,
    String today,
  ) async {
    final rows =
        _purchases
            .where(
              (p) =>
                  p.userId == userId &&
                  p.purchaseDate.compareTo(today) >= 0 &&
                  (p.purchaseDate == today ||
                      p.status != PurchaseStatus.collected),
            )
            .toList()
          ..sort((a, b) => a.purchaseDate.compareTo(b.purchaseDate));
    final purchase =
        rows.where((p) => p.status != PurchaseStatus.collected).firstOrNull ??
        rows.where((p) => p.purchaseDate == today).firstOrNull;
    return purchase == null ? null : _decorate(purchase);
  }

  @override
  Future<bool> notifyNextBatch(String storeId, String date) async {
    _requireOnline();
    _requireOwner(storeId);
    final waiting = _purchases.where(
      (p) =>
          p.storeId == storeId &&
          p.purchaseDate == date &&
          p.status == PurchaseStatus.waiting,
    );
    if (waiting.isEmpty) return false;

    final next = waiting
        .map((p) => p.batchNumber)
        .reduce((a, b) => a < b ? a : b);
    for (var i = 0; i < _purchases.length; i++) {
      final p = _purchases[i];
      if (p.storeId == storeId &&
          p.purchaseDate == date &&
          p.batchNumber == next &&
          p.status == PurchaseStatus.waiting) {
        _purchases[i] = p.copyWith(status: PurchaseStatus.notified);
      }
    }
    _emit();
    return true;
  }

  @override
  Future<void> collectPurchase(String purchaseId) async {
    _requireOnline();
    final i = _purchases.indexWhere((p) => p.id == purchaseId);
    if (i < 0) return;
    _requireOwner(_purchases[i].storeId);
    _purchases[i] = _purchases[i].copyWith(status: PurchaseStatus.collected);
    _emit();
  }

  @override
  Future<void> setStoreOpen(String storeId, bool isOpen) async {
    _requireOnline();
    _requireOwner(storeId);
    _replaceStore(
      _stores.firstWhere((s) => s.id == storeId).copyWith(isOpen: isOpen),
    );
    _emit();
  }

  @override
  Future<void> saveStoreAllocation(
    String storeId, {
    required int dailyLimit,
    required int batchSize,
    required String date,
    String? openTime,
    String? closeTime,
  }) async {
    _requireOnline();
    _requireOwner(storeId);
    final sold = _purchases
        .where((p) => p.storeId == storeId && p.purchaseDate == date)
        .length;
    _replaceStore(
      _stores
          .firstWhere((s) => s.id == storeId)
          .copyWith(
            dailyBagLimit: dailyLimit,
            batchSize: batchSize < 1 ? 1 : batchSize,
            bagsRemaining: (dailyLimit - sold) < 0 ? 0 : dailyLimit - sold,
            openTime: openTime,
            closeTime: closeTime,
          ),
    );
    _emit();
  }

  @override
  Future<void> recordScan({
    required String storeId,
    required String outcome,
    String? purchaseId,
    String? scannedName,
    String? scannedNationalId,
  }) async {
    _requireOnline();
    _scans.insert(
      0,
      ScanEventModel(
        id: _nextId('scan'),
        storeId: storeId,
        purchaseId: purchaseId,
        outcome: outcome,
        scannedName: scannedName,
        scannedNationalId: scannedNationalId,
        scannedAtMillis: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    _emit();
  }

  @override
  Future<void> setStorePinned({
    required String userId,
    required String storeId,
    required bool pinned,
  }) async {
    _requireOnline();
    final key = '$userId|$storeId';
    pinned ? _pins.add(key) : _pins.remove(key);
    _emit();
  }

  // --- reads --------------------------------------------------------------

  @override
  Future<void> refresh() async {}

  @override
  Stream<List<StoreModel>> watchStores() {
    late StreamController<List<StoreModel>> out;
    StreamSubscription<void>? sub;
    out = StreamController<List<StoreModel>>(
      onListen: () {
        out.add(List.of(_stores));
        sub = _storesCtrl.stream.listen((_) => out.add(List.of(_stores)));
      },
      onCancel: () => sub?.cancel(),
    );
    return out.stream;
  }

  @override
  Future<List<StoreModel>> getStores() async => List.of(_stores);

  @override
  Future<StoreModel?> getStoreById(String storeId) async =>
      _stores.where((s) => s.id == storeId).firstOrNull;

  @override
  Future<StoreModel?> getStoreForOwner(String ownerId) async =>
      _stores.where((s) => s.ownerId == ownerId).firstOrNull;

  @override
  Stream<List<StoreListEntry>> watchStoreListForUser({
    required String userId,
    required String today,
  }) {
    return _watch(() {
      return _stores.map((store) {
        final mine =
            _purchases
                .where((p) => p.userId == userId && p.storeId == store.id)
                .toList()
              ..sort((a, b) => b.purchaseDate.compareTo(a.purchaseDate));
        final todays = mine.where((p) => p.purchaseDate == today).firstOrNull;
        return StoreListEntry(
          store: store,
          pinned: _pins.contains('$userId|${store.id}'),
          todayStatus: todays?.status,
          todayPurchaseId: todays?.id,
          lastPurchaseDate: mine.firstOrNull?.purchaseDate,
        );
      }).toList();
    });
  }

  List<PurchaseModel> _queue(String storeId, String date) {
    final rows =
        _purchases
            .where((p) => p.storeId == storeId && p.purchaseDate == date)
            .map(_decorate)
            .toList()
          ..sort((a, b) => a.createdAtMillis.compareTo(b.createdAtMillis));
    return rows;
  }

  @override
  Stream<List<PurchaseModel>> watchQueueForStore(String storeId, String date) =>
      _watch(() => _queue(storeId, date));

  @override
  Future<List<PurchaseModel>> getQueueForStore(
    String storeId,
    String date,
  ) async => _queue(storeId, date);

  @override
  Future<PurchaseModel?> getBlockingPurchase(String userId, String date) async {
    final match = _purchases
        .where((p) => p.userId == userId && p.purchaseDate == date)
        .firstOrNull;
    return match == null ? null : _decorate(match);
  }

  @override
  Future<PurchaseModel?> getPurchaseById(String purchaseId) async {
    final match = _purchases.where((p) => p.id == purchaseId).firstOrNull;
    return match == null ? null : _decorate(match);
  }

  @override
  Stream<PurchaseModel?> watchPurchaseById(String purchaseId) => _watch(() {
    final match = _purchases.where((p) => p.id == purchaseId).firstOrNull;
    return match == null ? null : _decorate(match);
  });

  @override
  Future<List<ScanEventModel>> getScansForStore(
    String storeId, {
    int limit = 100,
  }) async => _scans.where((s) => s.storeId == storeId).take(limit).toList();

  List<CustomerSummaryModel> _customers(String storeId) {
    final byUser = <String, List<PurchaseModel>>{};
    for (final p in _purchases.where((p) => p.storeId == storeId)) {
      byUser.putIfAbsent(p.userId, () => []).add(p);
    }
    final out =
        byUser.entries.map((e) {
            final user = _users[e.key];
            final dates = e.value.map((p) => p.purchaseDate).toList()..sort();
            return CustomerSummaryModel(
              userId: e.key,
              name: user?.name ?? '',
              phone: user?.phone ?? '',
              totalPurchases: e.value.length,
              lastPurchaseDate: dates.last,
            );
          }).toList()
          ..sort((a, b) => b.lastPurchaseDate.compareTo(a.lastPurchaseDate));
    return out;
  }

  @override
  Stream<List<CustomerSummaryModel>> watchCustomersForStore(String storeId) =>
      _watch(() => _customers(storeId));

  @override
  Future<List<CustomerSummaryModel>> getCustomersForStore(
    String storeId,
  ) async => _customers(storeId);

  @override
  Future<List<StoreDaySummary>> getDailySummaries(
    String storeId, {
    int limit = 30,
  }) async {
    final byDate = <String, List<PurchaseModel>>{};
    for (final p in _purchases.where((p) => p.storeId == storeId)) {
      byDate.putIfAbsent(p.purchaseDate, () => []).add(p);
    }
    final dates = byDate.keys.toList()..sort((a, b) => b.compareTo(a));
    return dates.take(limit).map((date) {
      final rows = byDate[date]!;
      final collected = rows
          .where((p) => p.status == PurchaseStatus.collected)
          .length;
      return StoreDaySummary(
        date: date,
        sold: rows.length,
        collected: collected,
        notCollected: rows.length - collected,
      );
    }).toList();
  }
}
