import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:raghif/data/repositories/supabase_queue_repository.dart';
import 'package:raghif/domain/models/purchase_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/fake_queue_repository.dart';

void main() {
  const today = '2026-10-27';
  const tomorrow = '2026-10-28';

  test(
    'fake prioritizes upcoming waiting booking over collected today',
    () async {
      final repository = FakeQueueRepository.seeded();
      addTearDown(repository.dispose);
      repository.givenPurchase(
        userId: 'user-buyer',
        storeId: 'store-rimal',
        date: today,
        status: PurchaseStatus.collected,
      );
      final upcoming = repository.givenPurchase(
        userId: 'user-buyer',
        storeId: 'store-rimal',
        date: tomorrow,
      );
      expect(
        await repository.currentOrUpcomingPurchase('user-buyer', today),
        upcoming,
      );
    },
  );

  group('server purchase priority', () {
    late HttpServer server;
    late SupabaseClient client;
    late SupabaseQueueRepository repository;
    var rows = <Map<String, dynamic>>[];
    Map<String, dynamic> row(String id, String date, String status) => {
      'id': id,
      'store_id': 's1',
      'user_id': 'u1',
      'purchase_date': date,
      'batch_number': 1,
      'status': status,
      'created_at': '2026-10-27T08:00:00Z',
    };
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      rows = [];
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) {
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(rows));
        request.response.close();
      });
      client = SupabaseClient('http://127.0.0.1:${server.port}', 'anon');
      await client.auth.setInitialSession(
        jsonEncode({
          'access_token':
              'eyJhbGciOiJIUzI1NiJ9.${base64Url.encode(utf8.encode(jsonEncode({'sub': 'u1', 'exp': 4102444800}))).replaceAll('=', '')}.fixture',
          'token_type': 'bearer',
          'user': {
            'id': 'u1',
            'aud': 'authenticated',
            'created_at': '2026-01-01T00:00:00Z',
          },
        }),
      );
      repository = SupabaseQueueRepository(client: client);
    });
    tearDown(() async {
      await server.close(force: true);
      await client.dispose();
    });

    test(
      'upcoming waiting booking stays visible after collecting a new booking today',
      () async {
        rows = [
          row('collected-today', today, 'collected'),
          row('postponed-tomorrow', tomorrow, 'waiting'),
        ];
        expect(
          (await repository.currentOrUpcomingPurchase('u1', today))?.id,
          'postponed-tomorrow',
        );
      },
    );
    test(
      'collected today remains visible when no uncollected booking exists',
      () async {
        rows = [
          row('collected-today', today, 'collected'),
          row('collected-future', tomorrow, 'collected'),
        ];
        expect(
          (await repository.currentOrUpcomingPurchase('u1', today))?.id,
          'collected-today',
        );
      },
    );
    test(
      'uncollected today takes priority over uncollected tomorrow',
      () async {
        rows = [
          row('waiting-today', today, 'waiting'),
          row('postponed-tomorrow', tomorrow, 'waiting'),
        ];
        expect(
          (await repository.currentOrUpcomingPurchase('u1', today))?.id,
          'waiting-today',
        );
      },
    );
  });
}
