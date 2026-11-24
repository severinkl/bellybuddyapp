// ignore_for_file: invalid_use_of_internal_member
import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/src/internals.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/models/first_tip.dart';
import 'package:belly_buddy/models/journey_rewards.dart';
import 'package:belly_buddy/providers/buddy_provider.dart';
import 'package:belly_buddy/providers/first_tip_provider.dart';
import 'package:belly_buddy/providers/journey_rewards_provider.dart';
import 'package:belly_buddy/providers/profile_provider.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';
import 'package:belly_buddy/repositories/profile_repository.dart';
import 'package:belly_buddy/repositories/recipe_repository.dart';
import 'package:belly_buddy/repositories/recommendation_repository.dart';

import '../helpers/fakes.dart';
import '../helpers/fixtures.dart';
import '../helpers/logs.dart';
import '../helpers/riverpod_helpers.dart';

/// The signed-in user's id, switchable.
final _user = SwitchableUserId('u1');

/// The app's clock, pinned to another day than the test run's.
final _now = DateTime(2026, 11, 24, 14);

/// Day 3 earned, the first tip offered (the weekly tips were off).
const _offered = JourneyRewards(earnedDay: 3, tipOffer: TipOffer.offered);

/// The profile: Fruktose, vegetarian, the weekly tips off.
final _profile = testUserProfile(
  intolerances: ['Fruktose'],
  diet: 'vegetarisch',
  weeklyTipsEnabled: false,
);

/// Meals of today, 2 and 4 days ago: the last is out of the 3 days.
final _today = testMealEntry(
  id: 'today',
  trackedAt: DateTime(2026, 11, 24, 8),
  title: 'Porridge',
  ingredients: ['Haferflocken'],
);
final _twoDaysAgo = testMealEntry(
  id: 'two',
  trackedAt: DateTime(2026, 11, 22, 19),
  title: 'Risotto',
  ingredients: ['Arborio'],
);
final _fourDaysAgo = testMealEntry(
  id: 'four',
  trackedAt: DateTime(2026, 11, 20, 12),
  title: 'Zwiebelsuppe',
  ingredients: ['Zwiebel'],
);

/// A saved set with two tips.
final _set = testRecommendation(
  id: 'first',
  recommendations: [
    testRecommendationItem(focus: true),
    testRecommendationItem(type: 'try', ingredient: 'Hafer', alternative: null),
  ],
);

/// The loads and writes in flight all landed.
Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await pumpEventQueue();
  }
}

/// No line of [logs] names a meal's title or ingredient.
void _expectNoMeals(List<String> logs) {
  for (final meal in [_today, _twoDaysAgo, _fourDaysAgo]) {
    for (final word in [meal.title, ...meal.ingredients]) {
      expect(logs.join('\n'), isNot(contains(word)), reason: word);
    }
  }
}

/// A [FakeProfileRepository] whose weekly-tips write waits for [gate].
class _GatedProfileRepository extends FakeProfileRepository {
  Completer<void>? gate;

  @override
  Future<void> setWeeklyTips(String userId, bool enabled) async {
    await gate?.future;
    return super.setWeeklyTips(userId, enabled);
  }
}

