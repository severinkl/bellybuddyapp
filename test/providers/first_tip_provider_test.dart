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

/// A saved set with two tips.
final _set = testRecommendation(
  id: 'first',
  recommendations: [
    testRecommendationItem(focus: true),
    testRecommendationItem(type: 'try', ingredient: 'Hafer', alternative: null),
  ],
);

/// The loads and writes in flight all landed.
Future<void> _settle() => pumpEventQueue(times: 100);

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
    entries = FakeEntryRepository();
    tips = FakeRecommendationRepository();
  });

  /// A container with [rewards] seeded (in memory), or with the stored
  /// rewards when [storedRewards]; with [_profile] loaded, no profile, or
  /// [profileLoading] (it loads [_profile] on `fetchProfile`).
  ProviderContainer container({
    JourneyRewards? rewards = _offered,
    bool noProfile = false,
    bool profileLoading = false,
    bool storedRewards = false,
    List<Override> overrides = const [],
  }) => ProviderContainer.test(
    overrides: [
      _user.override,
      profileRepositoryProvider.overrideWithValue(profiles),
      // Loading: the real notifier, loading until fetchProfile.
      if (!profileLoading)
        profileProviderSeededWith(noProfile ? null : _profile),
      entryRepositoryProvider.overrideWithValue(entries),
      recommendationRepositoryProvider.overrideWithValue(tips),
      buddyClockProvider.overrideWithValue(() => _now),
      if (!storedRewards) journeyRewardsSeededWith(rewards),
      ...overrides,
    ],
  );

  Future<FirstTipAcceptance> accept(ProviderContainer c) =>
      c.read(firstTipProvider.notifier).accept();

  JourneyRewards? rewardsOf(ProviderContainer c) =>
      c.read(journeyRewardsProvider);

  bool? weeklyTipsOf(ProviderContainer c) =>
      c.read(profileProvider).value?.weeklyTipsEnabled;

  group('accept', () {
    test('opt-in first, then one request with the profile', () async {
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
      // The opt-in write is on its way: nothing asked or answered.
      expect(tips.firstTipRequests, isEmpty);
      expect(rewardsOf(c), _offered);

      optIn.complete();
      expect(await accepted, FirstTipAcceptance.started);
      await _settle();

      expect(profiles.weeklyTipsWrites, [true]);
      expect(weeklyTipsOf(c), isTrue);
      // Stored before the call: the offer accepted, the request noted.
      expect(seen, [
        (TipOffer.accepted, null),
        (TipOffer.accepted, FirstTipState.requested),
      ]);
      final request = tips.firstTipRequests.single;
      expect(request.intolerances, ['Fruktose']);
      expect(request.diet, 'vegetarisch');

      aiCall.complete();
      await _settle();

      expect(seen.last, (TipOffer.accepted, FirstTipState.done));
      expect(tips.fetchCount, 1);
      expect(tips.marked, isEmpty);
      expect(tips.firstTipRequests, hasLength(1));
    });

    test('opt-in fails: failed, no request, firstTip unchanged', () async {
      captureLogs();
      profiles.weeklyTipsError = Exception('offline');
      final c = container();

      expect(await accept(c), FirstTipAcceptance.failed);
      await _settle();

      expect(profiles.weeklyTipsWrites, [true]);
      expect(weeklyTipsOf(c), isFalse);
      expect(tips.firstTipRequests, isEmpty);
      expect(rewardsOf(c), _offered);
    });

    test('no user, no journey or no profile: not ready, nothing written or '
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
        expect(await accept(c), FirstTipAcceptance.notReady);
      }
      await _settle();

      expect(profiles.weeklyTipsWrites, isEmpty);
      expect(tips.firstTipRequests, isEmpty);
      expect(rewardsOf(cases.first), _offered);
    });

    test('the profile (re)loading: waits for it, then switches on and asks '
        'with it', () async {
      final c = container(profileLoading: true);
      expect(c.read(profileProvider).isLoading, isTrue);

      final accepted = accept(c);
      await _settle();
      expect(profiles.weeklyTipsWrites, isEmpty);
      expect(rewardsOf(c), _offered);

      await c.read(profileProvider.notifier).fetchProfile();
      expect(await accepted, FirstTipAcceptance.started);
      await _settle();

      expect(profiles.weeklyTipsWrites, [true]);
      expect(rewardsOf(c)!.tipOffer, TipOffer.accepted);
      expect(tips.firstTipRequests.single.intolerances, ['Fruktose']);
    });

    test('the profile still loading after '
        '${AppConstants.firstTipProfileWait.inSeconds} s: not ready, nothing '
        'written or asked', () {
      fakeAsync((async) {
        captureLogs();
        final c = container(profileLoading: true);
        FirstTipAcceptance? accepted;
        accept(c).then((v) => accepted = v);

        async.elapse(
          AppConstants.firstTipProfileWait - const Duration(seconds: 1),
        );
        expect(accepted, isNull);
        async.elapse(const Duration(seconds: 2));

        expect(accepted, FirstTipAcceptance.notReady);
        expect(profiles.weeklyTipsWrites, isEmpty);
        expect(tips.firstTipRequests, isEmpty);
        expect(rewardsOf(c), _offered);
      });
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
      expect(both, [FirstTipAcceptance.started, FirstTipAcceptance.started]);
      expect(tips.firstTipRequests, hasLength(1));

      // While the request runs.
      expect(await accept(c), FirstTipAcceptance.started);
      await _settle();
      expect(tips.firstTipRequests, hasLength(1));

      aiCall.complete();
      await _settle();
      expect(rewardsOf(c)!.firstTip, FirstTipState.done);

      // After it is done.
      expect(await accept(c), FirstTipAcceptance.started);
      await _settle();

      expect(tips.firstTipRequests, hasLength(1));
      expect(profiles.weeklyTipsWrites, [true]);
      expect(rewardsOf(c)!.firstTip, FirstTipState.done);
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

      expect(await accept(c), FirstTipAcceptance.started);
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

        expect(await accept(c), FirstTipAcceptance.started);
        await _settle();

        await expectFailedOnce(c);
        expect(tips.marked, isEmpty);
        expect(logs.where((line) => line.contains('First tip failed')), [
          contains(logged),
        ]);
      });
    }

    test('timeout: failed, still opted in, one request', () {
      fakeAsync((async) {
        captureLogs();
        tips.firstTipGate = Completer<void>(); // never answers
        final c = container();
        FirstTipAcceptance? accepted;
        accept(c).then((v) => accepted = v);
        async.flushMicrotasks();
        expect(accepted, FirstTipAcceptance.started);

        async.elapse(AppConstants.firstTipTimeout - const Duration(seconds: 1));
        expect(rewardsOf(c)!.firstTip, FirstTipState.requested);

        async.elapse(const Duration(seconds: 2));
        expect(rewardsOf(c)!.firstTip, FirstTipState.failed);
        expect(weeklyTipsOf(c), isTrue);
        expect(tips.firstTipRequests, hasLength(1));
        expect(tips.fetchCount, 0);
      });
    });

    test('any other error: failed, logged with its type', () async {
      final logs = captureLogs();
      tips.firstTipError = StateError('broken');
      final c = container();

      expect(await accept(c), FirstTipAcceptance.started);
      await _settle();

      await expectFailedOnce(c);
      expect(logs, contains('FirstTip [ERROR]: First tip failed (StateError)'));
    });

    test('200 without tips: failed, nothing stamped (never „new": the tips '
        'skip an empty set)', () async {
      captureLogs();
      tips.firstTipSet = testRecommendation(
        id: 'empty',
        summary: 'Leider konnte keine Analyse durchgeführt werden.',
        recommendations: [],
      );
      final c = container();

      expect(await accept(c), FirstTipAcceptance.started);
      await _settle();

      await expectFailedOnce(c);
      expect(tips.marked, isEmpty);
    });

    test('an answer without id: failed', () async {
      captureLogs();
      final c = container();

      expect(await accept(c), FirstTipAcceptance.started);
      await _settle();

      await expectFailedOnce(c);
      expect(tips.marked, isEmpty);
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
      expect(await accept(first), FirstTipAcceptance.started);
      await _settle();
      expect(tips.firstTipRequests, hasLength(1));
      first.dispose();

      final restarted = await stored();
      const requested = (TipOffer.accepted, FirstTipState.requested);
      expect(answerOf(rewardsOf(restarted)), requested);

      expect(await accept(restarted), FirstTipAcceptance.started);
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

        expect(await accept(c), FirstTipAcceptance.started);
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

      expect(await accepted, FirstTipAcceptance.failed);
      await _settle();

      expect(tips.firstTipRequests, isEmpty);
      expect(answerOf(rewardsOf(c)), open);
      expect(answerOf(await storedFor('u2')), open);
      expect(answerOf(await storedFor('u1')), open);
    });
  });
}
