import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raghif/domain/models/user_model.dart';
import 'package:raghif/features/account/account_screen.dart';
import 'package:raghif/features/auth/bloc/auth_bloc.dart';

import '../../support/fake_auth_repository.dart';

void main() {
  const channel = MethodChannel('plugins.flutter.io/url_launcher');
  const user = UserModel(
    id: 'contact-buyer',
    name: 'مستخدم',
    phone: '0599111111',
    nationalId: '900111222',
  );

  Future<void> openAccount(WidgetTester tester) async {
    final repository = FakeAuthRepository(
      users: [user],
      sessionUserId: user.id,
    );
    final bloc = AuthBloc(authRepository: repository);
    addTearDown(bloc.close);
    bloc.add(const CheckAuthSessionEvent());
    await tester.pumpWidget(
      BlocProvider.value(
        value: bloc,
        child: const MaterialApp(home: AccountScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('contact button opens the new WhatsApp number externally', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return true;
        });
    await openAccount(tester);
    expect(find.text('تواصل معنا'), findsOneWidget);
    await tester.ensureVisible(find.text('تواصل معنا'));
    await tester.tap(find.text('تواصل معنا'));
    await tester.pumpAndSettle();
    expect(calls, hasLength(1));
    expect(calls.single.method, 'launch');
    expect(calls.single.arguments['url'], 'https://wa.me/972567561147');
    expect(calls.single.arguments['useWebView'], isFalse);
    expect(calls.single.arguments['useSafariVC'], isFalse);
    expect(find.text('تعذر فتح واتساب. حاول مرة أخرى.'), findsNothing);
  });

  for (final throwsError in [false, true]) {
    testWidgets('failed contact launch shows retry feedback ($throwsError)', (
      tester,
    ) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async {
            if (throwsError) throw PlatformException(code: 'unavailable');
            return false;
          });
      await openAccount(tester);
      expect(find.text('تواصل معنا'), findsOneWidget);
      await tester.ensureVisible(find.text('تواصل معنا'));
      await tester.tap(find.text('تواصل معنا'));
      await tester.pumpAndSettle();
      expect(find.text('تعذر فتح واتساب. حاول مرة أخرى.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
