import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/customer_summary_model.dart';
import '../../domain/models/purchase_model.dart';
import '../../domain/models/scan_event_model.dart';
import '../../domain/models/store_day_summary.dart';
import '../../domain/models/store_list_entry.dart';
import '../../domain/models/store_model.dart';
import '../../domain/repositories/queue_repository.dart';
import '../receipt_store.dart';

/// The only [QueueRepository]. Supabase is the only source of data.
///
/// Every read is a query against Postgres, scoped by RLS. `watch*` streams
/// re-run their query whenever Realtime reports a change to `purchases` or
/// `stores`, and after this device's own writes. Nothing is kept on the
/// phone except the buyer's latest receipt ([ReceiptStore]), so the pickup
/// QR still opens with no signal.
class SupabaseQueueRepository implements QueueRepository {
  SupabaseQueueRepository({
    required SupabaseClient client,
    ReceiptStore? receipts,
  }) : _client = client,
       _receipts = receipts ?? ReceiptStore();

  final SupabaseClient _client;
  final ReceiptStore _receipts;
  final Map<String, PurchaseModel> _latestPurchases = {};

  bool _isActiveBuyer(String userId) =>
      _client.auth.currentSession != null &&
      _client.auth.currentUser?.id == userId;

  /// A read that began before a move may finish after it. Keep the newer
  /// booking version both in the persisted ticket and in the returned value.
  Future<PurchaseModel> _rememberPurchase(PurchaseModel incoming) async {
    var purchase = incoming;
    final known = _latestPurchases[purchase.id];
    if (known != null && known.postponementCount > purchase.postponementCount) {
      purchase = known;
    }
    if (_isActiveBuyer(purchase.userId)) {
      final saved = await _receipts.load();
      if (saved?.id == purchase.id &&
          saved!.userId == purchase.userId &&
          saved.postponementCount > purchase.postponementCount) {
        purchase = saved;
      }
      await _receipts.save(purchase);
      final persisted = await _receipts.load();
      if (persisted?.id == purchase.id &&
          persisted!.userId == purchase.userId &&
          persisted.postponementCount > purchase.postponementCount) {
        purchase = persisted;
      }
    }
    // An overlapping read may have completed during the preference write.
    final latest = _latestPurchases[purchase.id];
    if (latest != null &&
        latest.postponementCount > purchase.postponementCount) {
      return latest;
    }
    _latestPurchases[purchase.id] = purchase;
    return purchase;
  }

  /// Fires when server data may have changed: a Realtime event or a write
  /// made from this device. Every live stream re-queries on it.
  final _changes = StreamController<void>.broadcast();
  RealtimeChannel? _channel;

  /// Purchase row plus the buyer and store names the screens show.
  static const _purchaseColumns =
      '*, profiles(name, phone, national_id), stores(name)';

  // ------------------------------------------------------------- writes --

  /// Runs an RPC. Every failure surfaces as one of two exceptions the UI can
  /// act on: [StoreSoldOutException] (a rule Postgres enforced) or
  /// [BackendUnavailableException] (the write did not happen, for any other
  /// reason). Raw driver errors never reach a screen.
  Future<T> _rpc<T>(String name, Map<String, dynamic> params) async {
    if (_client.auth.currentSession == null) {
      throw const BackendUnavailableException('no session');
    }
    try {
      return await _client.rpc(name, params: params) as T;
    } on PostgrestException catch (e) {
      throw mapRpcError(e);
    } catch (e) {
      // Socket errors, DNS failures, timeouts: the write did not happen.
      throw BackendUnavailableException(e);
    }
  }

  /// An RPC that changes server state: live streams re-query after it.
  Future<T> _write<T>(String name, Map<String, dynamic> params) async {
    final result = await _rpc<T>(name, params);
    _changes.add(null);
    return result;
  }

  /// Message raised by `reserve_bag` when a store is shut or out of bags.
  @visibleForTesting
  static const soldOutMessage = 'store closed or sold out';

