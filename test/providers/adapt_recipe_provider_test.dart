import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/models/adapted_recipe.dart';
import 'package:belly_buddy/providers/adapt_recipe_provider.dart';
import 'package:belly_buddy/repositories/recipe_repository.dart';

import '../helpers/fakes.dart';
import '../helpers/riverpod_helpers.dart';

void main() {
  late FakeRecipeRepository repo;
  late ProviderContainer container;
  final provider = adaptRecipeProvider('recipe-1');

  setUp(() {
    repo = FakeRecipeRepository();
    container = createContainer(
      overrides: [recipeRepositoryProvider.overrideWithValue(repo)],
    );
    // Keeps the autoDispose provider alive for the test.
    container.listen(provider, (_, _) {});
  });

  AdaptRecipeNotifier notifier() => container.read(provider.notifier);

  test('idle until start', () async {
    expect(container.read(provider), const AsyncData<AdaptedRecipe?>(null));
    await Future<void>.delayed(Duration.zero);

    expect(repo.adaptCalls, 0);
    expect(container.read(provider).value, isNull);
  });

  test('start sends the recipe id and holds the answer', () async {
    final seen = <String>[];
    repo.onAdapt = (id) async {
      seen.add(id);
      return testAdaptedRecipe(recipeId: id);
    };

    await notifier().start();

    expect(seen, ['recipe-1']);
    expect(container.read(provider).value?.recipeId, 'recipe-1');
  });

  test('start once', () async {
    final answer = Completer<AdaptedRecipe>();
    repo.onAdapt = (_) => answer.future;

    final first = notifier().start();
    expect(container.read(provider).isLoading, isTrue);
    final second = notifier().start();
    answer.complete(testAdaptedRecipe());
    await Future.wait([first, second]);

    expect(repo.adaptCalls, 1);
    expect(container.read(provider).value, isNotNull);

    await notifier().start();
    expect(repo.adaptCalls, 1, reason: 'a result is kept, not fetched again');
  });

  test('a failure is the error state', () async {
    repo.onAdapt = (_) async =>
        throw const AdaptRecipeException(AdaptFailure.later);

    await notifier().start();

    final error = container.read(provider).error;
    expect(error, isA<AdaptRecipeException>());
    expect((error! as AdaptRecipeException).failure, AdaptFailure.later);
  });

  test('retry after a failure calls again', () async {
    repo.onAdapt = (_) async =>
        throw const AdaptRecipeException(AdaptFailure.failed);
    await notifier().start();
    expect(container.read(provider).hasError, isTrue);

    final answer = Completer<AdaptedRecipe>();
    repo.onAdapt = (_) => answer.future;
    final retry = notifier().retry();
    expect(container.read(provider).isLoading, isTrue);
    answer.complete(testAdaptedRecipe());
    await retry;

    expect(repo.adaptCalls, 2);
    expect(container.read(provider).hasError, isFalse);
    expect(container.read(provider).value?.note, isNotEmpty);
  });

  test('retry while loading sends nothing more', () async {
    final answer = Completer<AdaptedRecipe>();
    repo.onAdapt = (_) => answer.future;

    final started = notifier().start();
    final retry = notifier().retry();
    answer.complete(testAdaptedRecipe());
    await Future.wait([started, retry]);

    expect(repo.adaptCalls, 1);
  });

  test('retry with a result calls again', () async {
    await notifier().start();

    await notifier().retry();

    expect(repo.adaptCalls, 2);
  });

  test('closed while waiting: the late answer is dropped', () async {
    final answer = Completer<AdaptedRecipe>();
    repo.onAdapt = (_) => answer.future;
    final scoped = createContainer(
      overrides: [recipeRepositoryProvider.overrideWithValue(repo)],
    );
    final sub = scoped.listen(provider, (_, _) {});
    final started = scoped.read(provider.notifier).start();

    sub.close();
    await Future<void>.delayed(Duration.zero);
    answer.complete(testAdaptedRecipe());

    await expectLater(started, completes);
  });
}
