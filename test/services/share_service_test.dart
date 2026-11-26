import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:belly_buddy/models/data_share.dart';
import 'package:belly_buddy/services/share_service.dart';

import '../helpers/mocks.dart';
import '../helpers/supabase_mocks.dart';

const _columns =
    'id, display_name, period, share_meals, share_drinks, share_gut, '
    'share_toilet, share_patterns, share_photos, failed_codes, locked_at, '
    'revoked_at, last_opened_at, open_count, expires_at, created_at';

Map<String, dynamic> _row(String id) => {
  'id': id,
  'display_name': 'Dr. Muster',
  'period': '14d',
  'share_meals': true,
  'share_drinks': true,
  'share_gut': true,
  'share_toilet': true,
  'share_patterns': false,
  'share_photos': false,
  'failed_codes': 0,
  'locked_at': null,
  'revoked_at': null,
  'last_opened_at': null,
  'open_count': 0,
  'expires_at': '2026-12-10T12:00:00Z',
  'created_at': '2026-11-20T10:00:00Z',
};

const _new = NewShare(
  displayName: 'Dr. Muster',
  period: SharePeriod.days30,
  validDays: 30,
  meals: true,
  drinks: true,
  gut: false,
  toilet: true,
  patterns: false,
  photos: true,
);

void main() {
  late MockSupabaseClient client;
  late MockFunctionsClient functions;
  late ShareService service;

  setUp(() {
    client = MockSupabaseClient();
    functions = mockFunctions(client);
    service = ShareService(client);
  });

  group('list', () {
    test('selects the explicit column list, never *, newest first', () async {
      final fb = SettlableFilterBuilder(Future.value([_row('a'), _row('b')]));
      final qb = MockSupabaseQueryBuilder();
      String? cols;
      when(() => client.from('data_shares')).thenAnswer((_) => qb);
      when(() => qb.select(any())).thenAnswer((inv) {
        cols = inv.positionalArguments.single as String;
        return fb;
      });
      when(
        () => fb.order(any(), ascending: any(named: 'ascending')),
      ).thenAnswer((_) => fb);

      final result = await service.list();

      expect(result.map((s) => s.id), ['a', 'b']);
      expect(cols, _columns);
      expect(cols!, isNot(contains('*')));
      expect(cols!, isNot(contains('hash')));
      verify(() => fb.order('created_at', ascending: false)).called(1);
    });
  });

  group('create', () {
    test('sends exactly the body keys and parses the answer', () async {
      when(() => functions.invoke(any(), body: any(named: 'body'))).thenAnswer(
        (_) async => const FunctionResponse(
          status: 200,
          data: {
            'id': 's1',
            'link': 'https://x.example/s/abc',
            'code': '123456',
            'expires_at': '2026-12-26T12:00:00Z',
          },
        ),
      );

      final created = await service.create(_new);

      expect(created.id, 's1');
      expect(created.link, 'https://x.example/s/abc');
      expect(created.code, '123456');
      expect(created.expiresAt, DateTime.utc(2026, 12, 26, 12));
      final body =
          verify(
                () =>
                    functions.invoke('shares', body: captureAny(named: 'body')),
              ).captured.single
              as Map;
      expect(body, {
        'display_name': 'Dr. Muster',
        'period': '30d',
        'valid_days': 30,
        'meals': true,
        'drinks': true,
        'gut': false,
        'toilet': true,
        'patterns': false,
        'photos': true,
      });
    });

    test('409 becomes ShareException with the German message', () async {
      when(() => functions.invoke(any(), body: any(named: 'body'))).thenThrow(
        const FunctionException(
          status: 409,
          details: {'message': 'Du hast bereits 5 aktive Freigaben.'},
        ),
      );

      await expectLater(
        service.create(_new),
        throwsA(
          isA<ShareException>()
              .having((e) => e.status, 'status', 409)
              .having(
                (e) => e.message,
                'message',
                'Du hast bereits 5 aktive Freigaben.',
              ),
        ),
      );
    });

    test('403 with a non-JSON body has a status and no message', () async {
      when(
        () => functions.invoke(any(), body: any(named: 'body')),
      ).thenThrow(const FunctionException(status: 403, details: 'Forbidden'));
      await expectLater(
        service.create(_new),
        throwsA(
          isA<ShareException>()
              .having((e) => e.status, 'status', 403)
              .having((e) => e.message, 'message', isNull),
        ),
      );
    });

    test('other failures become ShareException without status', () async {
      when(
        () => functions.invoke(any(), body: any(named: 'body')),
      ).thenThrow(Exception('offline'));
      await expectLater(
        service.create(_new),
        throwsA(isA<ShareException>().having((e) => e.status, 's', isNull)),
      );
    });
  });

  group('end', () {
    test('posts to shares/<id>/end', () async {
      when(() => functions.invoke(any())).thenAnswer(
        (_) async => const FunctionResponse(status: 200, data: {'ok': true}),
      );
      await service.end('s1');
      verify(() => functions.invoke('shares/s1/end')).called(1);
    });

    test('404 becomes ShareException(404)', () async {
      when(() => functions.invoke(any())).thenThrow(
        const FunctionException(status: 404, details: {'message': 'Weg.'}),
      );
      await expectLater(
        service.end('zzz'),
        throwsA(isA<ShareException>().having((e) => e.status, 's', 404)),
      );
    });
  });
}
