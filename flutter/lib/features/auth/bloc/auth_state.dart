import 'package:equatable/equatable.dart';
import '../../../domain/models/user_model.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class Authenticated extends AuthState {
  const Authenticated(
    this.user, {
    this.profileSaving = false,
    this.profileError,
  });

  final UserModel user;
  final bool profileSaving;
  final String? profileError;

  @override
  List<Object?> get props => [user, profileSaving, profileError];
}

class Unauthenticated extends AuthState {
  const Unauthenticated();
}

class AuthFailure extends AuthState {
  const AuthFailure(this.errorMessage);

  final String errorMessage;

  @override
  List<Object?> get props => [errorMessage];
}

class AuthOtpSent extends AuthState {
  const AuthOtpSent({
    required this.nationalId,
    required this.phone,
    required this.otpCode,
  });

  final String nationalId;
  final String phone;
  final String otpCode;

  @override
  List<Object?> get props => [nationalId, phone, otpCode];
}

class AuthSwitchToRegister extends AuthState {
  const AuthSwitchToRegister({required this.nationalId});

  final String nationalId;

  @override
  List<Object?> get props => [nationalId];
}
