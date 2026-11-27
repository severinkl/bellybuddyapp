import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:belly_buddy/models/dietitian_card.dart';
import 'package:belly_buddy/models/dietitian_tip.dart';
import 'package:belly_buddy/services/dietitian_tip_service.dart';

import '../helpers/mocks.dart';
import '../helpers/supabase_mocks.dart';

const _table = 'dietitian_recommendations';

Map<String, dynamic> _row(String id, {String? seenAt, String? tryingAt}) => {
  'id': id,
  'sender_name': 'Julia Berger',
  'sender_profession': 'dietologin',
  'body': 'Probier <b>Haferflocken</b> 🌾\nam Morgen.',
  'created_at': '2026-11-26T08:00:00Z',
  'seen_at': seenAt,
  'trying_at': tryingAt,
};

/// Makes [filter] answer an awaited write: no rows, or [error].
void _stubFilterFuture(MockPostgrestFilterBuilder filter, {Object? error}) {
  when(
    () => filter.then<dynamic>(any(), onError: any(named: 'onError')),
  ).thenAnswer((inv) {
    final onValue = inv.positionalArguments[0] as Function;
    final onError = inv.namedArguments[#onError] as Function?;
    final answer = error == null
        ? Future<PostgrestList>.value([])
        : Future<PostgrestList>.error(error);
    return answer.then((v) => onValue(v), onError: onError);
  });
}

/// `client.from(_table).update(values)`: the filter builder, and the
/// values of the update once made.
(MockPostgrestFilterBuilder, Map<dynamic, dynamic>? Function()) _mockUpdate(
  MockSupabaseClient client,
) {
  final qb = MockSupabaseQueryBuilder();
  final fb = MockPostgrestFilterBuilder();
  Map<dynamic, dynamic>? values;
  when(() => client.from(_table)).thenAnswer((_) => qb);
  when(() => qb.update(any())).thenAnswer((inv) {
    values = inv.positionalArguments.single as Map;
    return fb;
  });
  return (fb, () => values);
}

void main() {
  late MockSupabaseClient client;
  late DietitianTipService service;

  setUp(() {
    client = MockSupabaseClient();
    service = DietitianTipService(client);
  });

  group('DietitianTip', () {
    test('parses, keeps the body as typed, round trips', () {
      final tip = DietitianTip.fromJson(_row('t1'));
      expect(tip.senderName, 'Julia Berger');
      expect(tip.senderProfession, DietitianProfession.dietologin);
      expect(tip.body, 'Probier <b>Haferflocken</b> 🌾\nam Morgen.');
      expect(tip.createdAt, DateTime.utc(2026, 11, 26, 8));
      expect(tip.isNew, isTrue);
      expect(DietitianTip.fromJson(tip.toJson()), tip);
      expect(tip.toJson()['sender_profession'], 'dietologin');
    });

    test('seen is not new', () {
      final tip = DietitianTip.fromJson(
        _row('t1', seenAt: '2026-11-26T09:00:00Z'),
      );
      expect(tip.isNew, isFalse);
      expect(tip.seenAt, DateTime.utc(2026, 11, 26, 9));
    });

    test('an unknown profession key reads „Andere"', () {
      final tip = DietitianTip.fromJson({
        ..._row('t1'),
        'sender_profession': 'zauberin',
      });
      expect(tip.senderProfession, DietitianProfession.andere);
    });
  });

  group('list', () {
    test('explicit columns, newest first', () async {
      final fb = SettlableFilterBuilder(Future.value([_row('a'), _row('b')]));
      final qb = MockSupabaseQueryBuilder();
      String? cols;
      when(() => client.from(_table)).thenAnswer((_) => qb);
      when(() => qb.select(any())).thenAnswer((inv) {
        cols = inv.positionalArguments.single as String;
        return fb;
      });
      when(
        () => fb.order(any(), ascending: any(named: 'ascending')),
      ).thenAnswer((_) => fb);

      final tips = await service.list();

      expect(tips.map((t) => t.id), ['a', 'b']);
      expect(cols, DietitianTipService.columns);
      expect(
        cols,
        'id, sender_name, sender_profession, body, created_at, seen_at, '
        'trying_at',
      );
      verify(() => fb.order('created_at', ascending: false)).called(1);
    });
  });

  group('markSeen', () {
    test('stamps only the given ids not seen yet', () async {
      final (fb, sent) = _mockUpdate(client);
      when(() => fb.inFilter(any(), any())).thenAnswer((_) => fb);
      when(() => fb.isFilter(any(), any())).thenAnswer((_) => fb);
      _stubFilterFuture(fb);

      await service.markSeen(['t1', 't2']);

      final update = sent()!;
      expect(update.keys, ['seen_at']);
      expect(DateTime.parse(update['seen_at'] as String).isUtc, isTrue);
      verify(() => fb.inFilter('id', ['t1', 't2'])).called(1);
      verify(() => fb.isFilter('seen_at', null)).called(1);
    });

    test('no ids: no call', () async {
      await service.markSeen([]);
      verifyNever(() => client.from(any()));
    });

    test('a failure is rethrown', () async {
      final (fb, _) = _mockUpdate(client);
      when(() => fb.inFilter(any(), any())).thenAnswer((_) => fb);
      when(() => fb.isFilter(any(), any())).thenAnswer((_) => fb);
      _stubFilterFuture(fb, error: Exception('offline'));
      await expectLater(service.markSeen(['t1']), throwsException);
    });
  });

  group('setTrying', () {
    test('on: trying_at now', () async {
      final (fb, sent) = _mockUpdate(client);
      when(() => fb.eq(any(), any())).thenAnswer((_) => fb);
      _stubFilterFuture(fb);

      await service.setTrying('t1', true);

      final update = sent()!;
      expect(update.keys, ['trying_at']);
      expect(update['trying_at'], isA<String>());
      verify(() => fb.eq('id', 't1')).called(1);
    });

    test('off: trying_at null', () async {
      final (fb, sent) = _mockUpdate(client);
      when(() => fb.eq(any(), any())).thenAnswer((_) => fb);
      _stubFilterFuture(fb);

      await service.setTrying('t1', false);

      final update = sent()!;
      expect(update, {'trying_at': null});
      verify(() => fb.eq('id', 't1')).called(1);
    });
  });

  group('remove', () {
    test('deletes the row by id', () async {
      final fb = mockDelete(client, table: _table);
      when(() => fb.eq(any(), any())).thenAnswer((_) => fb);
      _stubFilterFuture(fb);

      await service.remove('t1');

      verify(() => fb.eq('id', 't1')).called(1);
    });

    test('a failure is rethrown', () async {
      final fb = mockDelete(client, table: _table);
      when(() => fb.eq(any(), any())).thenAnswer((_) => fb);
      _stubFilterFuture(fb, error: Exception('offline'));
      await expectLater(service.remove('t1'), throwsException);
    });
  });
}
