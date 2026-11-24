// ignore_for_file: invalid_use_of_internal_member
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/src/internals.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/models/journey_rewards.dart';
import 'package:belly_buddy/models/recommendation.dart';
import 'package:belly_buddy/providers/buddy_offers_provider.dart';
import 'package:belly_buddy/providers/buddy_provider.dart';
import 'package:belly_buddy/providers/insights_provider.dart';
import 'package:belly_buddy/providers/journey_provider.dart';
import 'package:belly_buddy/providers/journey_rewards_provider.dart';
import 'package:belly_buddy/providers/profile_provider.dart';
import 'package:belly_buddy/providers/recommendation_provider.dart';
import 'package:belly_buddy/repositories/buddy_repository.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';
import 'package:belly_buddy/repositories/recipe_repository.dart';
import 'package:belly_buddy/repositories/recommendation_repository.dart';

import '../helpers/fakes.dart';
import '../helpers/fixtures.dart';
import '../helpers/riverpod_helpers.dart';

/// The signed-in user's id, switchable.
final _user = SwitchableUserId();

void main() {
  // The foreground signal (an AppLifecycleListener) needs the binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime(2026, 11, 23, 14);
  late FakeEntryRepository entryRepo;
  late FakeRecommendationRepository tips;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Unlocked: 7 active days, 3 gut-feeling entries.
    entryRepo = FakeEntryRepository()
      ..insightSource = insightSourceFor(
        activeDays: 7,
        gutFeelings: 3,
        now: now,
      );
    // Nothing new: the default set was seen.
    tips = FakeRecommendationRepository();
  });

  /// Pumps the event queue until the journey is decided and, on it, its
  /// rewards are read: both land a few microtask hops after the insights.
  Future<void> untilJourneySettled(ProviderContainer c) async {
    bool settled() => switch (c.read(journeyProvider)) {
      true => c.read(journeyRewardsProvider) != null,
      false => true,
      null => false,
    };
    for (var rounds = 0; !settled(); rounds++) {
      if (rounds == 20) fail('the journey never settled');
      await pumpEventQueue();
    }
  }

  /// A container whose weekly tips are [weeklyTips] (null: profile not
  /// known), with the offers listened to, the insights and tips loaded and,
  /// unless [journeyUndecided], the journey settled
  /// ([untilJourneySettled]).
  Future<ProviderContainer> loaded({
    bool? weeklyTips = false,
    List<Override> overrides = const [],
    bool journeyUndecided = false,
  }) async {
    final c = ProviderContainer.test(
      overrides: [
        entryRepositoryProvider.overrideWithValue(entryRepo),
        recommendationRepositoryProvider.overrideWithValue(tips),
        recipeRepositoryProvider.overrideWithValue(FakeRecipeRepository()),
        buddyRepositoryProvider.overrideWithValue(FakeBuddyRepository()),
        _user.override,
        buddyClockProvider.overrideWithValue(() => now),
        profileProviderSeededWith(
          weeklyTips == null
              ? null
              : testUserProfile(weeklyTipsEnabled: weeklyTips),
        ),
        ...overrides,
      ],
    );
    c.listen(buddyOffersProvider, (_, _) {});
    await c.read(insightsProvider.future);
    await c.read(recommendationProvider.notifier).fetchRecommendations();
    if (!journeyUndecided) await untilJourneySettled(c);
    return c;
  }

  /// [n] active days before today, no Bauchgefühl: a journey user on day
  /// [n] (locked).
  void journeyDays(int n) => entryRepo.insightSource = insightSourceFor(
    activeDays: n,
    gutFeelings: 0,
    now: now,
  );

  /// Hands every offer to the Buddy, as Home does.
  Future<void> offerAll(ProviderContainer c) async {
    final buddy = c.read(buddyProvider.notifier);
    for (final MapEntry(key: kind, value: suffix)
        in c.read(buddyOffersProvider).entries) {
      await buddy.offerAnnouncement(kind, suffix: suffix);
    }
  }

  /// The Buddy's pending announcements, once he loaded.
  Future<List<BuddyAnnouncement>> pending(ProviderContainer c) async =>
      (await c.read(buddyProvider.future))!.announcements;

  /// The flag of [kind] with [suffix] for the signed-in user.
  String flag(BuddyAnnouncement kind, String suffix) =>
      '${AppConstants.keyBuddyAnnouncedPrefix}${testUserId}_${kind.name}_'
      '$suffix';

  group('buddyOffersProvider', () {
    test('an unseen set: tipsArrived with its id', () async {
      tips.sets = [testRecommendation(id: 'rec-1')];
      final c = await loaded(weeklyTips: true);

      expect(c.read(buddyOffersProvider), {
        BuddyAnnouncement.tipsArrived: 'rec-1',
      });
    });

    test('an unseen set without tips: no tipsArrived', () async {
      tips.sets = [testRecommendation(id: 'empty', recommendations: [])];
      final c = await loaded(weeklyTips: true);

      expect(c.read(buddyOffersProvider), isEmpty);
    });

    test('all seen: nothing', () async {
      final c = await loaded(weeklyTips: true);

      expect(c.read(buddyOffersProvider), isEmpty);
    });

    test('unlocked and weekly tips off: the weekly-tips offer', () async {
      final c = await loaded();

      expect(c.read(weeklyTipsOfferDueProvider), isTrue);
      expect(
        c.read(buddyOffersProvider),
        containsPair(BuddyAnnouncement.weeklyTipsOffer, 'once'),
      );
    });

    test('unlocked and weekly tips on: no offer', () async {
      final c = await loaded(weeklyTips: true);

      expect(c.read(weeklyTipsOfferDueProvider), isFalse);
      expect(
        c.read(buddyOffersProvider),
        isNot(contains(BuddyAnnouncement.weeklyTipsOffer)),
      );
    });

    test('locked: no offer', () async {
      entryRepo.insightSource = insightSourceFor(
        activeDays: 7,
        gutFeelings: 2,
        now: now,
      );
      final c = await loaded();

      expect(c.read(insightsProvider).value!.unlocked, isFalse);
      expect(c.read(weeklyTipsOfferDueProvider), isFalse);
      expect(c.read(buddyOffersProvider), isEmpty);
    });

    test('profile unknown: no offer', () async {
      final c = await loaded(weeklyTips: null);

      expect(c.read(weeklyTipsOfferDueProvider), isFalse);
      expect(c.read(buddyOffersProvider), isEmpty);
    });

    test('insights reloading for another user: no offer', () async {
      final c = await loaded();
      expect(c.read(weeklyTipsOfferDueProvider), isTrue);

      // The next user's insights load; the state keeps the previous
      // user's unlocked value meanwhile.
      entryRepo.holdInsightSource = true;
      _user.set(c, 'u2');
      final insights = c.read(insightsProvider);
      expect(insights, isA<AsyncLoading<Object?>>());
      expect(insights.value!.unlocked, isTrue);

      expect(c.read(weeklyTipsOfferDueProvider), isFalse);
      expect(c.read(buddyOffersProvider), isEmpty);
    });

    test(
      'insights refreshed (holding the value): no offer until done',
      () async {
        final c = await loaded();
        entryRepo.holdInsightSource = true;

        c.invalidate(insightsProvider);
        final insights = c.read(insightsProvider);
        expect(insights, isA<AsyncData<Object?>>());
        expect(insights.isLoading, isTrue);
        expect(insights.value!.unlocked, isTrue);
        expect(c.read(weeklyTipsOfferDueProvider), isFalse);

        entryRepo.heldInsightSources.single.complete(entryRepo.insightSource);
        await c.read(insightsProvider.future);
        expect(c.read(weeklyTipsOfferDueProvider), isTrue);
      },
    );
  });

  group('buddyOffersProvider on the journey', () {
    test('journey undecided: no offer', () async {
      // Unlocked and off: today's rule would offer it.
      final c = await loaded(
        overrides: [journeySeededWith(null)],
        journeyUndecided: true,
      );

      expect(c.read(insightsProvider).value!.unlocked, isTrue);
      expect(c.read(weeklyTipsOfferDueProvider), isFalse);
      expect(c.read(firstTipOfferDueProvider), isFalse);
      expect(c.read(buddyOffersProvider), isEmpty);
    });

    test("journey false (past day 7): today's rule", () async {
      SharedPreferences.setMockInitialValues({
        '${AppConstants.keyInsightJourneyPrefix}$testUserId': false,
      });
      final unlocked = await loaded();
      expect(unlocked.read(journeyProvider), isFalse);
      expect(unlocked.read(weeklyTipsOfferDueProvider), isTrue);
      expect(unlocked.read(firstTipOfferDueProvider), isFalse);
      expect(unlocked.read(buddyOffersProvider), {
        BuddyAnnouncement.weeklyTipsOffer: 'once',
      });

      journeyDays(3);
      final locked = await loaded();
      expect(locked.read(journeyProvider), isFalse);
      expect(locked.read(weeklyTipsOfferDueProvider), isFalse);
      expect(locked.read(buddyOffersProvider), isEmpty);
    });

    test('journey true, day 3, weekly off → firstTipOffer once', () async {
      journeyDays(3);
      final c = await loaded();

      expect(c.read(journeyProvider), isTrue);
      expect(c.read(weeklyTipsOfferDueProvider), isFalse);
      expect(c.read(buddyOffersProvider), {
        BuddyAnnouncement.firstTipOffer: 'once',
      });
      await offerAll(c);
      await offerAll(c);
      expect(await pending(c), [BuddyAnnouncement.firstTipOffer]);
      expect(c.read(buddyProvider).value!.announcementKeys, {
        BuddyAnnouncement.firstTipOffer: flag(
          BuddyAnnouncement.firstTipOffer,
          'once',
        ),
      });
    });

    test('the day-3 offer comes while the insights are still locked', () async {
      journeyDays(3);
      final c = await loaded();

      expect(c.read(insightsProvider).value!.unlocked, isFalse);
      expect(c.read(firstTipOfferDueProvider), isTrue);
    });

    group('a journey user flagged for the old shared weeklyTipsOffer', () {
      /// Day 3 with [offer], and the flag the day-3 offer used to share
      /// with the weekly tips' set.
      Future<ProviderContainer> flaggedWith(TipOffer offer) async {
        SharedPreferences.setMockInitialValues({
          '${AppConstants.keyInsightJourneyPrefix}$testUserId': true,
          '${AppConstants.keyJourneyRewardsPrefix}$testUserId': jsonEncode(
            JourneyRewards(earnedDay: 3, tipOffer: offer).toJson(),
          ),
          flag(BuddyAnnouncement.weeklyTipsOffer, 'once'): true,
        });
        journeyDays(3);
        final c = await loaded();
        await offerAll(c);
        return c;
      }

      test('answered: never offered again', () async {
        final c = await flaggedWith(TipOffer.declined);

        expect(c.read(firstTipOfferDueProvider), isFalse);
        expect(
          await pending(c),
          isNot(contains(BuddyAnnouncement.firstTipOffer)),
        );
      });

      test('unanswered (the opt-in failed): offered once more', () async {
        final c = await flaggedWith(TipOffer.offered);

        expect(await pending(c), contains(BuddyAnnouncement.firstTipOffer));
      });
    });

    test('opted in before day 3: journeyReward day 3, no offer', () async {
      journeyDays(3);
      final c = await loaded(weeklyTips: true);

      expect(c.read(firstTipOfferDueProvider), isFalse);
      expect(c.read(buddyOffersProvider), {
        BuddyAnnouncement.journeyReward: 'day3',
      });
    });

    test("day 2 → journeyReward: 'day2'", () async {
      journeyDays(2);
      final c = await loaded();

      expect(c.read(buddyOffersProvider), {
        BuddyAnnouncement.journeyReward: 'day2',
      });
    });

    test('a newer day replaces a pending older one', () async {
      journeyDays(4);
      final c = await loaded();
      await offerAll(c);
      expect(
        c
            .read(buddyProvider)
            .value!
            .announcementKeys[BuddyAnnouncement.journeyReward],
        flag(BuddyAnnouncement.journeyReward, 'day4'),
      );

      // Another active day: the insights move to day 5.
      journeyDays(5);
      c.invalidate(insightsProvider);
      await c.read(insightsProvider.future);
      await pumpEventQueue();
      expect(
        c.read(buddyOffersProvider),
        containsPair(BuddyAnnouncement.journeyReward, 'day5'),
      );
      await offerAll(c);

      final status = c.read(buddyProvider).value!;
      expect(
        status.announcements.where((a) => a == BuddyAnnouncement.journeyReward),
        hasLength(1),
      );
      expect(
        status.announcementKeys[BuddyAnnouncement.journeyReward],
        endsWith('_day5'),
      );
    });

    test('a flagged day is not offered again', () async {
      SharedPreferences.setMockInitialValues({
        flag(BuddyAnnouncement.journeyReward, 'day2'): true,
      });
      expect(
        flag(BuddyAnnouncement.journeyReward, 'day2'),
        'buddy_announced_${testUserId}_journeyReward_day2',
      );
      journeyDays(2);
      final c = await loaded();
      expect(c.read(buddyOffersProvider), {
        BuddyAnnouncement.journeyReward: 'day2',
      });

      await offerAll(c);

      expect(await pending(c), isEmpty);
    });

    test("unlocked journey user → patternsUnlocked 'once'; with the flag set "
        '→ not queued', () async {
      SharedPreferences.setMockInitialValues({
        '${AppConstants.keyInsightJourneyPrefix}$testUserId': true,
      });
      final c = await loaded(weeklyTips: true);
      expect(c.read(insightsProvider).value!.unlocked, isTrue);
      expect(c.read(buddyOffersProvider), {
        BuddyAnnouncement.patternsUnlocked: 'once',
      });
      await offerAll(c);
      expect(await pending(c), [BuddyAnnouncement.patternsUnlocked]);

      // Played, then the app restarts.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(
        flag(BuddyAnnouncement.patternsUnlocked, 'once'),
        true,
      );
      final restarted = await loaded(weeklyTips: true);
      expect(
        restarted.read(buddyOffersProvider),
        containsPair(BuddyAnnouncement.patternsUnlocked, 'once'),
      );
      await offerAll(restarted);
      expect(await pending(restarted), isEmpty);
    });

    test('day 7 with the day-3 offer still open: „Muster frei!" before the '
        'offer, after new tips, and queued in that order', () async {
      SharedPreferences.setMockInitialValues({
        '${AppConstants.keyInsightJourneyPrefix}$testUserId': true,
      });
      // An unseen set with a tip: „Neue Tipps" stays first.
      tips = FakeRecommendationRepository(sets: [testRecommendation()]);
      final c = await loaded();

      expect(c.read(insightsProvider).value!.unlocked, isTrue);
      expect(c.read(journeyRewardsProvider)!.tipOffer, TipOffer.offered);
      expect(c.read(buddyOffersProvider).keys.toList(), [
        BuddyAnnouncement.tipsArrived,
        BuddyAnnouncement.patternsUnlocked,
        BuddyAnnouncement.firstTipOffer,
      ]);
      await offerAll(c);
      expect(await pending(c), [
        BuddyAnnouncement.tipsArrived,
        BuddyAnnouncement.patternsUnlocked,
        BuddyAnnouncement.firstTipOffer,
      ]);
    });

    test('journey false: no reward, no patternsUnlocked', () async {
      // Unlocked past day 7 before this release: no celebration either.
      final c = await loaded(weeklyTips: true);

      expect(c.read(journeyProvider), isFalse);
      expect(c.read(buddyOffersProvider), isEmpty);
    });

    test("firstTip failed → firstTipFailed 'once'", () async {
      const rewards = JourneyRewards(
        earnedDay: 3,
        tipOffer: TipOffer.accepted,
        firstTip: FirstTipState.failed,
      );
      SharedPreferences.setMockInitialValues({
        '${AppConstants.keyInsightJourneyPrefix}$testUserId': true,
        '${AppConstants.keyJourneyRewardsPrefix}$testUserId': jsonEncode(
          rewards.toJson(),
        ),
      });
      journeyDays(3);
      final c = await loaded(weeklyTips: true);

      expect(c.read(buddyOffersProvider), {
        BuddyAnnouncement.firstTipFailed: 'once',
      });
    });
  });

  group('offerStillAppliesProvider (as an offer plays)', () {
    ProviderContainer container({
      Recommendation? unseen,
      bool? weeklyTips,
      bool? journey = false,
      JourneyRewards? rewards,
    }) => ProviderContainer.test(
      overrides: [
        unseenTipSetProvider.overrideWithValue(unseen),
        weeklyTipsEnabledProvider.overrideWithValue(weeklyTips),
        journeySeededWith(journey),
        journeyRewardsSeededWith(rewards),
      ],
    );

    test('tipsArrived: while the set is unseen', () {
      final unseen = container(unseen: testRecommendation());
      expect(
        unseen.read(offerStillAppliesProvider(BuddyAnnouncement.tipsArrived)),
        isTrue,
      );
      expect(
        container().read(
          offerStillAppliesProvider(BuddyAnnouncement.tipsArrived),
        ),
        isFalse,
      );
    });

    test('weeklyTipsOffer: until the weekly tips are known to be on; a '
        'profile still loading does not withdraw it', () {
      bool applies(bool? weeklyTips) => container(
        weeklyTips: weeklyTips,
      ).read(offerStillAppliesProvider(BuddyAnnouncement.weeklyTipsOffer));

      expect(applies(false), isTrue);
      expect(applies(null), isTrue);
      expect(applies(true), isFalse);
    });

    test('firstTipOffer: until the offer is answered (here or in „Deine '
        'Belohnungen") or the weekly tips are on; never once skipped', () {
      bool applies(TipOffer? offer, {bool? weeklyTips = false}) => container(
        weeklyTips: weeklyTips,
        journey: true,
        rewards: JourneyRewards(earnedDay: 3, tipOffer: offer),
      ).read(offerStillAppliesProvider(BuddyAnnouncement.firstTipOffer));

      expect(applies(TipOffer.offered), isTrue);
      expect(applies(TipOffer.offered, weeklyTips: null), isTrue);
      expect(applies(TipOffer.offered, weeklyTips: true), isFalse);
      expect(applies(null), isTrue);
      expect(applies(TipOffer.declined), isFalse);
      expect(applies(TipOffer.accepted), isFalse);
      expect(applies(TipOffer.skipped), isFalse);
      // The rewards not read yet: never withdrawn meanwhile.
      expect(
        container(
          weeklyTips: false,
          journey: true,
        ).read(offerStillAppliesProvider(BuddyAnnouncement.firstTipOffer)),
        isTrue,
      );
    });

    test('each offer only on its side of the journey; neither while it is '
        'undecided', () {
      bool applies(BuddyAnnouncement offer, bool? journey) => container(
        weeklyTips: false,
        journey: journey,
        rewards: const JourneyRewards(earnedDay: 3, tipOffer: TipOffer.offered),
      ).read(offerStillAppliesProvider(offer));

      expect(applies(BuddyAnnouncement.weeklyTipsOffer, false), isTrue);
      expect(applies(BuddyAnnouncement.weeklyTipsOffer, true), isFalse);
      expect(applies(BuddyAnnouncement.weeklyTipsOffer, null), isFalse);
      expect(applies(BuddyAnnouncement.firstTipOffer, true), isTrue);
      expect(applies(BuddyAnnouncement.firstTipOffer, false), isFalse);
      expect(applies(BuddyAnnouncement.firstTipOffer, null), isFalse);
    });

    test('the others always', () {
      final c = container(weeklyTips: true);
      for (final a in [
        BuddyAnnouncement.saverUsed,
        BuddyAnnouncement.streakBroken,
        BuddyAnnouncement.saverEarned,
        BuddyAnnouncement.goalReached,
      ]) {
        expect(c.read(offerStillAppliesProvider(a)), isTrue, reason: '$a');
      }
    });

    test('offerStillApplies: the new kinds always apply', () {
      final c = container(weeklyTips: true, journey: null);
      for (final a in [
        BuddyAnnouncement.journeyReward,
        BuddyAnnouncement.patternsUnlocked,
        BuddyAnnouncement.firstTipFailed,
      ]) {
        expect(c.read(offerStillAppliesProvider(a)), isTrue, reason: '$a');
      }
    });
  });
}
