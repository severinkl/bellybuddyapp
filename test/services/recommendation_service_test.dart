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
}