  /// Message raised by `notify_next_batch` when nothing is left to call.
  static const _noWaitingBatch = 'no waiting batch to notify';

  @visibleForTesting
  static Exception mapRpcError(PostgrestException e) =>
      e.message.toLowerCase() == soldOutMessage
      ? StoreSoldOutException()
      : BackendUnavailableException(e);

  @override
  Future<PurchaseModel> reserveBag({
    required String storeId,
    required String date,
  }) async {
    final row = await _write<Map<String, dynamic>>('reserve_bag', {
      'p_store_id': storeId,
      'p_purchase_date': date,
    });
    try {
      final saved = await getPurchaseById(row['id'] as String);
      if (saved != null) return saved;
    } catch (_) {
      // The reservation went through; only the follow-up read failed.
    }
    final bare = purchaseFromRow(row);
    await _receipts.save(bare);
    return bare;
  }

  @override
  Future<PurchaseModel> postponePurchase(String purchaseId) async {
    final previous = await _receipts.load();
    Map<String, dynamic> row;
    try {
      row = await _rpc<Map<String, dynamic>>('postpone_purchase', {
        'p_purchase_id': purchaseId,
      });
    } on BackendUnavailableException catch (e) {
      final cause = e.cause;
      if (cause is PostgrestException &&
          const {
            'not your booking',
            'only buyers may postpone',
            'already postponed',
            'only today uncollected booking may be postponed',
            'already reserved a bag tomorrow',
            'tomorrow capacity exhausted',
          }.contains(cause.message.toLowerCase())) {
        throw PostponeRejectedException(cause.message.toLowerCase());
      }
      rethrow;
    }
    var purchase = purchaseFromRow(row);
    if (previous?.id == purchase.id) {
      purchase = purchase.copyWith(
        userName: previous!.userName,
        userPhone: previous.userPhone,
        userNationalId: previous.userNationalId,
        storeName: previous.storeName,
      );
    }
    // Save the authoritative move before streams re-query.
    purchase = await _rememberPurchase(purchase);
    _changes.add(null);
    return purchase;
  }

  @override
  Future<bool> notifyNextBatch(String storeId, String date) async {
    try {
      await _write<dynamic>('notify_next_batch', {
        'p_store_id': storeId,
        'p_purchase_date': date,
      });
    } on BackendUnavailableException catch (e) {
      // "no waiting batch to notify" is an expected outcome, not a failure.
      final cause = e.cause;
      if (cause is PostgrestException &&
          cause.message.toLowerCase() == _noWaitingBatch) {
        return false;
      }
      rethrow;
    }
    return true;
  }

  @override
  Future<void> collectPurchase(String purchaseId) =>
      _write<dynamic>('collect_purchase', {'p_purchase_id': purchaseId});

  @override
  Future<void> setStoreOpen(String storeId, bool isOpen) => _write<dynamic>(
    'set_store_open',
    {'p_store_id': storeId, 'p_is_open': isOpen},
  );

  @override
  Future<void> saveStoreAllocation(
    String storeId, {
    required int dailyLimit,
    required int batchSize,
    required String date,
    String? openTime,
    String? closeTime,
  }) => _write<dynamic>('save_store_allocation', {
    'p_store_id': storeId,
    'p_daily_bag_limit': dailyLimit,
    'p_batch_size': batchSize,
    'p_purchase_date': date,
    'p_open_time': _time(openTime),
    'p_close_time': _time(closeTime),
  });

  @override
  Future<void> recordScan({
    required String storeId,
    required String outcome,
    String? purchaseId,
    String? scannedName,
    String? scannedNationalId,
  }) => _write<dynamic>('record_scan', {
    'p_store_id': storeId,
    'p_outcome': outcome,
    'p_purchase_id': purchaseId,
    'p_scanned_name': scannedName,
    'p_scanned_national_id': scannedNationalId,
  });

  @override
  Future<void> setStorePinned({
    required String userId,
    required String storeId,
    required bool pinned,
  }) => _write<dynamic>('set_store_pinned', {
    'p_store_id': storeId,
    'p_pinned': pinned,
  });

