import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:belly_buddy/models/ingredient_suggestion_group.dart';
import 'package:belly_buddy/models/recommendation.dart';
import 'package:belly_buddy/providers/buddy_provider.dart';
import 'package:belly_buddy/providers/dietitian_tips_provider.dart';
import 'package:belly_buddy/providers/discover_news_provider.dart';
import 'package:belly_buddy/providers/ingredient_suggestion_provider.dart';
import 'package:belly_buddy/providers/recommendation_provider.dart';
import 'package:belly_buddy/repositories/ingredient_repository.dart';
import 'package:belly_buddy/repositories/recommendation_repository.dart';
import 'package:belly_buddy/router/route_names.dart';
import 'package:belly_buddy/services/dietitian_tip_service.dart';

import '../helpers/app_lifecycle.dart';
import '../helpers/dietitian_tip_fakes.dart';
import '../helpers/fakes.dart';
import '../helpers/fixtures.dart';
import '../helpers/mocks.dart';
import '../helpers/riverpod_helpers.dart';

void main() {
  // The foreground signal's AppLifecycleListener needs the binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeRecommendationRepository tips;
  late MockIngredientRepository alternatives;
  late SwitchableUserId user;
  late DateTime now;

  /// The app is back in the foreground [later] after now.
  void returnLater(Duration later) {
    now = now.add(later);
    returnFromBackground();
  }

  setUp(() {
    now = DateTime(2026, 11, 23, 9);
    tips = FakeRecommendationRepository();
    alternatives = MockIngredientRepository();
    when(
      () => alternatives.fetchSuggestionGroups(any()),
    ).thenAnswer((_) async => [testSuggestionGroup()]);
  });

  /// A container with [userId] signed in (none for null) that keeps
  /// [discoverNewsProvider] alive like the app root does.
  ProviderContainer makeContainer({
    String? userId = testUserId,
    List<Override> extra = const [],
  }) {
    user = SwitchableUserId(userId);
    final c = ProviderContainer.test(
      overrides: [
        ...extra,
        user.override,
        recommendationRepositoryProvider.overrideWithValue(tips),
        ingredientRepositoryProvider.overrideWithValue(alternatives),
        buddyClockProvider.overrideWithValue(() => now),
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

  test('back in the foreground 5 minutes after the last load: loads them '
      'again', () async {
    makeContainer();
    await settle();

    returnLater(const Duration(minutes: 5));
    await settle();

    expect(tips.fetchCount, 2);
    verify(() => alternatives.fetchSuggestionGroups(testUserId)).called(2);
  });

  test(
    'back in the foreground sooner: nothing; a push loads regardless',
    () async {
      final c = makeContainer();
      await settle();

      returnLater(const Duration(minutes: 4, seconds: 59));
      await settle();
      expect(tips.fetchCount, 1);

      await c.read(discoverNewsProvider.notifier).refresh();
      expect(tips.fetchCount, 2);

      // 5 minutes after the push's load, not after the sign-in's.
      returnLater(const Duration(minutes: 4));
      await settle();
      expect(tips.fetchCount, 2);
      returnLater(const Duration(minutes: 1));
      await settle();
      expect(tips.fetchCount, 3);
    },
  );

  test('signed out: loads nothing', () async {
    makeContainer(userId: null);
    await settle();

    returnLater(const Duration(hours: 1));
    await settle();

    expect(tips.fetchCount, 0);
    verifyNever(() => alternatives.fetchSuggestionGroups(any()));
  });

  test(
    'signing in loads them; signing out stops the foreground loads',
    () async {
      final c = makeContainer(userId: null);
      await settle();

      user.set(c, testUserId);
      await settle();
      expect(tips.fetchCount, 1);

      user.set(c, null);
      await settle();
      returnLater(const Duration(hours: 1));
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

    user.set(c, 'other-user');
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

  test('calls while a refresh runs make exactly one more after it, and '
      'wait for it', () async {
    final c = makeContainer();
    await settle();

    // Every load from here on waits until the test lets it finish.
    final loads = <Completer<List<IngredientSuggestionGroup>>>[];
    when(() => alternatives.fetchSuggestionGroups(any())).thenAnswer((_) {
      final load = Completer<List<IngredientSuggestionGroup>>();
      loads.add(load);
      return load.future;
    });
    final news = c.read(discoverNewsProvider.notifier);
    var done = 0;
    // One starts; a push and a resume arrive while it runs.
    for (var i = 0; i < 3; i++) {
      unawaited(news.refresh().then((_) => done++));
    }
    await settle();
    expect(loads, hasLength(1));

    loads.single.complete([testSuggestionGroup()]);
    await settle();
    expect(loads, hasLength(2));
    expect(done, 0);

    loads.last.complete([testSuggestionGroup()]);
    await settle();
    expect(loads, hasLength(2));
    expect(done, 3);
  });

  test('a refresh at sign-in is the sign-in load, not one more', () async {
    final c = makeContainer();
    unawaited(c.read(discoverNewsProvider.notifier).refresh());
    await settle();

    expect(tips.fetchCount, 1);
    verify(() => alternatives.fetchSuggestionGroups(testUserId)).called(1);
  });

  group('a push in the foreground', () {
    for (final route in [
      RoutePaths.recommendations,
      RoutePaths.ingredientSuggestions,
    ]) {
      test('routed to $route: loads them', () async {
        final c = makeContainer();
        await settle();

        await c.read(discoverNewsProvider.notifier).pushArrived(route);

        expect(tips.fetchCount, 2);
        verify(() => alternatives.fetchSuggestionGroups(testUserId)).called(2);
      });
    }

    test('routed to Entdecken: loads the dietitian tips again, nothing '
        'else', () async {
      final service = FakeDietitianTipService([testTip()]);
      final c = makeContainer(
        extra: [dietitianTipServiceProvider.overrideWithValue(service)],
      );
      c.listen(dietitianTipsProvider, (_, _) {});
      await c.read(dietitianTipsProvider.future);
      await settle();

      await c
          .read(discoverNewsProvider.notifier)
          .pushArrived(RoutePaths.discover);

      expect(service.listCalls, 2);
      expect(tips.fetchCount, 1);
    });

    test('routed to Entdecken before the tips ever loaded: no load (their '
        'first load is still to come)', () async {
      final service = FakeDietitianTipService([testTip()]);
      final c = makeContainer(
        extra: [dietitianTipServiceProvider.overrideWithValue(service)],
      );
      await settle();

      await c
          .read(discoverNewsProvider.notifier)
          .pushArrived(RoutePaths.discover);

      expect(service.listCalls, 0);
    });

    for (final route in [RoutePaths.diary, null]) {
      test('routed to $route: nothing', () async {
        final c = makeContainer();
        await settle();

        await c.read(discoverNewsProvider.notifier).pushArrived(route);

        expect(tips.fetchCount, 1);
        verify(() => alternatives.fetchSuggestionGroups(testUserId)).called(1);
      });
    }
  });

  group('ensureLoaded (Entdecken opening)', () {
    test('right after sign-in: joins the sign-in load, no other', () async {
      final signInLoad = Completer<List<IngredientSuggestionGroup>>();
      when(
        () => alternatives.fetchSuggestionGroups(any()),
      ).thenAnswer((_) => signInLoad.future);
      final c = makeContainer();
      await settle();

      var loaded = false;
      unawaited(
        c
            .read(discoverNewsProvider.notifier)
            .ensureLoaded()
            .then((_) => loaded = true),
      );
      await settle();
      expect(loaded, isFalse);

      signInLoad.complete([testSuggestionGroup()]);
      await settle();
      expect(loaded, isTrue);
      expect(tips.fetchCount, 1);
      verify(() => alternatives.fetchSuggestionGroups(testUserId)).called(1);
    });

    test('both loaded: nothing', () async {
      final c = makeContainer();
      await settle();

      await c.read(discoverNewsProvider.notifier).ensureLoaded();

      expect(tips.fetchCount, 1);
      verify(() => alternatives.fetchSuggestionGroups(testUserId)).called(1);
    });

    test('after a failed first load: loads', () async {
      var fetches = 0;
      when(() => alternatives.fetchSuggestionGroups(any())).thenAnswer(
        (_) => ++fetches == 1
            ? Future.error(Exception('offline'))
            : Future.value([testSuggestionGroup()]),
      );
      final c = makeContainer();
      await settle();
      expect(c.read(ingredientSuggestionProvider).hasValue, isFalse);

      await c.read(discoverNewsProvider.notifier).ensureLoaded();

      expect(fetches, 2);
      expect(c.read(ingredientSuggestionProvider).value, hasLength(1));
    });
  });

  group('discoverBadgeProvider', () {
    /// Loads what the container's fakes hold, then reads the badge.
    Future<bool> badgeAfterLoad({
      List<Recommendation>? sets,
      List<IngredientSuggestionGroup>? groups,
    }) async {
      tips = FakeRecommendationRepository(sets: sets);
      when(
        () => alternatives.fetchSuggestionGroups(any()),
      ).thenAnswer((_) async => groups ?? []);
      final c = makeContainer();
      await settle();
      return c.read(discoverBadgeProvider);
    }

    test('an unseen tip set: true', () async {
      expect(await badgeAfterLoad(sets: [testRecommendation()]), isTrue);
    });

    test('one new alternative: true', () async {
      expect(await badgeAfterLoad(groups: [testSuggestionGroup()]), isTrue);
    });

    test('nothing new: false', () async {
      expect(
        await badgeAfterLoad(groups: [testSuggestionGroup(isNew: false)]),
        isFalse,
      );
    });

    test('both still loading: false', () {
      final c = ProviderContainer.test();
      expect(c.read(discoverBadgeProvider), isFalse);
    });
  });
}
