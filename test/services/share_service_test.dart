import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:belly_buddy/models/data_share.dart';
import 'package:belly_buddy/models/dietitian_card.dart';
import 'package:belly_buddy/services/share_service.dart';

import '../helpers/mocks.dart';
import '../helpers/supabase_mocks.dart';

const _columns =
    'id, display_name, period, share_meals, share_drinks, share_gut, '
    'share_toilet, share_patterns, share_photos, failed_codes, locked_at, '
    'revoked_at, last_opened_at, open_count, expires_at, created_at, '
    'kind, dietitian_id, kept_by, '
    'dietitian:dietitians!data_shares_dietitian_id_fkey(name, profession, practice, town, blocked_at), '
    'keeper:dietitians!data_shares_kept_by_fkey(name, profession, practice, town, blocked_at)';

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
  'kind': 'link',
  'dietitian_id': null,
  'kept_by': null,
  'dietitian': null,
  'keeper': null,
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

const _terms = DietitianShareTerms(
  displayName: 'Julia Berger',
  period: SharePeriod.days14,
  duration: ShareDuration.open,
  meals: true,
  drinks: false,
  gut: true,
  toilet: false,
  patterns: true,
  photos: false,
);

const _termsBody = {
  'display_name': 'Julia Berger',
  'period': '14d',
  'duration': 'open',
  'meals': true,
  'drinks': false,
  'gut': true,
  'toilet': false,
  'patterns': true,
  'photos': false,
};

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
          details: {'error': 'Du hast bereits 5 aktive Freigaben.'},
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

  void stubAnswer(Object? data) => when(
    () => functions.invoke(any(), body: any(named: 'body')),
  ).thenAnswer((_) async => FunctionResponse(status: 200, data: data));

  void stubError(int status, String message) => when(
    () => functions.invoke(any(), body: any(named: 'body')),
  ).thenThrow(FunctionException(status: status, details: {'error': message}));

  Matcher failsWith(int status, String message) => throwsA(
    isA<ShareException>()
        .having((e) => e.status, 'status', status)
        .having((e) => e.message, 'message', message),
  );

  Map<dynamic, dynamic> sentBody(String path) =>
      verify(
            () => functions.invoke(path, body: captureAny(named: 'body')),
          ).captured.single
          as Map;

  group('columns', () {
    test('no hash column, no *, both embeds', () {
      expect(ShareService.columns, isNot(contains('*')));
      expect(ShareService.columns, isNot(contains('hash')));
      expect(
        ShareService.columns,
        contains('dietitian:dietitians!data_shares_dietitian_id_fkey('),
      );
      expect(
        ShareService.columns,
        contains('keeper:dietitians!data_shares_kept_by_fkey('),
      );
    });

    test('a listed connection parses with its embed', () async {
      final row = {
        ..._row('c1'),
        'kind': 'dietitian',
        'dietitian_id': 'd-1',
        'expires_at': null,
        'dietitian': {
          'name': 'Julia Berger',
          'profession': 'dietologin',
          'practice': null,
          'town': 'Innsbruck',
          'blocked_at': null,
        },
      };
      final fb = SettlableFilterBuilder(Future.value([row]));
      final qb = MockSupabaseQueryBuilder();
      when(() => client.from('data_shares')).thenAnswer((_) => qb);
      when(() => qb.select(any())).thenAnswer((_) => fb);
      when(
        () => fb.order(any(), ascending: any(named: 'ascending')),
      ).thenAnswer((_) => fb);

      final [share] = await service.list();

      expect(share.kind, ShareKind.dietitian);
      expect(share.expiresAt, isNull);
      expect(share.dietitian!.line, 'Diätolog:in (eigene Angabe) · Innsbruck');
    });
  });

  group('lookup', () {
    test('sends only the code and parses the card', () async {
      stubAnswer({
        'card': {
          'name': 'Julia Berger',
          'profession': 'dietologin',
          'practice': 'Praxis für Ernährungstherapie',
          'town': 'Innsbruck',
        },
      });

      final card = await service.lookup('BERGER-7K2');

      expect(card.name, 'Julia Berger');
      expect(card.profession, DietitianProfession.dietologin);
      expect(card.practice, 'Praxis für Ernährungstherapie');
      expect(card.isBlocked, isFalse);
      expect(sentBody('practice-code'), {'code': 'BERGER-7K2'});
    });

    test('404 carries core\'s message', () async {
      stubError(404, 'Diesen Code gibt es nicht. Bitte prüfe ihn.');
      await expectLater(
        service.lookup('BERGER-7K2'),
        failsWith(404, 'Diesen Code gibt es nicht. Bitte prüfe ihn.'),
      );
    });

    test('429 carries core\'s message', () async {
      stubError(429, 'Zu viele Versuche.');
      await expectLater(
        service.lookup('BERGER-7K2'),
        failsWith(429, 'Zu viele Versuche.'),
      );
    });

    test('an unreadable answer is a ShareException without status', () async {
      stubAnswer({'nope': true});
      await expectLater(
        service.lookup('BERGER-7K2'),
        throwsA(isA<ShareException>().having((e) => e.status, 's', isNull)),
      );
    });
  });

  group('connect', () {
    test('sends exactly the code and the terms, returns the id', () async {
      stubAnswer({'id': 'c1'});

      final id = await service.connect('BERGER-7K2', _terms);

      expect(id, 'c1');
      expect(sentBody('shares/dietitian'), {
        'code': 'BERGER-7K2',
        ..._termsBody,
      });
    });

    test('90 days is sent as 90d', () async {
      stubAnswer({'id': 'c1'});
      await service.connect(
        'BERGER-7K2',
        const DietitianShareTerms(
          displayName: 'J',
          period: SharePeriod.all,
          duration: ShareDuration.days90,
          meals: false,
          drinks: false,
          gut: false,
          toilet: false,
          patterns: false,
          photos: true,
        ),
      );
      final body = sentBody('shares/dietitian');
      expect(body['duration'], '90d');
      expect(body['period'], 'all');
    });

    test('404 / 409 / 429 carry core\'s message', () async {
      const cases = {
        404: 'Diesen Code gibt es nicht. Bitte prüfe ihn.',
        409:
            'Du hast 3 Berater:innen verbunden. Beende eine Verbindung, um '
            'eine neue hinzuzufügen.',
        429: 'Zu viele Versuche.',
      };
      for (final MapEntry(key: status, value: message) in cases.entries) {
        stubError(status, message);
        await expectLater(
          service.connect('BERGER-7K2', _terms),
          failsWith(status, message),
        );
      }
    });

    test('an answer without id is a ShareException', () async {
      stubAnswer({'ok': true});
      await expectLater(
        service.connect('BERGER-7K2', _terms),
        throwsA(isA<ShareException>().having((e) => e.status, 's', isNull)),
      );
    });
  });

  group('update', () {
    test('posts the terms without a code to shares/<id>/update', () async {
      stubAnswer({'ok': true});

      await service.update('c1', _terms);

      expect(sentBody('shares/c1/update'), _termsBody);
    });

    test('409 carries core\'s message', () async {
      stubError(409, 'Diese Verbindung ist schon beendet.');
      await expectLater(
        service.update('c1', _terms),
        failsWith(409, 'Diese Verbindung ist schon beendet.'),
      );
    });

    test('404 carries core\'s message', () async {
      stubError(404, 'Weg.');
      await expectLater(service.update('c1', _terms), failsWith(404, 'Weg.'));
    });
  });
}
