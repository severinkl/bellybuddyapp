// ignore_for_file: invalid_use_of_internal_member
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/src/internals.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/models/insights.dart';
import 'package:belly_buddy/models/intolerance_rules.dart';
import 'package:belly_buddy/models/my_recipe_item.dart';
import 'package:belly_buddy/models/recipe.dart';
import 'package:belly_buddy/models/user_profile.dart';
import 'package:belly_buddy/models/user_recipe.dart';
import 'package:belly_buddy/providers/profile_provider.dart';
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

class _Profile extends ProfileNotifier {
  _Profile(this._value);
  final AsyncValue<UserProfile?> _value;

  @override
  AsyncValue<UserProfile?> build() => _value;
}

/// Per-user favourites and collection, each fetch held until released.
/// Delegates to [_inner], but a favourite write waits for [_gate] first.
class _SlowFavRepo extends FakeRecipeRepository {
  _SlowFavRepo(this._inner, this._gate);
  final FakeRecipeRepository _inner;
  final Future<void> _gate;

  @override
  Future<List<FavoriteRecipe>> fetchFavorites(String userId) =>
      _inner.fetchFavorites(userId);

  @override
  Future<void> addFavorite(String userId, String recipeId) async {
    await _gate;
    await _inner.addFavorite(userId, recipeId);
  }
}

class _GatedRepo extends FakeRecipeRepository {
  final favGates = <String, Completer<List<FavoriteRecipe>>>{};
  final collectionGates = <Completer<List<Recipe>>>[];
  final favCalls = <String>[];

  @override
  Future<List<FavoriteRecipe>> fetchFavorites(String userId) {
    favCalls.add(userId);
    return (favGates[userId] = Completer()).future;
  }

