import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestList;

import 'package:belly_buddy/services/recommendation_service.dart';

import '../helpers/fixtures.dart';
import '../helpers/mocks.dart';
import '../helpers/supabase_mocks.dart';

Map<String, dynamic> _recommendationRow({
  String id = 'rec-1',
  String userId = testUserId,
  String? summary = 'Tipp: Mehr Wasser trinken.',
}) => {
  'id': id,
  'user_id': userId,
  'summary': summary,
  'recommendations': <dynamic>[],
  'created_at': null,
};

/// Makes [filter] answer an awaited update: no rows, or [error].
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

void main() {
  late MockSupabaseClient client;
  late RecommendationService service;

  setUp(() {
    client = MockSupabaseClient();
    service = RecommendationService(client);
  });

  group('RecommendationService.fetchByUserId', () {
    test('returns list of Recommendation sorted by created_at desc', () async {
      final fb = mockSelectRows(
        client,
        table: 'recommendations',
        rows: [
          _recommendationRow(id: 'rec-1'),
          _recommendationRow(id: 'rec-2', summary: 'Zweiter Tipp'),
        ],
      );
      when(() => fb.eq(any(), any())).thenAnswer((_) => fb);
      when(() => fb.neq(any(), any())).thenAnswer((_) => fb);
      when(
        () => fb.order(any(), ascending: any(named: 'ascending')),
      ).thenAnswer((_) => fb);

      final result = await service.fetchByUserId(testUserId);

      expect(result, hasLength(2));
      expect(result.first.id, 'rec-1');
      expect(result.first.summary, 'Tipp: Mehr Wasser trinken.');
    });

    test('returns empty list when no recommendations exist', () async {
      final fb = mockSelectRows(client, table: 'recommendations', rows: []);
      when(() => fb.eq(any(), any())).thenAnswer((_) => fb);
      when(() => fb.neq(any(), any())).thenAnswer((_) => fb);
      when(
        () => fb.order(any(), ascending: any(named: 'ascending')),
      ).thenAnswer((_) => fb);

      final result = await service.fetchByUserId(testUserId);

      expect(result, isEmpty);
    });

    test('orders by created_at descending', () async {
      final fb = mockSelectRows(client, table: 'recommendations', rows: []);
      when(() => fb.eq(any(), any())).thenAnswer((_) => fb);
      when(() => fb.neq(any(), any())).thenAnswer((_) => fb);
      when(
        () => fb.order(any(), ascending: any(named: 'ascending')),
      ).thenAnswer((_) => fb);

      await service.fetchByUserId(testUserId);

      verify(() => fb.order('created_at', ascending: false)).called(1);
    });

    test('filters by user_id', () async {
      final fb = mockSelectRows(client, table: 'recommendations', rows: []);
      when(() => fb.eq(any(), any())).thenAnswer((_) => fb);
      when(() => fb.neq(any(), any())).thenAnswer((_) => fb);
      when(
        () => fb.order(any(), ascending: any(named: 'ascending')),
      ).thenAnswer((_) => fb);

      await service.fetchByUserId(testUserId);

      verify(() => fb.eq('user_id', testUserId)).called(1);
    });
  });

  group('RecommendationService.markSeen', () {
    test(
      'stamps only the given sets, those of the user not seen yet',
      () async {
        final fb = mockUpdate(client, table: 'recommendations');
        when(() => fb.eq(any(), any())).thenAnswer((_) => fb);
        when(() => fb.inFilter(any(), any())).thenAnswer((_) => fb);
        when(() => fb.isFilter(any(), any())).thenAnswer((_) => fb);
        _stubFilterFuture(fb);

        await service.markSeen(testUserId, ['rec-1', 'rec-2']);

        verify(
          () => client
              .from('recommendations')
              .update(any(that: containsPair('seen_at', isA<String>()))),
        ).called(1);
        verify(() => fb.eq('user_id', testUserId)).called(1);
        verify(() => fb.inFilter('id', ['rec-1', 'rec-2'])).called(1);
        verify(() => fb.isFilter('seen_at', null)).called(1);
      },
    );

    test('no ids: no call', () async {
      await service.markSeen(testUserId, []);
      verifyNever(() => client.from(any()));
    });

    test('a failure is rethrown', () async {
      final fb = mockUpdate(client, table: 'recommendations');
      when(() => fb.eq(any(), any())).thenAnswer((_) => fb);
      when(() => fb.inFilter(any(), any())).thenAnswer((_) => fb);
      when(() => fb.isFilter(any(), any())).thenAnswer((_) => fb);
      _stubFilterFuture(fb, error: Exception('offline'));

      await expectLater(
        service.markSeen(testUserId, ['rec-1']),
        throwsException,
      );
    });
  });
}
