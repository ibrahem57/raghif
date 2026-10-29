import '../../domain/models/purchase_model.dart';
import 'qr_payload.dart';

/// How a scanned receipt resolved against the owner's local data.
enum QrRedemptionOutcome {
  /// Purchase found, notified, arrival toggled by the caller — bag handed over.
  checkedIn,

  /// The booking moved to a different date; its old QR is invalid.
  staleReceipt,

  /// Already marked collected earlier — duplicate scan.
  alreadyCollected,

  /// Purchase exists but its batch has not been notified yet.
  batchNotCalledYet,

  /// Decoded fine but no matching purchase in this device's data
  /// (expected in the prototype — no cross-device sync; see issue #28).
  notFoundHere,

  /// Matches a purchase of a different store, or — since the v1 payload
  /// carries `store_id` — the code itself claims another store even when no
  /// local purchase exists.
  wrongStore,
}

/// Outcome of matching a decoded receipt against local data, keeping the
/// decoded payload so the UI can always show what was encoded.
class QrRedemptionResult {
  const QrRedemptionResult({
    required this.outcome,
    required this.payload,
    this.purchase,
  });

  final QrRedemptionOutcome outcome;
  final QrPayload payload;
  final PurchaseModel? purchase;

  int? get batchNumber => purchase?.batchNumber;

  /// Store name to show on a wrong-store result: prefer the local record
  /// when we have one, otherwise fall back to the store the code claims.
  String? get actualStoreName => purchase?.storeName ?? payload.storeName;
}

/// Pure decode-and-match logic, deliberately separated from the camera widget
/// so redemption rules are unit-testable without a camera (issue #28 testing
/// decision). The caller applies [QrRedemptionOutcome.checkedIn] by toggling
/// arrival on the returned [QrRedemptionResult.purchase].
QrRedemptionResult evaluateQrRedemption({
  required QrPayload payload,
  required PurchaseModel? purchase,
  required String ownerStoreId,
}) {
  // The v1 code's own store claim is checked FIRST: it is decidable without
  // any local data, so a receipt from another bakery scanned on a device
  // that never saw the purchase reports wrongStore instead of notFoundHere.
  if (payload.storeId != null && payload.storeId != ownerStoreId) {
    return QrRedemptionResult(
      outcome: QrRedemptionOutcome.wrongStore,
      payload: payload,
      purchase: purchase,
    );
  }

  if (purchase == null) {
    return QrRedemptionResult(
      outcome: QrRedemptionOutcome.notFoundHere,
      payload: payload,
    );
  }

  if (purchase.storeId != ownerStoreId) {
    return QrRedemptionResult(
      outcome: QrRedemptionOutcome.wrongStore,
      payload: payload,
      purchase: purchase,
    );
  }

  if (payload.purchaseId != purchase.id ||
      payload.purchaseDate != purchase.purchaseDate) {
    return QrRedemptionResult(
      outcome: QrRedemptionOutcome.staleReceipt,
      payload: payload,
      purchase: purchase,
    );
  }

  final outcome = switch (purchase.status) {
    PurchaseStatus.notified => QrRedemptionOutcome.checkedIn,
    PurchaseStatus.collected => QrRedemptionOutcome.alreadyCollected,
    PurchaseStatus.waiting => QrRedemptionOutcome.batchNotCalledYet,
  };
  return QrRedemptionResult(
    outcome: outcome,
    payload: payload,
    purchase: purchase,
  );
}