void main() {
  // The insights' new-day signal (an AppLifecycleListener) needs the binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  late _GatedProfileRepository profiles;
  late FakeEntryRepository entries;
  late FakeRecommendationRepository tips;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    profiles = _GatedProfileRepository()..seedProfile(_profile);
    entries = FakeEntryRepository()
      ..recentMeals = [_today, _twoDaysAgo, _fourDaysAgo];
    tips = FakeRecommendationRepository();
  });

  /// A container with [rewards] seeded (in memory), or with the stored
  /// rewards when [storedRewards]; with [_profile] loaded, or no profile;
  /// the app's clock pinned to [now] (default [_now]).
  ProviderContainer container({
    JourneyRewards? rewards = _offered,
    bool noProfile = false,
    bool storedRewards = false,
    DateTime? now,
    List<Override> overrides = const [],
  }) => ProviderContainer.test(
    overrides: [
      _user.override,
      profileRepositoryProvider.overrideWithValue(profiles),
      profileProviderSeededWith(noProfile ? null : _profile),
      entryRepositoryProvider.overrideWithValue(entries),
      recommendationRepositoryProvider.overrideWithValue(tips),
      buddyClockProvider.overrideWithValue(() => now ?? _now),
      if (!storedRewards) journeyRewardsSeededWith(rewards),
      ...overrides,
    ],
  );

  Future<bool> accept(ProviderContainer c) =>
      c.read(firstTipProvider.notifier).accept();

  JourneyRewards? rewardsOf(ProviderContainer c) =>
      c.read(journeyRewardsProvider);

  bool? weeklyTipsOf(ProviderContainer c) =>
      c.read(profileProvider).value?.weeklyTipsEnabled;

  group('accept', () {
    test('opt-in first, then one request with the profile and the last 3 '
        'days\' meals', () async {
      final optIn = Completer<void>();
      final aiCall = Completer<void>();
      profiles.gate = optIn;
      tips
        ..firstTipGate = aiCall
        ..firstTipSet = _set;
      final c = container();
      final seen = <(TipOffer?, FirstTipState?)>[];
      c.listen(
        journeyRewardsProvider,
        (_, next) => seen.add((next?.tipOffer, next?.firstTip)),
      );

      final accepted = accept(c);
      await _settle();
      // The opt-in write is on its way: nothing read, asked or answered.
      expect(entries.recentMealsSince, isEmpty);
      expect(tips.firstTipRequests, isEmpty);
      expect(rewardsOf(c), _offered);

      optIn.complete();
      expect(await accepted, isTrue);
      await _settle();

      expect(profiles.weeklyTipsWrites, [true]);
      expect(weeklyTipsOf(c), isTrue);
      // Stored before the call: the offer accepted, the request noted.
      expect(seen, [
        (TipOffer.accepted, null),
        (TipOffer.accepted, FirstTipState.requested),
      ]);
      // 3 calendar days back, at the same wall-clock time.
      expect(entries.recentMealsSince, [DateTime(2026, 11, 21, 14)]);
      final request = tips.firstTipRequests.single;
      expect(request.intolerances, ['Fruktose']);
      expect(request.diet, 'vegetarisch');
      expect(request.meals, [_today, _twoDaysAgo]);

      aiCall.complete();
      await _settle();

      expect(seen.last, (TipOffer.accepted, FirstTipState.done));
      expect(tips.fetchCount, 1);
      expect(tips.marked, isEmpty);
      expect(tips.firstTipRequests, hasLength(1));
    });

    test('opt-in fails: false, no request, firstTip unchanged', () async {
      captureLogs();
      profiles.weeklyTipsError = Exception('offline');
      final c = container();

      expect(await accept(c), isFalse);
      await _settle();

      expect(profiles.weeklyTipsWrites, [true]);
      expect(weeklyTipsOf(c), isFalse);
      expect(entries.recentMealsSince, isEmpty);
      expect(tips.firstTipRequests, isEmpty);
      expect(rewardsOf(c), _offered);
    });

    test('no user, no journey or no profile: false, nothing written or '
        'asked', () async {
      captureLogs();
      final signedOut = container();
      _user.set(signedOut, null);
      final cases = [
        signedOut,
        container(rewards: null),
        container(noProfile: true),
      ];

      for (final c in cases) {
        expect(await accept(c), isFalse);
      }
      await _settle();

      expect(profiles.weeklyTipsWrites, isEmpty);
      expect(tips.firstTipRequests, isEmpty);
      expect(rewardsOf(cases.first), _offered);
    });

    test('accept twice: one request', () async {
      final aiCall = Completer<void>();
      tips
        ..firstTipGate = aiCall
        ..firstTipSet = _set;
      final c = container();

      // At once (a double tap): the second joins the first.
      final both = await Future.wait([accept(c), accept(c)]);
      await _settle();
      expect(both, [true, true]);
      expect(tips.firstTipRequests, hasLength(1));

      // While the request runs.
      expect(await accept(c), isTrue);
      await _settle();
      expect(tips.firstTipRequests, hasLength(1));

      aiCall.complete();
      await _settle();
      expect(rewardsOf(c)!.firstTip, FirstTipState.done);

      // After it is done.
      expect(await accept(c), isTrue);
      await _settle();

      expect(tips.firstTipRequests, hasLength(1));
      expect(profiles.weeklyTipsWrites, [true]);
      expect(rewardsOf(c)!.firstTip, FirstTipState.done);
    });

    test('the 3 days are calendar days: across the autumn-DST Sunday the '
        'bound keeps the wall clock', () async {
      // Under TZ=Europe/Vienna, 25 Oct 2026 has 25 hours: 72 hours before
      // Tuesday 14:00 is Saturday 15:00, not 14:00.
      final at1430 = testMealEntry(
        id: 'in',
        trackedAt: DateTime(2026, 10, 24, 14, 30),
      );
      final at1330 = testMealEntry(
        id: 'out',
        trackedAt: DateTime(2026, 10, 24, 13, 30),
      );
      entries.recentMeals = [at1430, at1330];
      final c = container(now: DateTime(2026, 10, 27, 14));

      expect(await accept(c), isTrue);
      await _settle();

      expect(entries.recentMealsSince, [DateTime(2026, 10, 24, 14)]);
      expect(tips.firstTipRequests.single.meals, [at1430]);
    });
  });

  group('the request fails', () {
    /// After a failure: failed, still opted in, one request, nothing
    /// reloaded, the state false; a later accept asks nothing.
    Future<void> expectFailedOnce(ProviderContainer c) async {
      expect(rewardsOf(c)!.firstTip, FirstTipState.failed);
      expect(rewardsOf(c)!.tipOffer, TipOffer.accepted);
      expect(weeklyTipsOf(c), isTrue);
      expect(profiles.weeklyTipsWrites, [true]);
      expect(tips.firstTipRequests, hasLength(1));
      expect(tips.fetchCount, 0);

      expect(await accept(c), isTrue);
      await _settle();
      expect(tips.firstTipRequests, hasLength(1));
    }

    for (final (name, error, logged) in [
      ('500', const FirstTipException(500), '500'),
      ('429', const FirstTipException(429), '429'),
      ('transport', const FirstTipException(), 'no status'),
    ]) {
      test('$name: failed, still opted in, one request, logged once', () async {
        final logs = captureLogs();
        tips.firstTipError = error;
        final c = container();

        expect(await accept(c), isTrue);
        await _settle();

        await expectFailedOnce(c);
        expect(tips.marked, isEmpty);
        expect(logs.where((line) => line.contains('First tip failed')), [
          contains(logged),
        ]);
        _expectNoMeals(logs);
      });
    }

    test('timeout: failed, still opted in, one request', () {
      fakeAsync((async) {
        final logs = captureLogs();
        tips.firstTipGate = Completer<void>(); // never answers
        final c = container();
        bool? accepted;
        accept(c).then((v) => accepted = v);
        async.flushMicrotasks();
        expect(accepted, isTrue);

        async.elapse(AppConstants.firstTipTimeout - const Duration(seconds: 1));
        expect(rewardsOf(c)!.firstTip, FirstTipState.requested);

        async.elapse(const Duration(seconds: 2));
        expect(rewardsOf(c)!.firstTip, FirstTipState.failed);
        expect(weeklyTipsOf(c), isTrue);
        expect(tips.firstTipRequests, hasLength(1));
        expect(tips.fetchCount, 0);
        _expectNoMeals(logs);
      });
    });

    test('a meals read that never ends: failed after the timeout, and no '
        'request after it', () {
      fakeAsync((async) {
        captureLogs();
        final read = Completer<void>();
        entries.recentMealsGate = read; // hangs
        final c = container();
        accept(c);
        async.flushMicrotasks();

        async.elapse(AppConstants.firstTipTimeout - const Duration(seconds: 1));
        expect(rewardsOf(c)!.firstTip, FirstTipState.requested);

        async.elapse(const Duration(seconds: 2));
        expect(rewardsOf(c)!.firstTip, FirstTipState.failed);

        // The read ends late: the request it would start is dropped.
        read.complete();
        async.flushMicrotasks();
        expect(tips.firstTipRequests, isEmpty);
        expect(rewardsOf(c)!.firstTip, FirstTipState.failed);
        expect(weeklyTipsOf(c), isTrue);
      });
    });

    test(
      'any other error (the meals read fails): failed, no request',
      () async {
        final logs = captureLogs();
        entries.recentMealsError = Exception('offline');
        final c = container();

        expect(await accept(c), isTrue);
        await _settle();

        expect(rewardsOf(c)!.firstTip, FirstTipState.failed);
        expect(weeklyTipsOf(c), isTrue);
        expect(tips.firstTipRequests, isEmpty);
        expect(
          logs,
          contains('FirstTip [ERROR]: First tip failed (_Exception)'),
        );
        _expectNoMeals(logs);

        expect(await accept(c), isTrue);
        await _settle();
        expect(entries.recentMealsSince, hasLength(1));
      },
    );

    test('200 without tips: failed, the set stamped seen', () async {
      captureLogs();
      tips.firstTipSet = testRecommendation(
        id: 'empty',
        summary: 'Leider konnte keine Analyse durchgeführt werden.',
        recommendations: [],
      );
      final c = container();

      expect(await accept(c), isTrue);
      await _settle();

      await expectFailedOnce(c);
      expect(tips.marked, [
        ['empty'],
      ]);
      expect(tips.sets.first.seenAt, isNotNull);
    });

    test('an answer without id: failed, nothing to stamp', () async {
      captureLogs();
      final c = container();

      expect(await accept(c), isTrue);
      await _settle();

      await expectFailedOnce(c);
      expect(tips.marked, isEmpty);
    });

    test('a failed stamp is only logged', () async {
      final logs = captureLogs();
      tips
        ..firstTipSet = testRecommendation(id: 'empty', recommendations: [])
        ..markError = Exception('offline');
      final c = container();

      expect(await accept(c), isTrue);
      await _settle();

      await expectFailedOnce(c);
      expect(tips.marked, [
        ['empty'],
      ]);
      expect(logs, contains(startsWith('FirstTip [ERROR]')));
    });
  });

  group('over the stored rewards', () {
    late FakeRecipeRepository recipes;

    setUp(() {
      SharedPreferences.setMockInitialValues({
        'insight_journey_u1': true,
        'insight_journey_u2': true,
        // Both with the offer open, so a stray answer would show.
        'journey_rewards_u1': jsonEncode(_offered.toJson()),
        'journey_rewards_u2': jsonEncode(_offered.toJson()),
      });
      entries.insightSource = insightSourceFor(
        activeDays: 3,
        gutFeelings: 0,
        now: _now,
      );
      recipes = FakeRecipeRepository()
        ..collection = [testRecipe(id: 'a', title: 'Apfel-Reis')];
    });

    /// A container over the stored rewards (an app start), read.
    Future<ProviderContainer> stored() async {
      final c = container(
        storedRewards: true,
        overrides: [recipeRepositoryProvider.overrideWithValue(recipes)],
      );
      c.listen(journeyRewardsProvider, (_, _) {});
      await _settle();
      expect(rewardsOf(c), isNotNull);
      return c;
    }

    /// The day-3 answer and the first tip of [r] (the picks fill
    /// meanwhile).
    (TipOffer?, FirstTipState?) answerOf(JourneyRewards? r) =>
        (r?.tipOffer, r?.firstTip);

    const open = (TipOffer.offered, null);

    Future<JourneyRewards?> storedFor(String userId) async {
      final raw = (await SharedPreferences.getInstance()).getString(
        'journey_rewards_$userId',
      );
      return raw == null ? null : JourneyRewards.fromJson(jsonDecode(raw));
    }

    test('after a restart with a request stored: none', () async {
      // The app is closed while the call is on its way.
      tips.firstTipGate = Completer<void>();
      final first = await stored();
      expect(await accept(first), isTrue);
      await _settle();
      expect(tips.firstTipRequests, hasLength(1));
      first.dispose();

      final restarted = await stored();
      const requested = (TipOffer.accepted, FirstTipState.requested);
      expect(answerOf(rewardsOf(restarted)), requested);

      expect(await accept(restarted), isTrue);
      await _settle();

      expect(tips.firstTipRequests, hasLength(1));
      expect(profiles.weeklyTipsWrites, [true]);
      expect(answerOf(rewardsOf(restarted)), requested);
      expect(answerOf(await storedFor('u1')), requested);
    });

    test(
      'the user changed meanwhile: nothing stored for the new user',
      () async {
        final logs = captureLogs();
        final aiCall = Completer<void>();
        tips
          ..firstTipGate = aiCall
          ..firstTipSet = _set;
        final c = await stored();
        expect(answerOf(rewardsOf(c)), open);

        expect(await accept(c), isTrue);
        await _settle();
        expect(tips.firstTipRequests, hasLength(1));

        _user.set(c, 'u2');
        await _settle();
        aiCall.complete();
        await _settle();

        expect(answerOf(rewardsOf(c)), open);
        expect(answerOf(await storedFor('u2')), open);
        expect(answerOf(await storedFor('u1')), (
          TipOffer.accepted,
          FirstTipState.requested,
        ));
        expect(tips.fetchCount, 0);
        expect(tips.marked, isEmpty);
        expect(logs, contains(startsWith('FirstTip [WARN]')));
      },
    );

    test('a switch during the opt-in write: false, no request, nothing '
        'stored for the new user', () async {
      captureLogs();
      final optIn = Completer<void>();
      profiles.gate = optIn;
      final c = await stored();
      expect(answerOf(rewardsOf(c)), open);

      final accepted = accept(c);
      await _settle();
      _user.set(c, 'u2');
      await _settle();
      optIn.complete();

      expect(await accepted, isFalse);
      await _settle();

      expect(tips.firstTipRequests, isEmpty);
      expect(answerOf(rewardsOf(c)), open);
      expect(answerOf(await storedFor('u2')), open);
      expect(answerOf(await storedFor('u1')), open);
    });
  });
}