  // -------------------------------------------------------------- reads --

  /// Runs [query]; anything that is not an answer from the server becomes
  /// [BackendUnavailableException], same as for writes.
  Future<T> _read<T>(Future<T> Function() query) async {
    try {
      return await query();
    } catch (e) {
      throw BackendUnavailableException(e);
    }
  }

  /// [fetch] now, then again on every change. A failed fetch keeps the last
  /// value on screen and retries shortly, instead of erroring the stream.
  ///
  /// ponytail: re-runs the whole query per change; fine for one pilot store,
  /// filter Realtime by store_id if the queue ever gets large.
  Stream<T> _live<T>(Future<T> Function() fetch) {
    late final StreamController<T> out;
    StreamSubscription<void>? changes;
    Timer? retry;
    var generation = 0;

    Future<void> emit() async {
      final requestGeneration = ++generation;
      retry?.cancel();
      try {
        final value = await fetch();
        if (!out.isClosed && requestGeneration == generation) out.add(value);
      } catch (error) {
        if (!out.isClosed && requestGeneration == generation) {
          out.addError(BackendUnavailableException(error));
          retry = Timer(const Duration(seconds: 10), emit);
        }
      }
    }

    out = StreamController<T>(
      onListen: () {
        _listenForServerChanges();
        changes = _changes.stream.listen((_) => emit());
        emit();
      },
      onCancel: () async {
        generation++;
        retry?.cancel();
        await changes?.cancel();
        await out.close();
      },
    );
    return out.stream;
  }

  void _listenForServerChanges() {
    _channel ??= _client
        .channel('public-changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'purchases',
          callback: (_) => _changes.add(null),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'stores',
          callback: (_) => _changes.add(null),
        )
        .subscribe();
  }

  @override
  Future<void> refresh() async => _changes.add(null);

  @override
  Stream<List<StoreModel>> watchStores() => _live(getStores);

  @override
  Future<List<StoreModel>> getStores() => _read(() async {
    final rows = await _client.from('stores').select().order('created_at');
    return rows.map(storeFromRow).toList();
  });

  @override
  Future<StoreModel?> getStoreById(String storeId) => _read(() async {
    final row = await _client
        .from('stores')
        .select()
        .eq('id', storeId)
        .maybeSingle();
    return row == null ? null : storeFromRow(row);
  });

  @override
  Future<StoreModel?> getStoreForOwner(String ownerId) => _read(() async {
    final row = await _client
        .from('stores')
        .select()
        .eq('owner_id', ownerId)
        .limit(1)
        .maybeSingle();
    return row == null ? null : storeFromRow(row);
  });

  @override
  Stream<List<StoreListEntry>> watchStoreListForUser({
    required String userId,
    required String today,
  }) {
    return _live(() async {
      final stores = await getStores();
      final (pins, mine) = await _read(
        () async => (
          await _client
              .from('store_pins')
              .select('store_id')
              .eq('user_id', userId),
          await _client
              .from('purchases')
              .select('id, store_id, purchase_date, status')
              .eq('user_id', userId)
              .order('purchase_date', ascending: false),
        ),
      );
      final pinned = pins.map((p) => p['store_id'] as String).toSet();

      return stores.map((store) {
        final atStore = mine.where((p) => p['store_id'] == store.id);
        final todays = atStore
            .where((p) => p['purchase_date'] == today)
            .firstOrNull;
        return StoreListEntry(
          store: store,
          pinned: pinned.contains(store.id),
          todayStatus: todays == null ? null : _status(todays['status']),
          todayPurchaseId: todays?['id'] as String?,
          lastPurchaseDate: atStore.firstOrNull?['purchase_date'] as String?,
        );
      }).toList();
    });
  }

  @override
  Stream<List<PurchaseModel>> watchQueueForStore(String storeId, String date) =>
      _live(() => getQueueForStore(storeId, date));

