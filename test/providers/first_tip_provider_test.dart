// ignore_for_file: invalid_use_of_internal_member
import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart' show debugPrint;
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

/// What the logger prints during the test (and nothing on the console).
List<String> _captureLogs() {
  final logs = <String>[];
  final print = debugPrint;
  debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
  addTearDown(() => debugPrint = print);
  return logs;
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
  /// rewards when [storedRewards]; with [_profile] loaded, or no profile.
  ProviderContainer container({
    JourneyRewards? rewards = _offered,
    bool noProfile = false,
    bool storedRewards = false,
    List<Override> overrides = const [],
  }) => ProviderContainer.test(
    overrides: [
      _user.override,
      profileRepositoryProvider.overrideWithValue(profiles),
      profileProviderSeededWith(noProfile ? null : _profile),
      entryRepositoryProvider.overrideWithValue(entries),
      recommendationRepositoryProvider.overrideWithValue(tips),
      buddyClockProvider.overrideWithValue(() => _now),
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
      final running = <bool>[];
      c.listen(firstTipProvider, (_, next) => running.add(next));

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
      expect(c.read(firstTipProvider), isTrue);
      expect(entries.recentMealsSince, [DateTime(2026, 11, 21, 14)]);
      expect(
        entries.recentMealsSince.single,
        _now.subtract(AppConstants.firstTipMealsWindow),
      );
      final request = tips.firstTipRequests.single;
      expect(request.intolerances, ['Fruktose']);
      expect(request.diet, 'vegetarisch');
      expect(request.meals, [_today, _twoDaysAgo]);

      aiCall.complete();
      await _settle();

      expect(seen.last, (TipOffer.accepted, FirstTipState.done));
      expect(tips.fetchCount, 1);
      expect(tips.marked, isEmpty);
      expect(running, [true, false]);
      expect(tips.firstTipRequests, hasLength(1));
    });

    test('opt-in fails: false, no request, firstTip unchanged', () async {
      _captureLogs();
      profiles.weeklyTipsError = Exception('offline');
      final c = container();

      expect(await accept(c), isFalse);
      await _settle();

      expect(profiles.weeklyTipsWrites, [true]);
      expect(weeklyTipsOf(c), isFalse);
      expect(entries.recentMealsSince, isEmpty);
      expect(tips.firstTipRequests, isEmpty);
      expect(rewardsOf(c), _offered);
      expect(c.read(firstTipProvider), isFalse);
    });

    test('no user, no journey or no profile: false, nothing written or '
        'asked', () async {
      _captureLogs();
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

    test('after a restart with a request stored: none', () async {
      const stored = JourneyRewards(
        earnedDay: 3,
        tipOffer: TipOffer.accepted,
        firstTip: FirstTipState.requested,
      );
      final c = container(rewards: stored);

      expect(await accept(c), isTrue);
      await _settle();

      expect(tips.firstTipRequests, isEmpty);
      expect(profiles.weeklyTipsWrites, isEmpty);
      expect(rewardsOf(c), stored);
      expect(c.read(firstTipProvider), isFalse);
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
      expect(c.read(firstTipProvider), isFalse);

      expect(await accept(c), isTrue);
      await _settle();
      expect(tips.firstTipRequests, hasLength(1));
    }

    for (final (name, error, logged) in [
      ('500', const FirstTipException(500), '500'),
      ('429', const FirstTipException(429), '429'),
      ('transport', const FirstTipException(), 'no status'),
    ]) {
      test('$name: failed, still opted in, one request', () async {
        final logs = _captureLogs();
        tips.firstTipError = error;
        final c = container();

        expect(await accept(c), isTrue);
        await _settle();

        await expectFailedOnce(c);
        expect(tips.marked, isEmpty);
        expect(logs, contains(contains(logged)));
        _expectNoMeals(logs);
      });
    }

    test('timeout: failed, still opted in, one request', () {
      fakeAsync((async) {
        final logs = _captureLogs();
        tips.firstTipGate = Completer<void>(); // never answers
        final c = container();
        bool? accepted;
        accept(c).then((v) => accepted = v);
        async.flushMicrotasks();
        expect(accepted, isTrue);
        expect(c.read(firstTipProvider), isTrue);

        async.elapse(AppConstants.firstTipTimeout - const Duration(seconds: 1));
        expect(rewardsOf(c)!.firstTip, FirstTipState.requested);

        async.elapse(const Duration(seconds: 2));
        expect(rewardsOf(c)!.firstTip, FirstTipState.failed);
        expect(weeklyTipsOf(c), isTrue);
        expect(tips.firstTipRequests, hasLength(1));
        expect(tips.fetchCount, 0);
        expect(c.read(firstTipProvider), isFalse);
        _expectNoMeals(logs);
      });
    });

    test('200 without tips: failed, the set stamped seen', () async {
      _captureLogs();
      tips.firstTipSet = testRecommendation(
        id: 'empty',
        summary: 'Leider konnte keine Analyse durchgeführt werden.',
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
      _captureLogs();
      final c = container();

      expect(await accept(c), isTrue);
      await _settle();

      await expectFailedOnce(c);
      expect(tips.marked, isEmpty);
    });

    test('a failed stamp is only logged', () async {
      final logs = _captureLogs();
      tips
        ..firstTipSet = testRecommendation(id: 'empty')
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

  group('the user changed meanwhile', () {
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

    /// A container over the stored rewards, read.
    Future<ProviderContainer> stored() async {
      final c = container(
        storedRewards: true,
        overrides: [recipeRepositoryProvider.overrideWithValue(recipes)],
      );
      c.listen(journeyRewardsProvider, (_, _) {});
      await _settle();
      expect(rewardsOf(c)!.tipOffer, TipOffer.offered);
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

    test(
      'the user changed meanwhile: nothing stored for the new user',
      () async {
        final logs = _captureLogs();
        final aiCall = Completer<void>();
        tips
          ..firstTipGate = aiCall
          ..firstTipSet = _set;
        final c = await stored();

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
        expect(c.read(firstTipProvider), isFalse);
        expect(logs, contains(startsWith('FirstTip [WARN]')));
      },
    );

    test('a switch during the opt-in write: false, no request, nothing '
        'stored for the new user', () async {
      _captureLogs();
      final optIn = Completer<void>();
      profiles.gate = optIn;
      final c = await stored();

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
