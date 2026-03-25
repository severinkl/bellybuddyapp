import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

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
      when(
        () => fb.order(any(), ascending: any(named: 'ascending')),
      ).thenAnswer((_) => fb);

      final result = await service.fetchByUserId(testUserId);

      expect(result, isEmpty);
    });

    test('orders by created_at descending', () async {
      final fb = mockSelectRows(client, table: 'recommendations', rows: []);
      when(() => fb.eq(any(), any())).thenAnswer((_) => fb);
      when(
        () => fb.order(any(), ascending: any(named: 'ascending')),
      ).thenAnswer((_) => fb);

      await service.fetchByUserId(testUserId);

      verify(() => fb.order('created_at', ascending: false)).called(1);
    });

    test('filters by user_id', () async {
      final fb = mockSelectRows(client, table: 'recommendations', rows: []);
      when(() => fb.eq(any(), any())).thenAnswer((_) => fb);
      when(
        () => fb.order(any(), ascending: any(named: 'ascending')),
      ).thenAnswer((_) => fb);

      await service.fetchByUserId(testUserId);

      verify(() => fb.eq('user_id', testUserId)).called(1);
    });
  });

  group('RecommendationService.fetchRecentContext', () {
    /// Sets up settled filter builders for both meal_entries and toilet_entries
    /// so that Future.wait resolves correctly.
    ({SettlableFilterBuilder meals, SettlableFilterBuilder toilet})
    setupBothTables({
      List<Map<String, dynamic>> mealRows = const [],
      List<Map<String, dynamic>> toiletRows = const [],
    }) {
      final meals = mockSelectRows(
        client,
        table: 'meal_entries',
        rows: mealRows,
      );
      final toilet = mockSelectRows(
        client,
        table: 'toilet_entries',
        rows: toiletRows,
      );

      for (final f in [meals, toilet]) {
        when(() => f.eq(any(), any())).thenAnswer((_) => f);
        when(() => f.gte(any(), any())).thenAnswer((_) => f);
        when(
          () => f.order(any(), ascending: any(named: 'ascending')),
        ).thenAnswer((_) => f);
        when(() => f.limit(any())).thenAnswer((_) => f);
      }

      return (meals: meals, toilet: toilet);
    }

    test('returns map with recentMeals and recentToilet keys', () async {
      setupBothTables(
        mealRows: [
          {'title': 'Frühstück', 'ingredients': <dynamic>[]},
        ],
        toiletRows: [
          {'stool_type': 4},
        ],
      );

      final result = await service.fetchRecentContext(testUserId);

      expect(result.containsKey('recentMeals'), isTrue);
      expect(result.containsKey('recentToilet'), isTrue);
    });

    test('returns meal and toilet data within 7-day window', () async {
      setupBothTables(
        mealRows: [
          {'title': 'Mittagessen', 'ingredients': <dynamic>[]},
          {'title': 'Abendbrot', 'ingredients': <dynamic>[]},
        ],
        toiletRows: [
          {'stool_type': 3},
        ],
      );

      final result = await service.fetchRecentContext(testUserId);

      expect(result['recentMeals'], hasLength(2));
      expect(result['recentToilet'], hasLength(1));
    });

    test('filters both queries by user_id', () async {
      final tables = setupBothTables();

      await service.fetchRecentContext(testUserId);

      verify(() => tables.meals.eq('user_id', testUserId)).called(1);
      verify(() => tables.toilet.eq('user_id', testUserId)).called(1);
    });

    test('applies gte filter for 7-day window on both tables', () async {
      final tables = setupBothTables();

      await service.fetchRecentContext(testUserId);

      verify(() => tables.meals.gte('created_at', any())).called(1);
      verify(() => tables.toilet.gte('created_at', any())).called(1);
    });
  });
}
