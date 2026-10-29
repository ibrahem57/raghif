import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/i18n/strings.dart';
import '../../core/notifications/fcm_service.dart';
import '../../domain/models/user_model.dart';
import '../../domain/repositories/auth_repository.dart';
import '../receipt_store.dart';

/// Auth backed by Supabase (national-ID + PIN, verified server-side by the
/// `auth-gateway` Edge Function, which mints a real Supabase session — see
/// docs/supabase-migration-plan.md).
///
/// Who is signed in is Supabase's own persisted session; the profile behind
/// it is read from `profiles` every time. Nothing about the user is kept on
/// the phone, except what the buyer's saved receipt already carries
/// ([ReceiptStore]), which lets an offline restart still reach the receipt.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository({
    required SupabaseClient client,
    FcmService? fcmService,
    ReceiptStore? receipts,
  }) : _client = client,
       _fcmService = fcmService,
       _receipts = receipts ?? ReceiptStore();

  final SupabaseClient _client;
  final FcmService? _fcmService;
  final ReceiptStore _receipts;

  /// Every profile column the app reads. Named, never `*`: `pin_hash` is
  /// revoked in SQL and asking for it fails the whole request.
  static const _profileColumns =
      'id, phone, national_id, name, role, jawwal_pay_number, '
      'verification_status';

  static UserModel _userFromRow(Map<String, dynamic> row) => UserModel(
    id: row['id'] as String,
    phone: (row['phone'] as String?) ?? '',
    nationalId: (row['national_id'] as String?) ?? '',
    name: (row['name'] as String?) ?? '',
    role: row['role'] == 'owner' ? UserRole.owner : UserRole.buyer,
    jawwalPayNumber: row['jawwal_pay_number'] as String?,
    verificationStatus: row['verification_status'] == 'verified'
        ? VerificationStatus.verified
        : VerificationStatus.pending,
  );

  Future<Map<String, dynamic>> _invoke(
    String action,
    Map<String, dynamic> payload,
  ) async {
    final res = await _client.functions.invoke(
      'auth-gateway',
      body: {'action': action, ...payload},
    );
    final data = res.data;
    if (data is Map && data['error'] != null) {
      throw Exception(data['error'].toString());
    }
    return Map<String, dynamic>.from(data as Map);
  }

  /// A gateway call where the server saying no (401 wrong PIN/code, 404 unknown
  /// ID) is an answer, not a failure: null. Anything else -- no connection, a
  /// timeout, a 5xx -- is rethrown, so the caller never reports "wrong PIN" or
  /// "not registered" for a network that never answered.
  Future<T?> _answered<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on FunctionException catch (e) {
      if (e.status == 401 || e.status == 404) return null;
      rethrow;
    }
  }

  Future<UserModel> _applySession(Map<String, dynamic> result) async {
    await _client.auth.setSession(result['refreshToken'] as String);
    final profile = Map<String, dynamic>.from(result['profile'] as Map);
    unawaited(_fcmService?.registerCurrentDeviceToken());
    return UserModel(
      id: profile['remoteId'] as String,
      phone: profile['phone'] as String? ?? '',
      nationalId: profile['nationalId'] as String? ?? '',
      name: profile['name'] as String? ?? '',
      role: profile['role'] == 'owner' ? UserRole.owner : UserRole.buyer,
      jawwalPayNumber: profile['jawwalPayNumber'] as String?,
      verificationStatus: profile['verificationStatus'] == 'verified'
          ? VerificationStatus.verified
          : VerificationStatus.pending,
    );
  }

  @override
  Future<UserModel?> login({required String phone, required String pin}) async {
    return _answered(() async {
      final result = await _invoke('login-pin', {
        'identifier': phone.trim(),
        'by': 'phone',
        'pin': pin.trim(),
      });
      return _applySession(result);
    });
  }

  @override
  Future<UserModel?> loginWithPin({
    required String nationalId,
    required String pin,
  }) async {
    return _answered(() async {
      final result = await _invoke('login-pin', {
        'identifier': nationalId.trim(),
        'by': 'nationalId',
        'pin': pin.trim(),
      });
      return _applySession(result);
    });
  }

  @override
  Future<UserModel?> loginWithOtp({
    required String nationalId,
    required String code,
  }) async {
    return _answered(() async {
      final result = await _invoke('otp-confirm', {
        'nationalId': nationalId.trim(),
        'otpCode': code.trim(),
      });
      return _applySession(result);
    });
  }

  @override
  Future<({String code, String phone})?> requestOtp(String nationalId) async {
    return _answered(() async {
      final result = await _invoke('otp-request', {
        'nationalId': nationalId.trim(),
      });
      return (
        code: result['otpCode'] as String,
        phone: (result['phone'] as String?) ?? '',
      );
    });
  }

  @override
  Future<UserModel?> restoreSession() async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) return null;
    try {
      return await findById(authUser.id);
    } catch (_) {
      // No signal at startup: a buyer with a saved receipt still gets in, far
      // enough to show it at the bakery. Nobody else does.
      final receipt = await _receipts.load();
      if (receipt == null || receipt.userId != authUser.id) rethrow;
      return UserModel(
        id: receipt.userId,
        phone: receipt.userPhone ?? '',
        nationalId: receipt.userNationalId ?? '',
        name: receipt.userName ?? '',
        verificationStatus: VerificationStatus.verified,
      );
    }
  }

  @override
  Future<UserModel?> findById(String id) async {
    final row = await _client
        .from('profiles')
        .select(_profileColumns)
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : _userFromRow(row);
  }

  @override
  Future<bool> nationalIdExists(String nationalId) async {
    try {
      final result = await _invoke('check-availability', {
        'nationalId': nationalId.trim(),
      });
      return result['nationalIdExists'] as bool? ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> phoneExists(String phone) async {
    try {
      final result = await _invoke('check-availability', {
        'phone': phone.trim(),
      });
      return result['phoneExists'] as bool? ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  String? validateRegistration({
    required String phone,
    required String pin,
    required String nationalId,
    required String name,
    String? jawwalPayNumber,
  }) {
    if (phone.trim().isEmpty ||
        pin.trim().length != 4 ||
        nationalId.trim().isEmpty ||
        name.trim().isEmpty) {
      return Strings.registerError;
    }
    return null;
  }

  @override
  Future<UserModel> register({
    required String phone,
    required String pin,
    required String nationalId,
    required String name,
    String? jawwalPayNumber,
  }) async {
    final result = await _invoke('register', {
      'phone': phone.trim(),
      'pin': pin.trim(),
      'nationalId': nationalId.trim(),
      'name': name.trim(),
      'jawwalPayNumber': jawwalPayNumber?.trim(),
    });
    return _applySession(result);
  }

  @override
  Future<void> updateVerificationStatus(
    String userId,
    VerificationStatus status,
  ) async {
    await _client
        .from('profiles')
        .update({
          'verification_status': status == VerificationStatus.verified
              ? 'verified'
              : 'pending',
        })
        .eq('id', userId);
  }

  @override
  Future<void> updateJawwalPayNumber(
    String userId,
    String jawwalPayNumber,
  ) async {
    await _client
        .from('profiles')
        .update({'jawwal_pay_number': jawwalPayNumber.trim()})
        .eq('id', userId);
  }

  @override
  Future<UserModel> updateProfile({
    required String name,
    required String phone,
    required String jawwalPayNumber,
  }) async {
    final row = await _client
        .rpc(
          'update_my_profile',
          params: {
            'p_name': name.trim(),
            'p_phone': phone.trim(),
            'p_jawwal_pay_number': jawwalPayNumber.trim(),
          },
        )
        .single();
    return _userFromRow(row);
  }

  @override
  Future<void> logout() async {
    // Before signOut: the device_tokens RLS policy needs a live session, and
    // a token left behind keeps pushing this user's batch alerts to whoever
    // holds the phone next. Best-effort — a dead connection must never trap
    // someone in a signed-in state they asked to leave.
    try {
      await _fcmService?.unregisterCurrentDeviceToken();
    } catch (_) {
      // ignored: logout proceeds regardless
    }
    // signOut() revokes the session on the server, so it throws when the
    // backend is down. Signing out is a local decision first: the local
    // session is dropped regardless, or a dead connection leaves the person
    // pressing "sign out" with nothing happening.
    try {
      await _client.auth.signOut();
    } catch (_) {
      // ignored: the server-side revoke is best effort
    }
    // The receipt carries this buyer's name and national ID.
    await _receipts.clear();
  }
}
