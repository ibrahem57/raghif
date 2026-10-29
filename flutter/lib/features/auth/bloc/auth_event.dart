import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class CheckAuthSessionEvent extends AuthEvent {
  const CheckAuthSessionEvent();
}

class RequestOtpEvent extends AuthEvent {
  const RequestOtpEvent({required this.nationalId});

  final String nationalId;

  @override
  List<Object?> get props => [nationalId];
}

class VerifyOtpEvent extends AuthEvent {
  const VerifyOtpEvent({required this.nationalId, required this.otp});

  final String nationalId;
  final String otp;

  @override
  List<Object?> get props => [nationalId, otp];
}

class PinLoginRequestedEvent extends AuthEvent {
  const PinLoginRequestedEvent({required this.nationalId, required this.pin});

  final String nationalId;
  final String pin;

  @override
  List<Object?> get props => [nationalId, pin];
}

class LoginRequestedEvent extends AuthEvent {
  const LoginRequestedEvent({required this.phone, required this.pin});

  final String phone;
  final String pin;

  @override
  List<Object?> get props => [phone, pin];
}

class RegisterRequestedEvent extends AuthEvent {
  const RegisterRequestedEvent({
    required this.phone,
    required this.pin,
    required this.nationalId,
    required this.name,
    this.jawwalPayNumber,
  });

  final String phone;
  final String pin;
  final String nationalId;
  final String name;
  final String? jawwalPayNumber;

  @override
  List<Object?> get props => [phone, pin, nationalId, name, jawwalPayNumber];
}

class LogoutRequestedEvent extends AuthEvent {
  const LogoutRequestedEvent();
}

class UpdateProfileRequestedEvent extends AuthEvent {
  const UpdateProfileRequestedEvent({
    required this.name,
    required this.phone,
    required this.jawwalPayNumber,
  });

  final String name;
  final String phone;
  final String jawwalPayNumber;

  @override
  List<Object?> get props => [name, phone, jawwalPayNumber];
}

/// Mock verification approval — see WaitingForVerificationScreen. Real
/// ID/face-match is out of scope for this prototype.
class VerificationApprovedEvent extends AuthEvent {
  const VerificationApprovedEvent();
}
