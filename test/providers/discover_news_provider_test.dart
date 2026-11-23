import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import 'package:belly_buddy/models/ingredient_suggestion_group.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/discover_news_provider.dart';
import 'package:belly_buddy/providers/ingredient_suggestion_provider.dart';
import 'package:belly_buddy/providers/recommendation_provider.dart';
import 'package:belly_buddy/repositories/ingredient_repository.dart';
import 'package:belly_buddy/repositories/recommendation_repository.dart';

import '../helpers/fakes.dart';
import '../helpers/fixtures.dart';
import '../helpers/mocks.dart';

/// The signed-in user's id, switchable.
class _UserId extends Notifier<String?> {
  _UserId(this._initial);
  final String? _initial;

  @override
  String? build() => _initial;

  void set(String? id) => state = id;
}

void main() {
  // The provider's AppLifecycleListener needs the binding.
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  void resume() => binding
    ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
    ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);

  late FakeRecommendationRepository tips;
  late MockIngredientRepository alternatives;
  late NotifierProvider<_UserId, String?> user;

  setUp(() {
    tips = FakeRecommendationRepository();
    alternatives = MockIngredientRepository();
    when(
      () => alternatives.fetchSuggestionGroups(any()),
    ).thenAnswer((_) async => [testSuggestionGroup()]);
  });

  /// A container with [userId] signed in (none for null) that keeps
  /// [discoverNewsProvider] alive like the app root does.
  ProviderContainer makeContainer({String? userId = testUserId}) {
    user = NotifierProvider<_UserId, String?>(() => _UserId(userId));
    final c = ProviderContainer.test(
      overrides: [
        currentUserIdProvider.overrideWith((ref) => ref.watch(user)),
        recommendationRepositoryProvider.overrideWithValue(tips),
        ingredientRepositoryProvider.overrideWithValue(alternatives),
      ],
    );
    c.listen(discoverNewsProvider, (_, _) {});
    return c;
  }

  /// Lets the scheduled refresh and the fakes' answers run.
  Future<void> settle() => pumpEventQueue();

  test('signed in: loads tips and alternatives once', () async {
    final c = makeContainer();
    await settle();

    expect(tips.fetchCount, 1);
    verify(() => alternatives.fetchSuggestionGroups(testUserId)).called(1);
    expect(c.read(recommendationProvider).value, tips.sets);
    expect(c.read(ingredientSuggestionProvider).value, hasLength(1));
  });

  test('back in the foreground: loads them again', () async {
    makeContainer();
    await settle();

    resume();
    await settle();

    expect(tips.fetchCount, 2);
    verify(() => alternatives.fetchSuggestionGroups(testUserId)).called(2);
  });

  test('signed out: loads nothing', () async {
    makeContainer(userId: null);
    await settle();

    resume();
    await settle();

    expect(tips.fetchCount, 0);
    verifyNever(() => alternatives.fetchSuggestionGroups(any()));
  });

  test(
    'signing in loads them; signing out stops the foreground loads',
    () async {
      final c = makeContainer(userId: null);
      await settle();

      c.read(user.notifier).set(testUserId);
      await settle();
      expect(tips.fetchCount, 1);

      c.read(user.notifier).set(null);
      await settle();
      resume();
      await settle();
      expect(tips.fetchCount, 1);
    },
  );

  test('another user does not join the previous user\'s refresh, and sees '
      'only their own', () async {
    final previous = Completer<List<IngredientSuggestionGroup>>();
    when(
      () => alternatives.fetchSuggestionGroups(testUserId),
    ).thenAnswer((_) => previous.future);
    when(
      () => alternatives.fetchSuggestionGroups('other-user'),
    ).thenAnswer((_) async => [testSuggestionGroup(ingredientName: 'Lauch')]);
    final c = makeContainer();
    await settle();

    c.read(user.notifier).set('other-user');
    await settle();
    verify(() => alternatives.fetchSuggestionGroups('other-user')).called(1);

    // The previous user's answer lands last.
    previous.complete([testSuggestionGroup(ingredientName: 'Zwiebel')]);
    await settle();
    expect(
      c.read(ingredientSuggestionProvider).value!.single.ingredientName,
      'Lauch',
    );
  });

  test('two refreshes at once fetch once', () async {
    final c = makeContainer();
    await settle();
    expect(tips.fetchCount, 1);

    final news = c.read(discoverNewsProvider.notifier);
    await Future.wait([news.refresh(), news.refresh()]);

    expect(tips.fetchCount, 2);
    verify(() => alternatives.fetchSuggestionGroups(testUserId)).called(2);
  });
}
