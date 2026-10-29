import '../models/customer_summary_model.dart';
import '../models/purchase_model.dart';
import '../models/scan_event_model.dart';
import '../models/store_day_summary.dart';
import '../models/store_list_entry.dart';
import '../models/store_model.dart';

/// Thrown by [QueueRepository.reserveBag] when the store has no bags left
/// (or has closed) — decided by Postgres, not by the on-device cache.
class StoreSoldOutException implements Exception {}

/// Thrown by any write when the backend can't be reached.
///
/// Postgres is the source of truth, so a write that can't reach it has not
/// happened. The app says so rather than recording it locally and letting
/// two devices disagree about who holds the last bag. Reads keep working
/// from cache while offline; writes do not.
class BackendUnavailableException implements Exception {
  const BackendUnavailableException([this.cause]);

  final Object? cause;

  @override
  String toString() => 'BackendUnavailableException($cause)';
}

/// Reads come from the on-device cache (see `AppDatabase`), which the sync
/// service keeps fed from Supabase. Writes go to Postgres RPCs, which own
/// every rule worth enforcing — sold-out, one-bag-per-day, batch
/// assignment, who may notify or collect.
///
/// Ids are Supabase UUIDs throughout: the same string identifies a row on
/// the device, on the server and inside a QR code.
class PostponeRejectedException implements Exception {
  const PostponeRejectedException(this.reason);
  final String reason;
}

abstract class QueueRepository {
  /// Pulls the current server state into the cache. Safe to call often;
  /// swallows connection errors, since reads are allowed to be stale.
  Future<void> refresh();

  Stream<List<StoreModel>> watchStores();

  Future<List<StoreModel>> getStores();

  Future<StoreModel?> getStoreById(String storeId);

  /// The store this user owns, or null if they own none.
  Future<StoreModel?> getStoreForOwner(String ownerId);

  /// The buyer's store list: every store plus that buyer's own context for it
  /// (pinned, today's order status, last purchase date), so the list can float
  /// the stores they actually use to the top and show extra detail on them.
  Stream<List<StoreListEntry>> watchStoreListForUser({
    required String userId,
    required String today,
  });

  Future<void> setStorePinned({
    required String userId,
    required String storeId,
    required bool pinned,
  });

  /// Audit trail: records one QR scan attempt at pickup.
  Future<void> recordScan({
    required String storeId,
    required String outcome,
    String? purchaseId,
    String? scannedName,
    String? scannedNationalId,
  });

  /// Scan history for a store, newest first.
  Future<List<ScanEventModel>> getScansForStore(
    String storeId, {
    int limit = 100,
  });

  Stream<List<PurchaseModel>> watchQueueForStore(String storeId, String date);

  Future<List<PurchaseModel>> getQueueForStore(String storeId, String date);

  /// This buyer's order for [date], if any — the one-bag-per-day rule made
  /// visible. Authoritative check happens server-side on reserve.
  Future<PurchaseModel?> getBlockingPurchase(String userId, String date);

  /// Today's booking, otherwise the earliest future uncollected booking.
  Future<PurchaseModel?> currentOrUpcomingPurchase(String userId, String today);

  /// Moves the signed-in buyer's eligible booking to tomorrow, atomically.
  Future<PurchaseModel> postponePurchase(String purchaseId);

  Future<PurchaseModel?> getPurchaseById(String purchaseId);

  Stream<PurchaseModel?> watchPurchaseById(String purchaseId);

  /// Reserves a bag for the signed-in user. The buyer is taken from the
  /// session server-side, never passed in, so a client can't reserve on
  /// someone else's behalf.
  Future<PurchaseModel> reserveBag({
    required String storeId,
    required String date,
  });

  /// Returns true if a waiting batch existed and was notified, false if
  /// there was nothing left to notify.
  Future<bool> notifyNextBatch(String storeId, String date);

  /// Owner hands the bag over.
  Future<void> collectPurchase(String purchaseId);

  Future<void> setStoreOpen(String storeId, bool isOpen);

  Future<void> saveStoreAllocation(
    String storeId, {
    required int dailyLimit,
    required int batchSize,
    required String date,
    String? openTime,
    String? closeTime,
  });

  Stream<List<CustomerSummaryModel>> watchCustomersForStore(String storeId);

  Future<List<CustomerSummaryModel>> getCustomersForStore(String storeId);

  /// Per-day sales totals for a store, newest day first — the owner's history
  /// browser. Computed by Postgres (`store_daily_summaries`).
  Future<List<StoreDaySummary>> getDailySummaries(
    String storeId, {
    int limit = 30,
  });
}
