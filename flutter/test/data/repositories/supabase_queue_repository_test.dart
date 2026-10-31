import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:raghif/data/receipt_store.dart';
import 'package:raghif/data/repositories/supabase_queue_repository.dart';
import 'package:raghif/domain/models/purchase_model.dart';
import 'package:raghif/domain/repositories/queue_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('mapRpcError', () {
    test('the sold-out message becomes StoreSoldOutException', () {
      final error = SupabaseQueueRepository.mapRpcError(
        const PostgrestException(
          message: SupabaseQueueRepository.soldOutMessage,
        ),
      );

      expect(error, isA<StoreSoldOutException>());
    });

    test(
      'any other server error is a failed write, never a raw driver error',
      () {
        for (final message in [
          'already reserved a bag today',
          'not the store owner',
          'batch not notified yet',
          'permission denied for table profiles',
        ]) {
          final error = SupabaseQueueRepository.mapRpcError(
            PostgrestException(message: message),
          );

          expect(error, isA<BackendUnavailableException>(), reason: message);
        }
      },
    );

    test('"closed" inside another message is not mistaken for sold out', () {
      final error = SupabaseQueueRepository.mapRpcError(
        const PostgrestException(message: 'connection closed unexpectedly'),
      );

      expect(error, isA<BackendUnavailableException>());
    });
  });

  // A real SupabaseClient against a local HTTP server standing in for
  // PostgREST: every GET answers with [serverRows], or fails while [down].
  // The failure is a 400 because the client retries 5xx and socket errors
  // with backoff (~7s); the repository falls back on any failure alike.
  group('reads come from the server; the receipt is the offline fallback', () {
    late HttpServer server;
    late SupabaseClient client;
    late SupabaseQueueRepository repo;
    var serverRows = <Map<String, dynamic>>[];
    var down = false;
    Completer<void>? holdNextRead;
    Completer<void>? readCaptured;

    Future<void> authenticate(String id) => client.auth.setInitialSession(
      jsonEncode({
        'access_token':
            'eyJhbGciOiJIUzI1NiJ9.${base64Url.encode(utf8.encode(jsonEncode({'sub': id, 'exp': 4102444800}))).replaceAll('=', '')}.fixture',
        'token_type': 'bearer',
        'user': {
          'id': id,
          'aud': 'authenticated',
          'created_at': '2026-01-01T00:00:00Z',
        },
      }),
    );

    Map<String, dynamic> row({String date = '2026-10-03'}) => {
      'id': 'p1',
      'store_id': 's1',
      'user_id': 'u1',
      'purchase_date': date,
      'batch_number': 2,
      'status': 'notified',
      'created_at': '2026-10-03T10:00:00Z',
      'profiles': {
        'name': 'أحمد',
        'phone': '0599111111',
        'national_id': '900111222',
      },
      'stores': {'name': 'مخبز الرمال'},
    };

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      down = false;
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      holdNextRead = null;
      readCaptured = null;
      server.listen((req) async {
        if (down) {
          req.response
            ..statusCode = HttpStatus.badRequest
            ..close();
          return;
        }
        final body = jsonEncode(serverRows);
        final hold = holdNextRead;
        if (hold != null && req.uri.path == '/rest/v1/purchases') {
          holdNextRead = null;
          readCaptured?.complete();
          await hold.future;
        }
        req.response
          ..headers.contentType = ContentType.json
          ..write(body)
          ..close();
      });
      client = SupabaseClient('http://127.0.0.1:${server.port}', 'anon');
      await authenticate('u1');
      repo = SupabaseQueueRepository(client: client);
    });

    tearDown(() async {
      await server.close(force: true);
      await client.dispose();
    });

    test(
      "today's order comes from the server, names included, and is saved",
      () async {
        serverRows = [row()];

        final order = await repo.getBlockingPurchase('u1', '2026-10-03');

        expect(order?.batchNumber, 2);
        expect(order?.status, PurchaseStatus.notified);
        expect(order?.userName, 'أحمد');
        expect(order?.userNationalId, '900111222');
        expect(order?.storeName, 'مخبز الرمال');
        expect(await ReceiptStore().load(), order);
      },
    );

    test(
      'no signal: the saved receipt stands in, for that buyer and day only',
      () async {
        serverRows = [row()];
        final online = await repo.getBlockingPurchase('u1', '2026-10-03');
        down = true;

        expect(await repo.getBlockingPurchase('u1', '2026-10-03'), online);
        expect(await repo.getPurchaseById('p1'), online);
        expect(
          () => repo.getBlockingPurchase('u1', '2026-10-04'),
          throwsA(isA<BackendUnavailableException>()),
        );
        expect(
          () => repo.getBlockingPurchase('someone-else', '2026-10-03'),
          throwsA(isA<BackendUnavailableException>()),
        );
      },
    );

    test('an order gone from the server is gone from the phone too', () async {
      serverRows = [row()];
      await repo.getBlockingPurchase('u1', '2026-10-03');

      serverRows = [];
      expect(await repo.getBlockingPurchase('u1', '2026-10-03'), isNull);
      expect(await ReceiptStore().load(), isNull);
    });

    test('today check does not erase a postponed future receipt', () async {
      serverRows = [row(date: '2026-10-04')..['postponement_count'] = 1];
      final moved = await repo.currentOrUpcomingPurchase('u1', '2026-10-03');
      expect(moved?.purchaseDate, '2026-10-04');
      serverRows = [];
      expect(await repo.getBlockingPurchase('u1', '2026-10-03'), isNull);
      expect(await ReceiptStore().load(), moved);
      down = true;
      expect(await repo.currentOrUpcomingPurchase('u1', '2026-10-03'), moved);
      expect(
        repo.currentOrUpcomingPurchase('other', '2026-10-03'),
        throwsA(isA<BackendUnavailableException>()),
      );
    });

    test(
      'offline purchase reads require the active authenticated buyer',
      () async {
        serverRows = [row(date: '2026-10-04')..['postponement_count'] = 1];
        await repo.currentOrUpcomingPurchase('u1', '2026-10-03');
        down = true;
        final anonymous = SupabaseClient(
          'http://127.0.0.1:${server.port}',
          'anon',
        );
        addTearDown(anonymous.dispose);
        final loggedOutRepo = SupabaseQueueRepository(client: anonymous);
        await expectLater(
          loggedOutRepo.currentOrUpcomingPurchase('u1', '2026-10-03'),
          throwsA(isA<BackendUnavailableException>()),
        );
        await expectLater(
          loggedOutRepo.getBlockingPurchase('u1', '2026-10-04'),
          throwsA(isA<BackendUnavailableException>()),
        );
        await authenticate('other');
        await expectLater(
          repo.currentOrUpcomingPurchase('u1', '2026-10-03'),
          throwsA(isA<BackendUnavailableException>()),
        );
        await expectLater(
          repo.getBlockingPurchase('u1', '2026-10-04'),
          throwsA(isA<BackendUnavailableException>()),
        );
      },
    );

    test(
      'delayed old GET returns the moved receipt rather than reverting its date',
      () async {
        serverRows = [row()];
        final release = Completer<void>();
        holdNextRead = release;
        readCaptured = Completer<void>();
        final pending = repo.getPurchaseById('p1');
        await readCaptured!.future;
        final moved = SupabaseQueueRepository.purchaseFromRow(
          row(date: '2026-10-04')..['postponement_count'] = 1,
        );
        await ReceiptStore().save(moved);
        release.complete();
        expect(await pending, moved);
      },
    );

    test(
      'overlapping live GETs never emit an old date after the moved booking',
      () async {
        serverRows = [row()];
        final release = Completer<void>();
        holdNextRead = release;
        readCaptured = Completer<void>();
        final values = <PurchaseModel?>[];
        final emitted = Completer<void>();
        final subscription = repo.watchPurchaseById('p1').listen((value) {
          values.add(value);
          if (value?.postponementCount == 1 && !emitted.isCompleted) {
            emitted.complete();
          }
        });
        await readCaptured!.future;
        serverRows = [row(date: '2026-10-04')..['postponement_count'] = 1];
        await repo.refresh();
        await emitted.future.timeout(const Duration(seconds: 5));
        release.complete();
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await subscription.cancel();
        expect(values, isNotEmpty);
        expect(values.every((p) => p?.purchaseDate == '2026-10-04'), isTrue);
      },
    );

    test('other reads have no fallback: no server, no data', () async {
      down = true;

      expect(repo.getStores(), throwsA(isA<BackendUnavailableException>()));
      expect(
        repo.getQueueForStore('s1', '2026-10-03'),
        throwsA(isA<BackendUnavailableException>()),
      );
    });
  });
}