  @override
  Future<List<PurchaseModel>> getQueueForStore(String storeId, String date) =>
      _read(() async {
        final rows = await _client
            .from('purchases')
            .select(_purchaseColumns)
            .eq('store_id', storeId)
            .eq('purchase_date', date)
            .order('created_at');
        return rows.map(purchaseFromRow).toList();
      });

  @override
  Future<PurchaseModel?> getBlockingPurchase(String userId, String date) async {
    try {
      final row = await _client
          .from('purchases')
          .select(_purchaseColumns)
          .eq('user_id', userId)
          .eq('purchase_date', date)
          .maybeSingle();
      if (row == null) {
        // The server has no order today, so a saved one must not resurface.
        final saved = await _receipts.load();
        if (saved?.userId == userId && saved?.purchaseDate == date) {
          await _receipts.clear();
        }
        return null;
      }
      return await _rememberPurchase(purchaseFromRow(row));
    } catch (e) {
      // No signal: the saved receipt stands in, if it is this buyer's today.
      final saved = await _receipts.load();
      if (_isActiveBuyer(userId) &&
          saved != null &&
          saved.userId == userId &&
          saved.purchaseDate == date) {
        return saved;
      }
      throw BackendUnavailableException(e);
    }
  }

  @override
  Future<PurchaseModel?> currentOrUpcomingPurchase(
    String userId,
    String today,
  ) async {
    try {
      final rows = await _client
          .from('purchases')
          .select(_purchaseColumns)
          .eq('user_id', userId)
          .gte('purchase_date', today)
          .order('purchase_date');
      final purchases = rows.map(purchaseFromRow).toList();
      final purchase =
          purchases
              .where((p) => p.status != PurchaseStatus.collected)
              .firstOrNull ??
          purchases.where((p) => p.purchaseDate == today).firstOrNull;
      if (purchase != null) {
        return await _rememberPurchase(purchase);
      } else {
        await _receipts.clear();
      }
      return purchase;
    } catch (e) {
      final saved = await _receipts.load();
      if (_isActiveBuyer(userId) &&
          saved != null &&
          saved.userId == userId &&
          saved.purchaseDate.compareTo(today) >= 0 &&
          (saved.purchaseDate == today ||
              saved.status != PurchaseStatus.collected)) {
        return saved;
      }
      throw BackendUnavailableException(e);
    }
  }

  @override
  Future<PurchaseModel?> getPurchaseById(String purchaseId) async {
    try {
      final row = await _client
          .from('purchases')
          .select(_purchaseColumns)
          .eq('id', purchaseId)
          .maybeSingle();
      if (row == null) return null;
      return await _rememberPurchase(purchaseFromRow(row));
    } catch (e) {
      final saved = await _receipts.load();
      if (saved != null &&
          saved.id == purchaseId &&
          _isActiveBuyer(saved.userId)) {
        return saved;
      }
      throw BackendUnavailableException(e);
    }
  }

  @override
  Stream<PurchaseModel?> watchPurchaseById(String purchaseId) =>
      _live(() => getPurchaseById(purchaseId));

  @override
  Future<List<ScanEventModel>> getScansForStore(
    String storeId, {
    int limit = 100,
  }) => _read(() async {
    final rows = await _client
        .from('scan_events')
        .select()
        .eq('store_id', storeId)
        .order('scanned_at', ascending: false)
        .limit(limit);
    return rows
        .map(
          (r) => ScanEventModel(
            id: r['id'] as String,
            storeId: r['store_id'] as String,
            purchaseId: r['purchase_id'] as String?,
            outcome: (r['outcome'] as String?) ?? '',
            scannedName: r['scanned_name'] as String?,
            scannedNationalId: r['scanned_national_id'] as String?,
            scannedAtMillis: _millis(r['scanned_at']),
          ),
        )
        .toList();
  });

  // Computed by Postgres (`store_customers` / `store_daily_summaries`) so the
  // owner's numbers come from the same rows the queue does.

  @override
  Stream<List<CustomerSummaryModel>> watchCustomersForStore(String storeId) =>
      _live(() => getCustomersForStore(storeId));

