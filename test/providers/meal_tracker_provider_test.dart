import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:belly_buddy/models/meal_entry.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/diary_provider.dart';
import 'package:belly_buddy/providers/meal_tracker_provider.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';
import 'package:belly_buddy/repositories/ingredient_repository.dart';
import 'package:belly_buddy/repositories/meal_media_repository.dart';
import 'package:belly_buddy/models/ingredient_search_result.dart';

import '../helpers/fakes.dart';
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
          const IngredientSearchResult(
            id: 'i-1',
            name: 'Zwiebel',
            isOwn: false,
          ),
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

  group('edit mode', () {
    final existing = MealEntry(
      id: 'meal-42',
      trackedAt: DateTime(2026, 4, 10, 12, 30),
      title: 'Pasta Bolognese',
      ingredients: const ['Nudeln', 'Tomatensoße', 'Hackfleisch'],
      imageUrl: 'https://cdn.example/old.jpg',
      notes: 'Mit extra Parmesan',
    );

    ProviderContainer makeEditContainer({
      FakeEntryRepository? entries,
      FakeMealMediaRepository? media,
      FakeIngredientRepository? ingredients,
    }) {
      return createContainer(
        overrides: [
          entryRepositoryProvider.overrideWithValue(
            entries ?? FakeEntryRepository(),
          ),
          mealMediaRepositoryProvider.overrideWithValue(
            media ?? FakeMealMediaRepository(),
          ),
          ingredientRepositoryProvider.overrideWithValue(
            ingredients ?? FakeIngredientRepository(),
          ),
          currentUserIdProvider.overrideWithValue('user-1'),
        ],
      );
    }

    test('seed(meal) copies all fields into state', () {
      final container = makeEditContainer();
      addTearDown(container.dispose);

      container.read(mealTrackerProvider.notifier).seed(existing);
      final s = container.read(mealTrackerProvider);

      expect(s.seed, existing);
      expect(s.title, 'Pasta Bolognese');
      expect(s.ingredients, ['Nudeln', 'Tomatensoße', 'Hackfleisch']);
      expect(s.imageUrl, 'https://cdn.example/old.jpg');
      expect(s.notes, 'Mit extra Parmesan');
      expect(s.trackedAt, DateTime(2026, 4, 10, 12, 30));
      expect(s.isDirty, isFalse);
    });

    test('isDirty flips to true after any seeded field changes', () {
      final container = makeEditContainer();
      addTearDown(container.dispose);

      final notifier = container.read(mealTrackerProvider.notifier);
      notifier.seed(existing);
      expect(container.read(mealTrackerProvider).isDirty, isFalse);

      notifier.setTitle('Pasta Carbonara');
      expect(container.read(mealTrackerProvider).isDirty, isTrue);
    });

    test(
      'isDirty stays false if user toggles a field back to the seed value',
      () {
        final container = makeEditContainer();
        addTearDown(container.dispose);

        final notifier = container.read(mealTrackerProvider.notifier);
        notifier.seed(existing);
        notifier.setTitle('Etwas Anderes');
        notifier.setTitle('Pasta Bolognese');

        expect(container.read(mealTrackerProvider).isDirty, isFalse);
      },
    );

    test(
      'save in edit mode calls updateMeal with seed.id and current form state',
      () async {
        final fakeEntries = FakeEntryRepository();
        final container = makeEditContainer(entries: fakeEntries);
        addTearDown(container.dispose);

        final notifier = container.read(mealTrackerProvider.notifier);
        notifier.seed(existing);
        notifier.setTitle('Pasta Carbonara');
        notifier.addIngredient('Speck');

        await notifier.save();

        expect(fakeEntries.updatedMeals, hasLength(1));
        final saved = fakeEntries.updatedMeals.single;
        expect(saved.id, 'meal-42');
        expect(saved.title, 'Pasta Carbonara');
        expect(saved.ingredients, contains('Speck'));
        expect(
          saved.imageUrl,
          'https://cdn.example/old.jpg',
          reason: 'no new bytes picked → keep seed imageUrl',
        );
        expect(
          fakeEntries.addedMeals,
          isEmpty,
          reason: 'edit mode must not call addMeal',
        );
      },
    );

    test('save in edit mode uploads new bytes and uses the new URL', () async {
      final fakeEntries = FakeEntryRepository();
      final fakeMedia = FakeMealMediaRepository(
        uploadResult: 'https://cdn.example/new.jpg',
      );
      final container = makeEditContainer(
        entries: fakeEntries,
        media: fakeMedia,
      );
      addTearDown(container.dispose);

      final notifier = container.read(mealTrackerProvider.notifier);
      notifier.seed(existing);
      notifier.setImage(Uint8List.fromList([1, 2, 3]), 'new.jpg');

      await notifier.save();

      final saved = fakeEntries.updatedMeals.single;
      expect(saved.imageUrl, 'https://cdn.example/new.jpg');
    });

    test(
      'save in edit mode invalidates both the old and new diary dates when the day changes',
      () async {
        final container = makeEditContainer();
        addTearDown(container.dispose);

        // Read the original-date provider first so invalidation has something to
        // invalidate.
        final originalDate = DateTime(2026, 4, 10);
        final originalRead = container.read(diaryEntriesProvider(originalDate));
        expect(originalRead, isA<AsyncValue<List<DiaryEntry>>>());

        final notifier = container.read(mealTrackerProvider.notifier);
        notifier.seed(existing);
        notifier.setTrackedAt(DateTime(2026, 4, 15, 9, 0));

        await notifier.save();

        // Both dates' providers should have been re-read (invalidation implies a
        // refresh on next read).
        final originalDay = DateTime(2026, 4, 10);
        final newDay = DateTime(2026, 4, 15);
        expect(
          container.read(diaryEntriesProvider(originalDay)),
          isA<AsyncValue<List<DiaryEntry>>>(),
        );
        expect(
          container.read(diaryEntriesProvider(newDay)),
          isA<AsyncValue<List<DiaryEntry>>>(),
        );
      },
    );

    test(
      'save in create mode still calls addMeal (regression check)',
      () async {
        final fakeEntries = FakeEntryRepository();
        final container = makeEditContainer(entries: fakeEntries);
        addTearDown(container.dispose);

        final notifier = container.read(mealTrackerProvider.notifier);
        notifier.addIngredient('Brot');
        await notifier.save();

        expect(fakeEntries.addedMeals, hasLength(1));
        expect(fakeEntries.updatedMeals, isEmpty);
      },
    );
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
