import 'package:raghif/domain/models/user_model.dart';
import 'package:raghif/domain/repositories/auth_repository.dart';

/// In-memory [AuthRepository] for tests that only need the app to boot.
///
/// Replaces `AuthRepositoryImpl`, which was deleted along with on-device
/// auth: PIN verification is the auth-gateway Edge Function's job now, so
/// there is no local implementation left to instantiate.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    this.users = const [],
    this.failWith,
    this.sessionUserId,
  });

  final List<UserModel> users;

  /// Who the persisted Supabase session belongs to at startup, if anyone.
  String? sessionUserId;

  /// When set, sign-in calls throw it: a call that never got an answer
  /// (no connection), as opposed to a server that said no.
  final Object? failWith;

  UserModel? _byNationalId(String nationalId) =>
      users.where((u) => u.nationalId == nationalId).firstOrNull;

  @override
  Future<UserModel?> login({
    required String phone,
    required String pin,
  }) async => users.where((u) => u.phone == phone).firstOrNull;

  @override
  Future<UserModel?> loginWithPin({
    required String nationalId,
    required String pin,
  }) async {
    if (failWith != null) throw failWith!;
    return _byNationalId(nationalId);
  }

  @override
  Future<UserModel?> loginWithOtp({
    required String nationalId,
    required String code,
  }) async => _byNationalId(nationalId);

  @override
  Future<({String code, String phone})?> requestOtp(String nationalId) async {
    if (failWith != null) throw failWith!;
    final user = _byNationalId(nationalId);
    return user == null ? null : (code: '1234', phone: user.phone);
  }

  @override
  Future<UserModel?> restoreSession() async {
    if (sessionUserId == null) return null;
    if (failWith != null) throw failWith!;
    return findById(sessionUserId!);
  }

  @override
  Future<UserModel?> findById(String id) async => _updatedUser?.id == id
      ? _updatedUser
      : users.where((u) => u.id == id).firstOrNull;

  @override
  Future<bool> nationalIdExists(String nationalId) async =>
      _byNationalId(nationalId) != null;

  @override
  Future<bool> phoneExists(String phone) async =>
      users.any((u) => u.phone == phone);

  @override
  String? validateRegistration({
    required String phone,
    required String pin,
    required String nationalId,
    required String name,
    String? jawwalPayNumber,
  }) => null;

  @override
  Future<UserModel> register({
    required String phone,
    required String pin,
    required String nationalId,
    required String name,
    String? jawwalPayNumber,
  }) async => UserModel(
    id: 'user-registered',
    phone: phone,
    nationalId: nationalId,
    name: name,
    jawwalPayNumber: jawwalPayNumber,
  );

  @override
  Future<void> updateVerificationStatus(
    String userId,
    VerificationStatus status,
  ) async {}

  @override
  Future<void> updateJawwalPayNumber(
    String userId,
    String jawwalPayNumber,
  ) async {}

  @override
  Future<UserModel> updateProfile({
    required String name,
    required String phone,
    required String jawwalPayNumber,
  }) async {
    if (failWith != null) throw failWith!;
    final current = await restoreSession();
    if (current == null) throw StateError('Not signed in');
    final updated = UserModel(
      id: current.id,
      nationalId: current.nationalId,
      role: current.role,
      verificationStatus: current.verificationStatus,
      name: name.trim(),
      phone: phone.trim(),
      jawwalPayNumber: jawwalPayNumber.trim().isEmpty
          ? null
          : jawwalPayNumber.trim(),
    );
    _updatedUser = updated;
    return updated;
  }

  UserModel? _updatedUser;

  @override
  Future<void> logout() async => sessionUserId = null;
}
