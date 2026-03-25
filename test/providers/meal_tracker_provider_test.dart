import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/meal_tracker_provider.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';
import 'package:belly_buddy/repositories/ingredient_repository.dart';
import 'package:belly_buddy/repositories/meal_media_repository.dart';
import 'package:belly_buddy/services/ingredient_service.dart';

import '../helpers/fixtures.dart';
import '../helpers/mocks.dart';
import '../helpers/riverpod_helpers.dart';

void main() {
  late MockMealMediaRepository mockMealMediaRepo;
  late MockIngredientRepository mockIngredientRepo;
  late MockEntryRepository mockEntryRepo;

  setUp(() {
    mockMealMediaRepo = MockMealMediaRepository();
    mockIngredientRepo = MockIngredientRepository();
    mockEntryRepo = MockEntryRepository();
    registerFallbackValue(testMealEntry());
    registerFallbackValue(Uint8List(0));
  });

  ProviderContainer makeContainer({String? userId = testUserId}) =>
      createContainer(
        overrides: [
          mealMediaRepositoryProvider.overrideWithValue(mockMealMediaRepo),
          ingredientRepositoryProvider.overrideWithValue(mockIngredientRepo),
          entryRepositoryProvider.overrideWithValue(mockEntryRepo),
          currentUserIdProvider.overrideWithValue(userId),
        ],
      );

  group('MealTrackerNotifier.setTitle', () {
    test('updates title in state', () {
      final container = makeContainer();
      container.read(mealTrackerProvider.notifier).setTitle('Pizza');
      expect(container.read(mealTrackerProvider).title, equals('Pizza'));
    });
  });

  group('MealTrackerNotifier.setNotes', () {
    test('updates notes in state', () {
      final container = makeContainer();
      container.read(mealTrackerProvider.notifier).setNotes('Notiz');
      expect(container.read(mealTrackerProvider).notes, equals('Notiz'));
    });
  });

  group('MealTrackerNotifier.setTrackedAt', () {
    test('updates trackedAt in state', () {
      final container = makeContainer();
      final dt = DateTime(2026, 1, 1, 10, 0);
      container.read(mealTrackerProvider.notifier).setTrackedAt(dt);
      expect(container.read(mealTrackerProvider).trackedAt, equals(dt));
    });
  });

  group('MealTrackerNotifier.analyzeImage', () {
    test(
      'sets isAnalyzing, calls repo, then updates title and ingredients',
      () async {
        final bytes = Uint8List.fromList([1, 2, 3]);
        when(() => mockMealMediaRepo.analyzeMealImage(any(), any())).thenAnswer(
          (_) async => {
            'title': 'Analysiertes Gericht',
            'ingredients': ['Tomate', 'Käse'],
          },
        );

        final container = makeContainer();
        await container
            .read(mealTrackerProvider.notifier)
            .analyzeImage(bytes, 'photo.jpg');

        final state = container.read(mealTrackerProvider);
        expect(state.title, equals('Analysiertes Gericht'));
        expect(state.ingredients, containsAll(['Tomate', 'Käse']));
        expect(state.isAnalyzing, isFalse);
      },
    );

    test('clears isAnalyzing on error and rethrows', () async {
      final bytes = Uint8List.fromList([1, 2, 3]);
      when(
        () => mockMealMediaRepo.analyzeMealImage(any(), any()),
      ).thenThrow(Exception('analyze failed'));

      final container = makeContainer();

      await expectLater(
        () => container
            .read(mealTrackerProvider.notifier)
            .analyzeImage(bytes, 'photo.jpg'),
        throwsA(isA<Exception>()),
      );

      expect(container.read(mealTrackerProvider).isAnalyzing, isFalse);
    });
  });

  group('MealTrackerNotifier.searchIngredients', () {
    test('returns empty list when query is less than 3 characters', () async {
      final container = makeContainer();
      await container
          .read(mealTrackerProvider.notifier)
          .searchIngredients('ab');

      expect(
        container.read(mealTrackerProvider).ingredientSuggestions,
        isEmpty,
      );
      verifyNever(
        () => mockIngredientRepo.search(any(), userId: any(named: 'userId')),
      );
    });

    test('calls repo.search for query of 3+ characters', () async {
      when(
        () => mockIngredientRepo.search(any(), userId: any(named: 'userId')),
      ).thenAnswer(
        (_) async => [
          const IngredientSuggestion(id: 'i-1', name: 'Zwiebel', isOwn: false),
        ],
      );

      final container = makeContainer();
      await container
          .read(mealTrackerProvider.notifier)
          .searchIngredients('Zwi');

      final state = container.read(mealTrackerProvider);
      expect(state.ingredientSuggestions, hasLength(1));
      expect(state.ingredientSuggestions.first.name, equals('Zwiebel'));
    });
  });

  group('MealTrackerNotifier.addIngredient', () {
    test('adds ingredient to list', () {
      when(
        () =>
            mockIngredientRepo.insertIfNew(any(), userId: any(named: 'userId')),
      ).thenAnswer((_) async {});

      final container = makeContainer();
      container.read(mealTrackerProvider.notifier).addIngredient('Tomate');

      expect(
        container.read(mealTrackerProvider).ingredients,
        contains('Tomate'),
      );
    });

    test('skips duplicate ingredients', () {
      when(
        () =>
            mockIngredientRepo.insertIfNew(any(), userId: any(named: 'userId')),
      ).thenAnswer((_) async {});

      final container = makeContainer();
      final notifier = container.read(mealTrackerProvider.notifier);
      notifier.addIngredient('Tomate');
      notifier.addIngredient('Tomate');

      expect(
        container
            .read(mealTrackerProvider)
            .ingredients
            .where((i) => i == 'Tomate'),
        hasLength(1),
      );
    });
  });

  group('MealTrackerNotifier.save', () {
    test('with image: uploads image then creates entry', () async {
      final bytes = Uint8List.fromList([1, 2, 3]);

      when(
        () => mockMealMediaRepo.uploadMealImage(
          userId: any(named: 'userId'),
          fileBytes: any(named: 'fileBytes'),
          extension: any(named: 'extension'),
        ),
      ).thenAnswer((_) async => 'https://example.com/image.jpg');

      when(
        () => mockEntryRepo.insertEntry(
          any(),
          any(),
          userId: any(named: 'userId'),
        ),
      ).thenAnswer((_) async {});

      // triggerSuggestionRefresh is void (fire-and-forget)
      when(() => mockMealMediaRepo.triggerSuggestionRefresh()).thenReturn(null);

      final container = makeContainer();
      final notifier = container.read(mealTrackerProvider.notifier);
      notifier.setImage(bytes, 'photo.jpg');

      await notifier.save();

      verify(
        () => mockMealMediaRepo.uploadMealImage(
          userId: testUserId,
          fileBytes: bytes,
          extension: 'jpg',
        ),
      ).called(1);
      verify(
        () => mockEntryRepo.insertEntry(any(), any(), userId: testUserId),
      ).called(1);

      expect(container.read(mealTrackerProvider).showSuccess, isTrue);
      expect(container.read(mealTrackerProvider).isSaving, isFalse);
    });

    test('without image: skips upload, creates entry', () async {
      when(
        () => mockEntryRepo.insertEntry(
          any(),
          any(),
          userId: any(named: 'userId'),
        ),
      ).thenAnswer((_) async {});

      when(() => mockMealMediaRepo.triggerSuggestionRefresh()).thenReturn(null);

      final container = makeContainer();
      await container.read(mealTrackerProvider.notifier).save();

      verifyNever(
        () => mockMealMediaRepo.uploadMealImage(
          userId: any(named: 'userId'),
          fileBytes: any(named: 'fileBytes'),
          extension: any(named: 'extension'),
        ),
      );
      verify(
        () => mockEntryRepo.insertEntry(any(), any(), userId: testUserId),
      ).called(1);
    });

    test('calls triggerSuggestionRefresh after save', () async {
      when(
        () => mockEntryRepo.insertEntry(
          any(),
          any(),
          userId: any(named: 'userId'),
        ),
      ).thenAnswer((_) async {});

      when(() => mockMealMediaRepo.triggerSuggestionRefresh()).thenReturn(null);

      final container = makeContainer();
      await container.read(mealTrackerProvider.notifier).save();

      verify(() => mockMealMediaRepo.triggerSuggestionRefresh()).called(1);
    });
  });
}
