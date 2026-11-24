import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/src/internals.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/models/insights.dart';
import 'package:belly_buddy/models/intolerance_rules.dart';
import 'package:belly_buddy/models/my_recipe_item.dart';
import 'package:belly_buddy/models/recipe.dart';
import 'package:belly_buddy/models/user_recipe.dart';
import 'package:belly_buddy/providers/insights_provider.dart';
import 'package:belly_buddy/providers/recipe_collection_provider.dart';
import 'package:belly_buddy/providers/user_recipes_provider.dart';
import 'package:belly_buddy/repositories/recipe_repository.dart';
import 'package:belly_buddy/services/recipes/recipe_ranking.dart';
import 'package:belly_buddy/providers/auth_provider.dart';

import '../helpers/fakes.dart';
import '../helpers/fixtures.dart';
import '../helpers/riverpod_helpers.dart';

class _OwnRecipes extends UserRecipesNotifier {
  _OwnRecipes(this._value);
  final AsyncValue<List<UserRecipe>> _value;

  @override
  AsyncValue<List<UserRecipe>> build() => _value;
}

void main() {
  late FakeRecipeRepository repo;
  final vegan = testRecipe(id: 'vegan', title: 'Vegan');
  final meat = testRecipe(id: 'meat', title: 'Fleisch', dietTags: const {});

  setUp(() => repo = FakeRecipeRepository()..collection = [vegan, meat]);

  ProviderContainer make({
    List<Override> overrides = const [],
    String? userId = testUserId,
    RankingSignals signals = const RankingSignals(),
    String? diet = 'vegan',
    List<String> intolerances = const ['Fruktose'],
  }) {
    final c = ProviderContainer(
      overrides: [
        recipeRepositoryProvider.overrideWithValue(repo),
        profileProviderSeededWith(
          testUserProfile(intolerances: intolerances, diet: diet),
        ),
        rankingSignalsProvider.overrideWithValue(signals),
        currentUserIdProvider.overrideWithValue(userId),
        ...overrides,
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  group('ranked', () {
    test(
      'vegan profile hides a non-vegan recipe, signals order the rest',
      () async {
        repo.collection = [
          testRecipe(id: 'a', title: 'A'),
          testRecipe(id: 'b', title: 'B', ingredients: [testLine('Reis')]),
          meat,
        ];
        final c = make(signals: const RankingSignals(good: {'reis'}));
        await c.read(recipeCollectionProvider.future);
        await c.read(intoleranceRulesProvider.future);
        final ranked = c.read(rankedRecipesProvider).requireValue;
        expect(ranked.hiddenByDiet, 1);
        expect(ranked.checked, isTrue);
        expect(ranked.fits.map((f) => f.recipe.id), ['a', 'b']);
      },
    );

    test('rules still loading, then loaded', () async {
      final gate = Completer<IntoleranceRules?>();
      final c = make(
        overrides: [intoleranceRulesProvider.overrideWith((_) => gate.future)],
      );
      c.listen(rankedRecipesProvider, (_, _) {});
      await c.read(recipeCollectionProvider.future);
      expect(c.read(rankedRecipesProvider).requireValue.checked, isFalse);
      gate.complete(testIntoleranceRules());
      await c.read(intoleranceRulesProvider.future);
      final ranked = c.read(rankedRecipesProvider).requireValue;
      expect(ranked.checked, isTrue);
      expect(ranked.fits.first.badge, isNotNull);
    });

    test('rules fail: unchecked, no throw', () async {
      repo.rules = null;
      final c = make();
      await c.read(recipeCollectionProvider.future);
      await c.read(intoleranceRulesProvider.future);
      expect(c.read(rankedRecipesProvider).requireValue.checked, isFalse);
    });

    test('rules throwing leave the fits unchecked', () async {
      final c = make(
        overrides: [
          intoleranceRulesProvider.overrideWith((ref) => throw StateError('x')),
        ],
      );
      await c.read(recipeCollectionProvider.future);
      expect(c.read(rankedRecipesProvider).requireValue.checked, isFalse);
    });
  });

  group('collection', () {
    test('refresh keeps the collection on failure', () async {
      final c = make();
      final before = await c.read(recipeCollectionProvider.future);
      repo.collectionError = StateError('offline');
      await c.read(recipeCollectionProvider.notifier).refresh();
      final state = c.read(recipeCollectionProvider);
      expect(state.hasError, isFalse);
      expect(state.requireValue, before);
    });

    test('refresh without data leaves the error', () async {
      repo.collectionError = StateError('offline');
      final c = make();
      await expectLater(
        c.read(recipeCollectionProvider.future),
        throwsStateError,
      );
      await c.read(recipeCollectionProvider.notifier).refresh();
      expect(c.read(recipeCollectionProvider).hasError, isTrue);
    });

    test('refresh picks up new recipes', () async {
      final c = make();
      await c.read(recipeCollectionProvider.future);
      repo.collection = [vegan];
      await c.read(recipeCollectionProvider.notifier).refresh();
      expect(c.read(recipeCollectionProvider).requireValue, [vegan]);
    });

    test('signed out: empty, no fetch', () async {
      repo.collectionError = StateError('must not be called');
      final c = make(userId: null);
      expect(await c.read(recipeCollectionProvider.future), isEmpty);
    });
  });

  group('favourites', () {
    test('toggle adds first, then removes', () async {
      final c = make();
      await c.read(recipeFavoritesProvider.future);
      final n = c.read(recipeFavoritesProvider.notifier);
      expect(n.isSaved('vegan'), isFalse);
      expect(await n.toggle('vegan'), isTrue);
      expect(await n.toggle('meat'), isTrue);
      expect(repo.added, ['vegan', 'meat']);
      expect(n.isSaved('vegan'), isTrue);
      expect(
        c.read(recipeFavoritesProvider).requireValue.map((f) => f.recipeId),
        ['meat', 'vegan'],
      );
      expect(await n.toggle('vegan'), isTrue);
      expect(repo.removed, ['vegan']);
      expect(n.isSaved('vegan'), isFalse);
    });

    test('toggle reverts on failure', () async {
      final c = make();
      await c.read(recipeFavoritesProvider.future);
      final n = c.read(recipeFavoritesProvider.notifier);
      await n.toggle('meat');
      final before = c.read(recipeFavoritesProvider).requireValue;
      repo.favoriteError = StateError('offline');
      expect(await n.toggle('vegan'), isFalse);
      expect(c.read(recipeFavoritesProvider).requireValue, before);
      expect(await n.toggle('meat'), isFalse);
      expect(c.read(recipeFavoritesProvider).requireValue, before);
    });

    test('savedRecipes skips ids missing from the collection', () async {
      repo.favorites = [
        FavoriteRecipe('gone', DateTime(2026, 11, 23)),
        FavoriteRecipe('vegan', DateTime(2026, 11, 22)),
        FavoriteRecipe('meat', DateTime(2026, 11, 24)),
      ];
      final c = make();
      c.listen(savedRecipesProvider, (_, _) {});
      expect(c.read(savedRecipesProvider), isEmpty);
      await c.read(recipeCollectionProvider.future);
      await c.read(recipeFavoritesProvider.future);
      final saved = c.read(savedRecipesProvider);
      expect(saved.map((s) => s.recipe.id), ['meat', 'vegan']);
      expect(saved.first.at, DateTime(2026, 11, 24));
    });
  });

  group('myRecipeItems', () {
    test('own and saved, newest first', () async {
      repo.favorites = [FavoriteRecipe('vegan', DateTime(2026, 11, 21))];
      final c = make(
        overrides: [
          userRecipesProvider.overrideWith(
            () => _OwnRecipes(
              AsyncData([
                testUserRecipe(id: 'o1', createdAt: DateTime(2026, 11, 20)),
                testUserRecipe(id: 'o2', createdAt: DateTime(2026, 11, 22)),
              ]),
            ),
          ),
        ],
      );
      c.listen(myRecipeItemsProvider, (_, _) {});
      await c.read(recipeCollectionProvider.future);
      await c.read(recipeFavoritesProvider.future);
      final items = c.read(myRecipeItemsProvider).requireValue;
      expect(items[0], isA<OwnRecipe>());
      expect((items[0] as OwnRecipe).recipe.id, 'o2');
      expect(items[1], isA<SavedRecipe>());
      expect((items[2] as OwnRecipe).recipe.id, 'o1');
    });

    test('own recipes loading: loading', () {
      final c = make(
        overrides: [
          userRecipesProvider.overrideWith(
            () => _OwnRecipes(const AsyncLoading()),
          ),
        ],
      );
      expect(c.read(myRecipeItemsProvider), isA<AsyncLoading>());
    });
  });

  group('recipeFit', () {
    test('known id, unknown id, collection error', () async {
      final c = make();
      c.listen(recipeFitProvider('meat'), (_, _) {});
      await c.read(recipeCollectionProvider.future);
      await c.read(intoleranceRulesProvider.future);
      // Diet is ignored: the non-vegan recipe still has a fit.
      expect(c.read(recipeFitProvider('meat')).requireValue?.recipe, meat);
      expect(c.read(recipeFitProvider('nope')).requireValue, isNull);

      repo.collectionError = StateError('x');
      final failing = make();
      await expectLater(
        failing.read(recipeCollectionProvider.future),
        throwsStateError,
      );
      expect(failing.read(recipeFitProvider('meat')).hasError, isTrue);
    });
  });

  group('forYou', () {
    test('picks from the ranked fits', () async {
      final c = make();
      await c.read(recipeCollectionProvider.future);
      final picked = c.read(forYouRecipesProvider).requireValue;
      expect(picked.map((f) => f.recipe.id), ['vegan']);
    });
  });

  group('rankingSignals', () {
    test('loading insights: empty', () {
      final c = ProviderContainer(
        overrides: [insightsProvider.overrideWith(() => _LoadingInsights())],
      );
      addTearDown(c.dispose);
      final s = c.read(rankingSignalsProvider);
      expect(s.good, isEmpty);
      expect(s.noticed, isEmpty);
    });

    test('locked insights: calm-day keys', () async {
      final c = ProviderContainer(
        overrides: [
          insightsProviderSeededWith(lockedInsights().copyWithCalm({'reis'})),
        ],
      );
      addTearDown(c.dispose);
      await c.read(insightsProvider.future);
      expect(c.read(rankingSignalsProvider).good, {'reis'});
    });
  });
}

class _LoadingInsights extends InsightsNotifier {
  @override
  Future<Insights> build() => Future.any(const []);
}

extension on Insights {
  Insights copyWithCalm(Set<String> keys) => Insights(
    progress: progress,
    calendar: calendar,
    goodDays: goodDays,
    hardDays: hardDays,
    noticed: noticed,
    pick: pick,
    journey: journey,
    calmDayIngredients: keys,
  );
}
