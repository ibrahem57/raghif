import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models/purchase_model.dart';

/// The one thing this app keeps on the phone: the signed-in buyer's latest
/// receipt, so the pickup QR still opens with no signal at the bakery.
///
/// Everything else comes from Supabase on demand. This is written only from
/// a server answer and read only when the server cannot be reached.
class ReceiptStore {
  static const _key = 'receipt.latest';

  Future<void> _pendingSave = Future.value();

  Future<void> save(PurchaseModel p) {
    final write = _pendingSave.catchError((Object _) {}).then((_) => _save(p));
    _pendingSave = write;
    return write;
  }

  Future<void> _save(PurchaseModel p) async {
    final prefs = await SharedPreferences.getInstance();
    // An older in-flight read must not overwrite a moved receipt.
    final previous = await load();
    if (previous?.id == p.id &&
        previous!.postponementCount > p.postponementCount) {
      return;
    }
    await prefs.setString(
      _key,
      jsonEncode({
        'id': p.id,
        'storeId': p.storeId,
        'userId': p.userId,
        'purchaseDate': p.purchaseDate,
        'batchNumber': p.batchNumber,
        'status': p.status.name,
        'createdAt': p.createdAtMillis,
        'userName': p.userName,
        'userPhone': p.userPhone,
        'userNationalId': p.userNationalId,
        'storeName': p.storeName,
        'postponementCount': p.postponementCount,
      }),
    );
  }

  Future<PurchaseModel?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return PurchaseModel(
        id: j['id'] as String,
        storeId: j['storeId'] as String,
        userId: j['userId'] as String,
        purchaseDate: j['purchaseDate'] as String,
        batchNumber: j['batchNumber'] as int,
        status: PurchaseStatus.values.byName(j['status'] as String),
        createdAtMillis: j['createdAt'] as int,
        userName: j['userName'] as String?,
        userPhone: j['userPhone'] as String?,
        userNationalId: j['userNationalId'] as String?,
        storeName: j['storeName'] as String?,
        postponementCount: (j['postponementCount'] as int?) ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