  @override
  Future<List<CustomerSummaryModel>> getCustomersForStore(
    String storeId,
  ) async {
    final rows = await _rpc<List<dynamic>>('store_customers', {
      'p_store_id': storeId,
    });
    return rows.cast<Map<String, dynamic>>().map((r) {
      return CustomerSummaryModel(
        userId: r['user_id'] as String,
        name: (r['name'] as String?) ?? '',
        phone: (r['phone'] as String?) ?? '',
        totalPurchases: (r['total_purchases'] as num?)?.toInt() ?? 0,
        lastPurchaseDate: (r['last_purchase_date'] as String?) ?? '',
      );
    }).toList();
  }

  @override
  Future<List<StoreDaySummary>> getDailySummaries(
    String storeId, {
    int limit = 30,
  }) async {
    final rows = await _rpc<List<dynamic>>('store_daily_summaries', {
      'p_store_id': storeId,
      'p_limit': limit,
    });
    return rows.cast<Map<String, dynamic>>().map((r) {
      return StoreDaySummary(
        date: (r['purchase_date'] as String?) ?? '',
        sold: (r['sold'] as num?)?.toInt() ?? 0,
        collected: (r['collected'] as num?)?.toInt() ?? 0,
        notCollected: (r['not_collected'] as num?)?.toInt() ?? 0,
      );
    }).toList();
  }

  // ------------------------------------------------------------ mapping --

  @visibleForTesting
  static StoreModel storeFromRow(Map<String, dynamic> row) => StoreModel(
    id: row['id'] as String,
    name: (row['name'] as String?) ?? '',
    isOpen: (row['is_open'] as bool?) ?? false,
    dailyBagLimit: (row['daily_bag_limit'] as int?) ?? 0,
    bagsRemaining: (row['bags_remaining'] as int?) ?? 0,
    ownerId: row['owner_id'] as String?,
    batchSize: (row['batch_size'] as int?) ?? 20,
    openTime: _hhmm(row['open_time'] as String?),
    closeTime: _hhmm(row['close_time'] as String?),
    area: (row['area'] as String?) ?? '',
    governorate: row['governorate'] as String?,
  );

  /// A `purchases` row, with the embedded `profiles` / `stores` names when
  /// the query asked for them (and RLS let this user see them).
  @visibleForTesting
  static PurchaseModel purchaseFromRow(Map<String, dynamic> row) {
    final buyer = row['profiles'] as Map<String, dynamic>?;
    final store = row['stores'] as Map<String, dynamic>?;
    return PurchaseModel(
      id: row['id'] as String,
      storeId: row['store_id'] as String,
      userId: row['user_id'] as String,
      purchaseDate: row['purchase_date'] as String,
      batchNumber: row['batch_number'] as int,
      postponementCount: (row['postponement_count'] as int?) ?? 0,
      status: _status(row['status']),
      createdAtMillis: _millis(row['created_at']),
      userName: buyer?['name'] as String?,
      userPhone: buyer?['phone'] as String?,
      userNationalId: buyer?['national_id'] as String?,
      storeName: store?['name'] as String?,
    );
  }

  static PurchaseStatus _status(Object? value) => switch (value) {
    'notified' => PurchaseStatus.notified,
    'collected' => PurchaseStatus.collected,
    _ => PurchaseStatus.waiting,
  };

  static int _millis(Object? iso) =>
      DateTime.parse(iso! as String).millisecondsSinceEpoch;

  /// Postgres `time` comes back as "HH:mm:ss"; the UI wants "HH:mm".
  static String? _hhmm(String? value) {
    if (value == null || value.length < 5) return value;
    return value.substring(0, 5);
  }

  /// Postgres `time` wants "HH:mm:ss"; the UI carries "HH:mm".
  static String? _time(String? hhmm) {
    if (hhmm == null || hhmm.isEmpty) return null;
    return hhmm.length == 5 ? '$hhmm:00' : hhmm;
  }
}
