import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:belly_buddy/models/first_tip.dart';
import 'package:belly_buddy/services/recommendation_service.dart';

import '../helpers/fixtures.dart';
import '../helpers/logs.dart';
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

/// An item of a `diet-recommendations` answer.
Map<String, dynamic> _item(String ingredient) => {
  'type': 'try',
  'ingredient': ingredient,
  'reason': 'Grund',
  'alternative': null,
  'focus': false,
  'recipe_id': null,
  'recipe_title': null,
};

/// The meal the first-tip tests send: late in the evening, wall clock.
final _meal = testMealEntry(
  trackedAt: DateTime(2026, 11, 23, 23, 30),
  title: 'Zwiebelsuppe',
  ingredients: ['Zwiebel', 'Brot'],
);

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

  group('RecommendationService.requestFirstTip', () {
    late MockFunctionsClient functions;

    setUp(() {
      functions = mockFunctions(client);
    });

    void stubAnswer(Object? data) => when(
      () => functions.invoke(any(), body: any(named: 'body')),
    ).thenAnswer((_) async => FunctionResponse(data: data, status: 200));

    void stubThrow(Object error) => when(
      () => functions.invoke(any(), body: any(named: 'body')),
    ).thenThrow(error);

    Future<FirstTipResult> request() => service.requestFirstTip(
      intolerances: ['Fruktose', 'Laktose'],
      diet: 'vegetarisch',
      meals: [_meal],
    );

    Matcher failsWith(int? status) => throwsA(
      isA<FirstTipException>().having((e) => e.status, 'status', status),
    );

    test('the body is exactly intolerances, diet and recentMeals', () async {
      stubAnswer({
        'id': 'set-1',
        'summary': 'Brief',
        'recommendations': [_item('Reis')],
      });

      await request();

      final captured = verify(
        () => functions.invoke(
          RecommendationService.firstTipFunction,
          body: captureAny(named: 'body'),
        ),
      ).captured;
      expect(RecommendationService.firstTipFunction, 'diet-recommendations');
      expect(captured.single, {
        'intolerances': ['Fruktose', 'Laktose'],
        'diet': 'vegetarisch',
        'recentMeals': [
          {
            'title': 'Zwiebelsuppe',
            'ingredients': ['Zwiebel', 'Brot'],
            'tracked_at': '2026-11-23T23:30:00.000Z',
          },
        ],
      });
    });

    test('no diet: sent as null', () async {
      stubAnswer({'id': 'set-1', 'recommendations': <dynamic>[]});

      await service.requestFirstTip(intolerances: [], diet: null, meals: []);

      final captured = verify(
        () => functions.invoke(any(), body: captureAny(named: 'body')),
      ).captured;
      expect(captured.single, {
        'intolerances': <String>[],
        'diet': null,
        'recentMeals': <Object>[],
      });
    });

    test('answer with id and 2 items → ok', () async {
      stubAnswer({
        'id': 'set-1',
        'summary': 'Mir ist aufgefallen, …',
        'recommendations': [_item('Reis'), _item('Hafer')],
        'created_at': '2026-11-24T10:00:00+00:00',
      });

      final result = await request();

      expect(result.id, 'set-1');
      expect(result.tips, 2);
      expect(result.ok, isTrue);
    });

    test('200 fallback without items → tips 0, not ok', () async {
      stubAnswer({
        'id': 'set-2',
        'summary': 'Leider konnte keine Analyse durchgeführt werden.',
        'recommendations': <dynamic>[],
        'created_at': '2026-11-24T10:00:00+00:00',
      });

      final result = await request();

      expect(result.id, 'set-2');
      expect(result.tips, 0);
      expect(result.ok, isFalse);
    });

    test('no id → not ok', () async {
      // Saving the set failed: core answers without `id`.
      stubAnswer({
        'summary': 'Mir ist aufgefallen, …',
        'recommendations': [_item('Reis'), _item('Hafer')],
      });

      final result = await request();

      expect(result.id, isNull);
      expect(result.tips, 2);
      expect(result.ok, isFalse);
    });

    test('429 → FirstTipException(429)', () async {
      stubThrow(
        const FunctionsHttpException(
          status: 429,
          details: {'error': 'Rate limit exceeded. Please try again later.'},
        ),
      );

      await expectLater(request(), failsWith(429));
    });

    test('500 → FirstTipException(500), logged by the caller only', () async {
      final logs = captureLogs();
      stubThrow(
        const FunctionsHttpException(
          status: 500,
          details: {'error': 'Failed to generate recommendations'},
        ),
      );

      await expectLater(request(), failsWith(500));
      expect(logs, isEmpty);
    });

    test('transport → FirstTipException(null)', () async {
      stubThrow(const FunctionsFetchException(details: 'offline'));

      await expectLater(request(), failsWith(null));
    });

    test(
      'a non-map answer → FirstTipException(null), nothing logged',
      () async {
        final logs = captureLogs();
        stubAnswer('Zwiebelsuppe mit Brot');

        await expectLater(request(), failsWith(null));
        expect(logs, isEmpty);
      },
    );

    test('an id that is not a string → FirstTipException(null)', () async {
      stubAnswer({
        'id': 7,
        'recommendations': [_item('Reis')],
      });

      await expectLater(request(), failsWith(null));
    });
  });
}
