import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:raghif/domain/models/user_model.dart';
import 'package:raghif/domain/repositories/auth_repository.dart';
import 'package:raghif/features/auth/bloc/auth_bloc.dart';

class _Repository extends Mock implements AuthRepository {}

void main() {
  const user = UserModel(
    id: 'a',
    phone: '0599111111',
    nationalId: '900111222',
    name: 'أحمد',
  );
  const event = UpdateProfileRequestedEvent(
    name: 'محمد',
    phone: '0599222222',
    jawwalPayNumber: '',
  );
  late _Repository repository;
  setUp(() => repository = _Repository());
  void stub(Future<UserModel> Function() response) {
    when(
      () => repository.updateProfile(
        name: 'محمد',
        phone: '0599222222',
        jawwalPayNumber: '',
      ),
    ).thenAnswer((_) => response());
  }

  blocTest<AuthBloc, AuthState>(
    'profile save remains authenticated and uses the server profile',
    build: () {
      stub(() async => user.copyWith(name: 'محمد', phone: '0599222222'));
      return AuthBloc(authRepository: repository);
    },
    seed: () => const Authenticated(user),
    act: (bloc) => bloc.add(event),
    expect: () => [
      const Authenticated(user, profileSaving: true),
      Authenticated(user.copyWith(name: 'محمد', phone: '0599222222')),
    ],
  );

  blocTest<AuthBloc, AuthState>(
    'profile failure retains authenticated user with an actionable error',
    build: () {
      stub(() async => throw Exception('offline'));
      return AuthBloc(authRepository: repository);
    },
    seed: () => const Authenticated(user),
    act: (bloc) => bloc.add(event),
    expect: () => [
      const Authenticated(user, profileSaving: true),
      isA<Authenticated>()
          .having((s) => s.user, 'same user', user)
          .having((s) => s.profileSaving, 'stopped saving', false)
          .having((s) => s.profileError, 'error', isNotEmpty),
    ],
  );

  test(
    'logout during profile save cannot restore the authenticated session',
    () async {
      final pending = Completer<UserModel>();
      stub(() => pending.future);
      when(() => repository.restoreSession()).thenAnswer((_) async => user);
      when(() => repository.logout()).thenAnswer((_) async {});
      final bloc = AuthBloc(authRepository: repository);
      bloc.add(const CheckAuthSessionEvent());
      await bloc.stream.firstWhere((s) => s is Authenticated);
      bloc.add(event);
      await bloc.stream.firstWhere(
        (s) => s is Authenticated && s.profileSaving,
      );
      bloc.add(const LogoutRequestedEvent());
      await bloc.stream.firstWhere((s) => s is Unauthenticated);
      pending.complete(user.copyWith(name: 'محمد'));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state, const Unauthenticated());
      await bloc.close();
    },
  );
}
