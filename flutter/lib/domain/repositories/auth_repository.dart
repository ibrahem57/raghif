import '../models/user_model.dart';

abstract class AuthRepository {
  Future<UserModel?> login({required String phone, required String pin});

  Future<UserModel?> loginWithPin({
    required String nationalId,
    required String pin,
  });

  /// [code] is the OTP the user entered; the backend checks it too, so a
  /// national ID alone never yields a session.
  Future<UserModel?> loginWithOtp({
    required String nationalId,
    required String code,
  });

  /// The (mock) code and the phone it goes to, or null if the national ID
  /// is not registered.
  Future<({String code, String phone})?> requestOtp(String nationalId);

  /// The signed-in user from the persisted Supabase session, with their
  /// profile read from the server; null when nobody is signed in.
  Future<UserModel?> restoreSession();

  Future<UserModel?> findById(String id);

  Future<bool> nationalIdExists(String nationalId);

  Future<bool> phoneExists(String phone);

  String? validateRegistration({
    required String phone,
    required String pin,
    required String nationalId,
    required String name,
    String? jawwalPayNumber,
  });

  Future<UserModel> register({
    required String phone,
    required String pin,
    required String nationalId,
    required String name,
    String? jawwalPayNumber,
  });

  Future<void> updateVerificationStatus(
    String userId,
    VerificationStatus status,
  );

  Future<void> updateJawwalPayNumber(String userId, String jawwalPayNumber);

  Future<UserModel> updateProfile({
    required String name,
    required String phone,
    required String jawwalPayNumber,
  });

  Future<void> logout();
}
