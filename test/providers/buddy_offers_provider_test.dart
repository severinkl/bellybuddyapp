import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:belly_buddy/models/recommendation.dart';
import 'package:belly_buddy/providers/buddy_offers_provider.dart';
import 'package:belly_buddy/providers/buddy_provider.dart';
import 'package:belly_buddy/providers/insights_provider.dart';
import 'package:belly_buddy/providers/profile_provider.dart';
import 'package:belly_buddy/providers/recommendation_provider.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';
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

  /// A container whose weekly tips are [weeklyTips] (null: profile not
  /// known), with the offers listened to and the insights and tips loaded.
  Future<ProviderContainer> loaded({bool? weeklyTips = false}) async {
    final c = ProviderContainer.test(
      overrides: [
        entryRepositoryProvider.overrideWithValue(entryRepo),
        recommendationRepositoryProvider.overrideWithValue(tips),
        _user.override,
        buddyClockProvider.overrideWithValue(() => now),
        weeklyTipsEnabledProvider.overrideWithValue(weeklyTips),
      ],
    );
    c.listen(buddyOffersProvider, (_, _) {});
    await c.read(insightsProvider.future);
    await c.read(recommendationProvider.notifier).fetchRecommendations();
    return c;
  }

  group('buddyOffersProvider', () {
    test('an unseen set: tipsArrived with its id', () async {
      tips.sets = [testRecommendation(id: 'rec-1')];
      final c = await loaded(weeklyTips: true);

      expect(c.read(buddyOffersProvider), {
        BuddyAnnouncement.tipsArrived: 'rec-1',
      });
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

  group('offerStillAppliesProvider (as an offer plays)', () {
    ProviderContainer container({Recommendation? unseen, bool? weeklyTips}) =>
        ProviderContainer.test(
          overrides: [
            unseenTipSetProvider.overrideWithValue(unseen),
            weeklyTipsEnabledProvider.overrideWithValue(weeklyTips),
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
  });
}
