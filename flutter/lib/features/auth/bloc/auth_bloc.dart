import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/i18n/strings.dart';
import '../../../domain/models/user_model.dart';
import '../../../domain/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

export 'auth_event.dart';
export 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({required AuthRepository authRepository})
    : _authRepository = authRepository,
      super(const AuthInitial()) {
    on<CheckAuthSessionEvent>(_onCheckAuthSession);
    on<RequestOtpEvent>(_onRequestOtp);
    on<VerifyOtpEvent>(_onVerifyOtp);
    on<PinLoginRequestedEvent>(_onPinLoginRequested);
    on<LoginRequestedEvent>(_onLoginRequested);
    on<RegisterRequestedEvent>(_onRegisterRequested);
    on<LogoutRequestedEvent>(_onLogoutRequested);
    on<VerificationApprovedEvent>(_onVerificationApproved);
    on<UpdateProfileRequestedEvent>(_onUpdateProfile);
  }

  final AuthRepository _authRepository;

  String? _pendingOtp;
  String? _pendingNationalId;
  int _sessionEpoch = 0;

  Future<void> _onUpdateProfile(
    UpdateProfileRequestedEvent event,
    Emitter<AuthState> emit,
  ) async {
    final current = state;
    if (current is! Authenticated || current.profileSaving) return;
    final epoch = _sessionEpoch;
    emit(Authenticated(current.user, profileSaving: true));
    try {
      final updated = await _authRepository.updateProfile(
        name: event.name.trim(),
        phone: event.phone.trim(),
        jawwalPayNumber: event.jawwalPayNumber.trim(),
      );
      if (epoch != _sessionEpoch ||
          state is! Authenticated ||
          (state as Authenticated).user.id != current.user.id) {
        return;
      }
      emit(Authenticated(updated));
    } catch (_) {
      if (epoch != _sessionEpoch ||
          state is! Authenticated ||
          (state as Authenticated).user.id != current.user.id) {
        return;
      }
      emit(
        Authenticated(
          current.user,
          profileError: 'تعذر حفظ البيانات. تحقق من الاتصال وحاول مجدداً.',
        ),
      );
    }
  }

  Future<void> _onCheckAuthSession(
    CheckAuthSessionEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final user = await _authRepository.restoreSession();
      emit(user != null ? Authenticated(user) : const Unauthenticated());
    } catch (e) {
      // Signed in on this phone, but the server could not be asked who that
      // is: the profile is not kept locally, so say so on the login screen.
      emit(const AuthFailure(Strings.loginOffline));
    }
  }

  Future<void> _onRequestOtp(
    RequestOtpEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final nationalId = event.nationalId.trim();
      // The server decides whether the ID exists. The local cache only knows
      // people who have signed in on this phone, so consulting it sent
      // everyone on a new device to "create an account".
      final otp = await _authRepository.requestOtp(nationalId);
      if (otp == null) {
        emit(AuthSwitchToRegister(nationalId: nationalId));
        return;
      }

      _pendingOtp = otp.code;
      _pendingNationalId = nationalId;
      // No SMS gateway yet: the login screen shows the mock code itself.
      emit(
        AuthOtpSent(
          nationalId: nationalId,
          phone: otp.phone,
          otpCode: otp.code,
        ),
      );
    } catch (e) {
      // The gateway answering "no" is handled in the repository; anything
      // that gets here is a call that never got an answer.
      emit(const AuthFailure(Strings.loginOffline));
    }
  }

  Future<void> _onVerifyOtp(
    VerifyOtpEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final nationalId = event.nationalId.trim();
      final otp = event.otp.trim();

      if (_pendingNationalId != null && _pendingNationalId != nationalId) {
        emit(const AuthFailure(Strings.otpError));
        return;
      }

      final expectedOtp =
          _pendingOtp ??
          (state is AuthOtpSent ? (state as AuthOtpSent).otpCode : '4821');

      if (otp != expectedOtp) {
        emit(const AuthFailure(Strings.otpError));
        return;
      }

      final user = await _authRepository.loginWithOtp(
        nationalId: nationalId,
        code: otp,
      );
      if (user != null) {
        _pendingOtp = null;
        _pendingNationalId = null;
        emit(Authenticated(user));
      } else {
        emit(const AuthFailure(Strings.loginError));
      }
    } catch (e) {
      // The gateway answering "no" is handled in the repository; anything
      // that gets here is a call that never got an answer.
      emit(const AuthFailure(Strings.loginOffline));
    }
  }

  Future<void> _onPinLoginRequested(
    PinLoginRequestedEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final nationalId = event.nationalId.trim();
      final pin = event.pin.trim();

      final user = await _authRepository.loginWithPin(
        nationalId: nationalId,
        pin: pin,
      );
      if (user != null) {
        emit(Authenticated(user));
        return;
      }

      final exists = await _authRepository.nationalIdExists(nationalId);
      if (exists) {
        emit(const AuthFailure(Strings.loginError));
      } else {
        emit(AuthSwitchToRegister(nationalId: nationalId));
      }
    } catch (e) {
      // The gateway answering "no" is handled in the repository; anything
      // that gets here is a call that never got an answer.
      emit(const AuthFailure(Strings.loginOffline));
    }
  }

  Future<void> _onLoginRequested(
    LoginRequestedEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final phone = event.phone.trim();
      final pin = event.pin.trim();

      final user = await _authRepository.login(phone: phone, pin: pin);
      if (user != null) {
        emit(Authenticated(user));
        return;
      }

      final exists = await _authRepository.phoneExists(phone);
      if (exists) {
        emit(const AuthFailure(Strings.loginError));
      } else {
        emit(AuthSwitchToRegister(nationalId: phone));
      }
    } catch (e) {
      // The gateway answering "no" is handled in the repository; anything
      // that gets here is a call that never got an answer.
      emit(const AuthFailure(Strings.loginOffline));
    }
  }

  Future<void> _onRegisterRequested(
    RegisterRequestedEvent event,
    Emitter<AuthState> emit,
  ) async {
    final validationError = _authRepository.validateRegistration(
      phone: event.phone,
      pin: event.pin,
      nationalId: event.nationalId,
      name: event.name,
      jawwalPayNumber: event.jawwalPayNumber,
    );

    if (validationError != null) {
      emit(AuthFailure(validationError));
      return;
    }

    emit(const AuthLoading());
    try {
      if (await _authRepository.phoneExists(event.phone)) {
        emit(const AuthFailure(Strings.phoneAlreadyRegistered));
        return;
      }
      if (await _authRepository.nationalIdExists(event.nationalId)) {
        emit(const AuthFailure(Strings.nationalIdAlreadyRegistered));
        return;
      }
      final user = await _authRepository.register(
        phone: event.phone,
        pin: event.pin,
        nationalId: event.nationalId,
        name: event.name,
        jawwalPayNumber: event.jawwalPayNumber,
      );
      emit(Authenticated(user));
    } catch (e) {
      emit(AuthFailure(e.toString()));
    }
  }

  Future<void> _onLogoutRequested(
    LogoutRequestedEvent event,
    Emitter<AuthState> emit,
  ) async {
    _sessionEpoch++;
    await _authRepository.logout();
    emit(const Unauthenticated());
  }

  Future<void> _onVerificationApproved(
    VerificationApprovedEvent event,
    Emitter<AuthState> emit,
  ) async {
    final current = state;
    if (current is! Authenticated) return;
    await _authRepository.updateVerificationStatus(
      current.user.id,
      VerificationStatus.verified,
    );
    final updated = await _authRepository.findById(current.user.id);
    if (updated != null) emit(Authenticated(updated));
  }
}
