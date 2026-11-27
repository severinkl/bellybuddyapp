import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:belly_buddy/repositories/ingredient_repository.dart';

import '../helpers/mocks.dart';
import '../helpers/fixtures.dart';

void main() {
  late MockIngredientService ingredientService;
  late IngredientRepository repo;

  setUpAll(() => registerFallbackValue(DateTime(2026)));

  setUp(() {
    ingredientService = MockIngredientService();
    repo = IngredientRepository(ingredientService);
    when(
      () => ingredientService.fetchMealsSince(any(), any()),
    ).thenAnswer((_) async => []);
  });

  group('search', () {
    test(
      'delegates to ingredientService.search with userId and limit',
      () async {
        final suggestions = [
          testIngredientSearchResult(name: 'Zwiebel'),
          testIngredientSearchResult(id: 'ing-2', name: 'Zucchini'),
        ];
        when(
          () => ingredientService.search(
            any(),
            limit: any(named: 'limit'),
            userId: any(named: 'userId'),
          ),
        ).thenAnswer((_) async => suggestions);

        final result = await repo.search('Zwi', limit: 5, userId: testUserId);

        expect(result, equals(suggestions));
        verify(
          () => ingredientService.search('Zwi', limit: 5, userId: testUserId),
        ).called(1);
      },
    );
  });

  group('insertIfNew', () {
    test('delegates to ingredientService.insertIfNew with userId', () async {
      when(
        () =>
            ingredientService.insertIfNew(any(), userId: any(named: 'userId')),
      ).thenAnswer((_) async {});

      await repo.insertIfNew('Zwiebel', userId: testUserId);

      verify(
        () => ingredientService.insertIfNew('Zwiebel', userId: testUserId),
      ).called(1);
    });
  });

  group('deleteUserIngredient', () {
    test('delegates to ingredientService.deleteUserIngredient', () async {
      when(
        () => ingredientService.deleteUserIngredient(any()),
      ).thenAnswer((_) async {});

      await repo.deleteUserIngredient('ing-1');

      verify(() => ingredientService.deleteUserIngredient('ing-1')).called(1);
    });
  });

  group('fetchSuggestionGroups', () {
    test(
      'calls fetchSuggestions then fetchReplacements + fetchMealDetails in parallel',
      () async {
        final suggestionData = [
          {
            'id': 'sug-1',
            'detected_ingredient_id': 'ing-1',
            'meal_id': 'meal-1',
            'helptext': null,
            'seen_at': null,
            'dismissed_at': null,
            'ingredients': {
              'id': 'ing-1',
              'name': 'Zwiebel',
              'image_url': null,
            },
          },
        ];

        when(
          () => ingredientService.fetchSuggestions(any()),
        ).thenAnswer((_) async => suggestionData);
        when(
          () => ingredientService.fetchReplacements(any()),
        ).thenAnswer((_) async => []);
        when(
          () => ingredientService.fetchMealDetails(any()),
        ).thenAnswer((_) async => []);

        await repo.fetchSuggestionGroups(testUserId);

        verify(() => ingredientService.fetchSuggestions(testUserId)).called(1);
        verify(() => ingredientService.fetchReplacements(['sug-1'])).called(1);
        verify(() => ingredientService.fetchMealDetails(['meal-1'])).called(1);
      },
    );

    test(
      'passes correct IDs extracted from suggestion rows to secondary fetches',
      () async {
        final suggestionData = [
          {
            'id': 'sug-10',
            'detected_ingredient_id': 'ing-A',
            'meal_id': 'meal-X',
            'helptext': null,
            'seen_at': null,
            'dismissed_at': null,
            'ingredients': {
              'id': 'ing-A',
              'name': 'Knoblauch',
              'image_url': null,
            },
          },
          {
            'id': 'sug-20',
            'detected_ingredient_id': 'ing-B',
            'meal_id': 'meal-Y',
            'helptext': null,
            'seen_at': null,
            'dismissed_at': null,
            'ingredients': {
              'id': 'ing-B',
              'name': 'Brokkoli',
              'image_url': null,
            },
          },
        ];

        when(
          () => ingredientService.fetchSuggestions(any()),
        ).thenAnswer((_) async => suggestionData);

        List<String>? capturedSuggestionIds;
        List<String>? capturedMealIds;

        when(() => ingredientService.fetchReplacements(any())).thenAnswer((
          invocation,
        ) {
          capturedSuggestionIds =
              invocation.positionalArguments[0] as List<String>;
          return Future.value([]);
        });
        when(() => ingredientService.fetchMealDetails(any())).thenAnswer((
          invocation,
        ) {
          capturedMealIds = invocation.positionalArguments[0] as List<String>;
          return Future.value([]);
        });

        await repo.fetchSuggestionGroups(testUserId);

        expect(capturedSuggestionIds, containsAll(['sug-10', 'sug-20']));
        expect(capturedMealIds, containsAll(['meal-X', 'meal-Y']));
      },
    );

    group('ranking by the meals eaten afterwards', () {
      void stub() {
        when(() => ingredientService.fetchSuggestions(any())).thenAnswer(
          (_) async => [
            {
              'id': 'sug-1',
              'detected_ingredient_id': 'ing-1',
              'meal_id': null,
              'helptext': null,
              'seen_at': null,
              'created_at': '2026-11-01T10:00:00+00:00',
              'ingredients': {'id': 'ing-1', 'name': 'Milch'},
            },
          ],
        );
        when(() => ingredientService.fetchReplacements(any())).thenAnswer(
          (_) async => [
            for (final (id, name) in [('r1', 'Mandelmilch'), ('r2', 'Tofu')])
              {
                'suggestion_id': 'sug-1',
                'ingredients': {'id': id, 'name': name, 'image_url': null},
              },
          ],
        );
        when(
          () => ingredientService.fetchMealDetails(any()),
        ).thenAnswer((_) async => []);
      }

      test('reads the last 180 days and ranks the eaten ones first', () async {
        stub();
        when(() => ingredientService.fetchMealsSince(any(), any())).thenAnswer(
          (_) async => [
            {
              'id': 'm1',
              'tracked_at': '2026-11-05T12:00:00+00:00',
              'ingredients': ['Tofu (fest, natur)', 'Reis'],
            },
          ],
        );

        final groups = await repo.fetchSuggestionGroups(testUserId);

        final ranked = groups.single.replacements;
        expect([for (final r in ranked) r.id], ['r2', 'r1']);
        expect(ranked.first.eatenAfter, 1);
        final since =
            verify(
                  () => ingredientService.fetchMealsSince(
                    testUserId,
                    captureAny(),
                  ),
                ).captured.single
                as DateTime;
        final now = DateTime.now();
        expect(since, DateTime(now.year, now.month, now.day - 180));
      });

      test('failing meals: ranked without them', () async {
        stub();
        when(
          () => ingredientService.fetchMealsSince(any(), any()),
        ).thenThrow(Exception('offline'));

        final groups = await repo.fetchSuggestionGroups(testUserId);

        expect(
          [for (final r in groups.single.replacements) r.id],
          ['r1', 'r2'],
        );
      });
    });

    test('handles empty suggestion data and returns empty list', () async {
      when(
        () => ingredientService.fetchSuggestions(any()),
      ).thenAnswer((_) async => []);
      when(
        () => ingredientService.fetchReplacements(any()),
      ).thenAnswer((_) async => []);
      when(
        () => ingredientService.fetchMealDetails(any()),
      ).thenAnswer((_) async => []);

      final result = await repo.fetchSuggestionGroups(testUserId);

      expect(result, isEmpty);
    });
  });

  group('markAllSeen', () {
    test('delegates to ingredientService.markAllSeen', () async {
      when(() => ingredientService.markAllSeen(any())).thenAnswer((_) async {});

      await repo.markAllSeen(['sug-1', 'sug-2']);

      verify(() => ingredientService.markAllSeen(['sug-1', 'sug-2'])).called(1);
    });
  });

  group('dismissSuggestions', () {
    test('delegates to ingredientService.dismissSuggestions', () async {
      when(
        () => ingredientService.dismissSuggestions(any()),
      ).thenAnswer((_) async {});

      await repo.dismissSuggestions(['sug-1']);

      verify(() => ingredientService.dismissSuggestions(['sug-1'])).called(1);
    });
  });
}