  @override
  Future<List<Recipe>> fetchCollection() {
    final c = Completer<List<Recipe>>();
    collectionGates.add(c);
    return c.future;
  }
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
    Override? profile,
  }) {
    final c = ProviderContainer(
      overrides: [
        recipeRepositoryProvider.overrideWithValue(repo),
        profile ??
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

    test('rules missing: unchecked', () async {
      repo.rules = null;
      final c = make();
      await c.read(recipeCollectionProvider.future);
      await c.read(intoleranceRulesProvider.future);
      expect(c.read(rankedRecipesProvider).requireValue.checked, isFalse);
    });

    test('rules fail: unchecked, no throw', () async {
      final c = make(
        overrides: [
          intoleranceRulesProvider.overrideWith((ref) => throw StateError('x')),
        ],
      );
      c.listen(rankedRecipesProvider, (_, _) {});
      await c.read(recipeCollectionProvider.future);
      await expectLater(
        c.read(intoleranceRulesProvider.future),
        throwsStateError,
      );
      expect(c.read(intoleranceRulesProvider).hasError, isTrue);
      expect(c.read(rankedRecipesProvider).requireValue.checked, isFalse);
    });

    test(
      'a profile write that keeps intolerances and diet keeps the ranking',
      () async {
        final c = make();
        c.listen(rankedRecipesProvider, (_, _) {});
        c.listen(recipeFitProvider('vegan'), (_, _) {});
        await c.read(recipeCollectionProvider.future);
        await c.read(intoleranceRulesProvider.future);
        final ranked = c.read(rankedRecipesProvider).requireValue;
        final fit = c.read(recipeFitProvider('vegan')).requireValue;
        final notifier = c.read(profileProvider.notifier);
        final profile = c.read(profileProvider).requireValue!;

        // A re-read profile: equal intolerances in a new list.
        notifier.state = AsyncData(
          profile.copyWith(
            weeklyTipsEnabled: !profile.weeklyTipsEnabled,
            intolerances: List.of(profile.intolerances),
          ),
        );
        expect(c.read(rankedRecipesProvider).requireValue, same(ranked));
        expect(c.read(recipeFitProvider('vegan')).requireValue, same(fit));

        notifier.state = AsyncData(profile.copyWith(intolerances: const []));
        expect(c.read(rankedRecipesProvider).requireValue, isNot(same(ranked)));
        expect(
          c.read(recipeFitProvider('vegan')).requireValue,
          isNot(same(fit)),
        );

        final now = c.read(rankedRecipesProvider).requireValue;
        notifier.state = AsyncData(profile.copyWith(diet: null));
        expect(c.read(rankedRecipesProvider).requireValue.hiddenByDiet, 0);
        expect(now.hiddenByDiet, 1);
      },
    );

    test('profile in error or loading: unchecked, diet not applied', () async {
      for (final profile in [
        AsyncValue<UserProfile?>.error(StateError('x'), StackTrace.empty),
        const AsyncValue<UserProfile?>.loading(),
      ]) {
        final c = make(
          profile: profileProvider.overrideWith(() => _Profile(profile)),
        );
        await c.read(recipeCollectionProvider.future);
        await c.read(intoleranceRulesProvider.future);
        final ranked = c.read(rankedRecipesProvider).requireValue;
        expect(ranked.checked, isFalse);
        expect(ranked.hiddenByDiet, 0);
        expect(ranked.fits, hasLength(2));
      }
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

    test('refresh without data is loading meanwhile, then data', () async {
      final gated = _GatedRepo();
      repo = gated;
      final c = make();
      c.listen(recipeCollectionProvider, (_, _) {});
      gated.collectionGates[0].completeError(StateError('offline'));
      await expectLater(
        c.read(recipeCollectionProvider.future),
        throwsStateError,
      );

      final refreshing = c.read(recipeCollectionProvider.notifier).refresh();
      expect(c.read(recipeCollectionProvider), isA<AsyncLoading>());
      gated.collectionGates[1].complete([vegan]);
      await refreshing;
      expect(c.read(recipeCollectionProvider).requireValue, [vegan]);
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

    for (final failed in [true, false]) {
      test(
        'refresh reloads rules that ${failed ? 'failed' : 'were missing'}',
        () async {
          if (failed) {
            repo.rulesError = StateError('offline');
          } else {
            repo.rules = null;
          }
          final c = make();
          c.listen(rankedRecipesProvider, (_, _) {});
          await c.read(recipeCollectionProvider.future);
          await c
              .read(intoleranceRulesProvider.future)
              .then((_) {}, onError: (_) {});
          expect(c.read(rankedRecipesProvider).requireValue.checked, isFalse);

          repo
            ..rulesError = null
            ..rules = testIntoleranceRules();
          await c.read(recipeCollectionProvider.notifier).refresh();
          await c.read(intoleranceRulesProvider.future);

          expect(repo.rulesFetches, 2);
          expect(c.read(rankedRecipesProvider).requireValue.checked, isTrue);
        },
      );
    }

    test('refresh keeps loaded rules', () async {
      final c = make();
      c.listen(rankedRecipesProvider, (_, _) {});
      await c.read(recipeCollectionProvider.future);
      await c.read(intoleranceRulesProvider.future);

      await c.read(recipeCollectionProvider.notifier).refresh();

      expect(repo.rulesFetches, 1);
      expect(c.read(intoleranceRulesProvider).isLoading, isFalse);
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

  group('user change', () {
    final user = SwitchableUserId('A');

    test('favourites: B never sees A, late results are dropped', () async {
      final gated = _GatedRepo();
      final c = ProviderContainer(
        overrides: [
          recipeRepositoryProvider.overrideWithValue(gated),
          user.override,
        ],
      );
      addTearDown(c.dispose);
      c.listen(recipeFavoritesProvider, (_, _) {});
      gated.favGates['A']!.complete([FavoriteRecipe('x', DateTime(2026))]);
      await c.read(recipeFavoritesProvider.future);
      final n = c.read(recipeFavoritesProvider.notifier);
      expect(n.isSaved('x'), isTrue);

      // A refreshes; before it lands, B signs in.
      final refreshing = n.refresh();
      await Future<void>.delayed(Duration.zero);
      user.set(c, 'B');
      await Future<void>.delayed(Duration.zero);
      expect(c.read(recipeFavoritesProvider).isLoading, isTrue);
      expect(n.isSaved('x'), isFalse, reason: 'A\'s data is not B\'s');
      expect(await n.toggle('y'), isFalse, reason: 'nothing settled yet');

      gated.favGates['A']!.complete([FavoriteRecipe('a-late', DateTime(2026))]);
      await refreshing;
      expect(c.read(recipeFavoritesProvider).isLoading, isTrue);

      gated.favGates['B']!.complete([FavoriteRecipe('b', DateTime(2026))]);
      await c.read(recipeFavoritesProvider.future);
      expect(
        c.read(recipeFavoritesProvider).requireValue.map((f) => f.recipeId),
        ['b'],
      );
    });

    test('a failed toggle of A does not touch B', () async {
      final fake = FakeRecipeRepository()..favoriteError = StateError('x');
      final slow = Completer<void>();
      final repo = _SlowFavRepo(fake, slow.future);
      final c = ProviderContainer(
        overrides: [
          recipeRepositoryProvider.overrideWithValue(repo),
          user.override,
        ],
      );
      addTearDown(c.dispose);
      c.listen(recipeFavoritesProvider, (_, _) {});
      await c.read(recipeFavoritesProvider.future);
      final n = c.read(recipeFavoritesProvider.notifier);
      final toggling = n.toggle('y');
      await Future<void>.delayed(Duration.zero);
      fake.favorites = [FavoriteRecipe('b', DateTime(2026))];
      user.set(c, 'B');
      await c.read(recipeFavoritesProvider.future);
      slow.complete();
      expect(await toggling, isFalse);
      expect(
        c.read(recipeFavoritesProvider).requireValue.map((f) => f.recipeId),
        ['b'],
      );
    });

    test(
      'collection: late refresh of A is dropped, reload is loading',
      () async {
        final gated = _GatedRepo();
        final c = ProviderContainer(
          overrides: [
            recipeRepositoryProvider.overrideWithValue(gated),
            user.override,
          ],
        );
        addTearDown(c.dispose);
        c.listen(recipeCollectionProvider, (_, _) {});
        c.listen(rankedRecipesProvider, (_, _) {});
        gated.collectionGates[0].complete([vegan]);
        await c.read(recipeCollectionProvider.future);

        final refreshing = c.read(recipeCollectionProvider.notifier).refresh();
        await Future<void>.delayed(Duration.zero);
        user.set(c, 'B');
        await Future<void>.delayed(Duration.zero);
        expect(c.read(rankedRecipesProvider), isA<AsyncLoading>());
        expect(c.read(recipeFitProvider('vegan')), isA<AsyncLoading>());

        gated.collectionGates[2].complete([meat]);
        await c.read(recipeCollectionProvider.future);
        gated.collectionGates[1].complete([vegan]);
        await refreshing;
        expect(c.read(recipeCollectionProvider).requireValue, [meat]);
      },
    );

    /// Signed in as A, out, then in as B while offline: the rebuild fails
    /// and Riverpod's error still carries the signed-out empty list.
    Future<ProviderContainer> offlineSignIn() async {
      final c = ProviderContainer(
        overrides: [
          recipeRepositoryProvider.overrideWithValue(repo),
          user.override,
          profileProviderSeededWith(testUserProfile()),
          rankingSignalsProvider.overrideWithValue(const RankingSignals()),
        ],
      );
      addTearDown(c.dispose);
      c.listen(recipeFavoritesProvider, (_, _) {});
      c.listen(recipeCollectionProvider, (_, _) {});
      c.listen(rankedRecipesProvider, (_, _) {});
      c.listen(forYouRecipesProvider, (_, _) {});
      c.listen(recipeFitProvider('vegan'), (_, _) {});
      await c.read(recipeFavoritesProvider.future);
      await c.read(recipeCollectionProvider.future);
      user.set(c, null);
      await c.read(recipeFavoritesProvider.future);
      await c.read(recipeCollectionProvider.future);
      repo
        ..favoritesError = StateError('offline')
        ..collectionError = StateError('offline');
      user.set(c, 'B');
      await c
          .read(recipeFavoritesProvider.future)
          .then((_) {}, onError: (_) {});
      await c
          .read(recipeCollectionProvider.future)
          .then((_) {}, onError: (_) {});
      expect(c.read(recipeFavoritesProvider).hasValue, isTrue);
      expect(c.read(recipeCollectionProvider).hasValue, isTrue);
      return c;
    }

    test('an offline sign-in: the error, never the previous list', () async {
      final c = await offlineSignIn();

      expect(c.read(recipeFavoritesProvider).hasError, isTrue);
      expect(c.read(rankedRecipesProvider), isA<AsyncError>());
      expect(c.read(rankedRecipesProvider).hasValue, isFalse);
      expect(c.read(forYouRecipesProvider).hasValue, isFalse);
      expect(c.read(recipeFitProvider('vegan')), isA<AsyncError>());
      expect(c.read(recipeFitProvider('vegan')).hasValue, isFalse);
    });

    test(
      'after an offline sign-in, a refresh loads, then fails or lands',
      () async {
        final c = await offlineSignIn();
        final favorites = c.read(recipeFavoritesProvider.notifier);
        final collection = c.read(recipeCollectionProvider.notifier);

        var refreshing = [favorites.refresh(), collection.refresh()];
        expect(c.read(recipeFavoritesProvider).isLoading, isTrue);
        expect(c.read(rankedRecipesProvider), isA<AsyncLoading>());
        await Future.wait(refreshing);
        for (final state in [
          c.read(recipeFavoritesProvider),
          c.read(recipeCollectionProvider),
        ]) {
          expect(state.hasError, isTrue);
          expect(state.isLoading, isFalse);
        }
        expect(c.read(rankedRecipesProvider), isA<AsyncError>());

        repo
          ..favoritesError = null
          ..collectionError = null
          ..favorites = [FavoriteRecipe('vegan', DateTime(2026))];
        refreshing = [favorites.refresh(), collection.refresh()];
        await Future.wait(refreshing);
        expect(favorites.isSaved('vegan'), isTrue);
        expect(
          c
              .read(rankedRecipesProvider)
              .requireValue
              .fits
              .map((f) => f.recipe.id),
          unorderedEquals(['vegan', 'meat']),
        );
      },
    );

    test('signed out: favourites and collection are empty', () async {
      final c = ProviderContainer(
        overrides: [
          recipeRepositoryProvider.overrideWithValue(repo),
          user.override,
        ],
      );
      addTearDown(c.dispose);
      c.listen(recipeFavoritesProvider, (_, _) {});
      c.listen(recipeCollectionProvider, (_, _) {});
      await c.read(recipeCollectionProvider.future);
      user.set(c, null);
      expect(await c.read(recipeFavoritesProvider.future), isEmpty);
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

  group('collectionRecipe', () {
    test('known id, unknown id; gone once nobody watches', () async {
      final c = make();
      final sub = c.listen(collectionRecipeProvider('meat'), (_, _) {});
      final fit = c.listen(recipeFitProvider('meat'), (_, _) {});
      await c.read(recipeCollectionProvider.future);
      expect(sub.read().requireValue, same(meat));
      expect(c.read(collectionRecipeProvider('nope')).requireValue, isNull);

      fit.close();
      await c.pump();
      expect(c.read(recipeFitProvider('meat').exists), isFalse);
      expect(c.read(collectionRecipeProvider('meat').exists), isTrue);
      sub.close();
      await c.pump();
      expect(c.read(collectionRecipeProvider('meat').exists), isFalse);
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

    test('reloading insights: empty', () async {
      final c = ProviderContainer(
        overrides: [
          insightsProviderSeededWith(lockedInsights().copyWithCalm({'reis'})),
        ],
      );
      addTearDown(c.dispose);
      c.listen(rankingSignalsProvider, (_, _) {});
      await c.read(insightsProvider.future);
      expect(c.read(rankingSignalsProvider).good, {'reis'});
      // A reload keeps the data but is loading: nothing decides on it.
      final notifier = c.read(insightsProvider.notifier);
      notifier.state = const AsyncLoading<Insights>().copyWithPrevious(
        c.read(insightsProvider),
      );
      expect(c.read(insightsProvider).hasValue, isTrue);
      expect(c.read(rankingSignalsProvider).good, isEmpty);
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
