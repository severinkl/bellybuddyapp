import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/journey/journey_rules.dart';
import '../utils/settled_value.dart';
import 'buddy_provider.dart';
import 'insights_provider.dart';
import 'journey_provider.dart';
import 'journey_rewards_provider.dart';
import 'profile_provider.dart';
import 'recommendation_provider.dart';
import 'tolerance_test_offer_provider.dart';

/// The flag suffix of the announcements offered once per user, ever:
/// [BuddyAnnouncement.weeklyTipsOffer], [BuddyAnnouncement.firstTipOffer],
/// [BuddyAnnouncement.patternsUnlocked] and
/// [BuddyAnnouncement.firstTipFailed].
const onceSuffix = 'once';

/// The flag suffix of [BuddyAnnouncement.journeyReward], followed by the
/// day: `day<n>`, once per journey day.
const journeyRewardSuffix = 'day';

/// Whether the Buddy offers the weekly tips off the journey
/// ([journeyProvider] false): he sees first patterns (the signed-in user's
/// insights are loaded and unlocked) and the weekly tips are known to be
/// off. Only settled insights count: while another user's insights load,
/// the state still holds the previous user's. On the journey (that is
/// [firstTipOfferDueProvider]) and while undecided: never.
final weeklyTipsOfferDueProvider = Provider<bool>(
  (ref) =>
      ref.watch(journeyProvider) == false &&
      (ref.watch(insightsProvider).settledValue?.unlocked ?? false) &&
      ref.watch(weeklyTipsEnabledProvider) == false,
);

/// Whether the Buddy offers a journey user day 3's first tip: the offer
/// waits for its answer ([tipOfferDue]), the insights locked or not. Off
/// the journey (no rewards): never.
final firstTipOfferDueProvider = Provider<bool>((ref) {
  final rewards = ref.watch(journeyRewardsProvider);
  return rewards != null &&
      tipOfferDue(rewards, weeklyTips: ref.watch(weeklyTipsEnabledProvider));
});

/// The announcements Home offers the Buddy while they apply, each with its
/// flag suffix ([BuddyNotifier.offerAnnouncement]), in this order:
/// - `tipsArrived` for the unseen tip set (once per set);
/// - `journeyReward` for the newest earned day of 1–6
///   ([journeyRewardAnnouncementProvider]), once per day: a newer day
///   replaces a pending older one;
/// - `patternsUnlocked` once the journey's first patterns were unlocked
///   ([patternsUnlockedDueProvider]; never off the journey: no rewards);
/// - `firstTipOffer` while it is due ([firstTipOfferDueProvider]): after
///   „Muster frei!", so a journey user who reaches day 7 with the day-3
///   offer still open sees the celebration first and the offer once back
///   on Home;
/// - `weeklyTipsOffer` while it is due ([weeklyTipsOfferDueProvider]);
/// - `firstTipFailed` once the day-3 first tip failed;
/// - `testOffer` while a subject is due ([toleranceTestOfferDueProvider]),
///   once per subject ([testOfferSuffix]);
/// - `testReintro` on a test's first reintroduction day
///   ([testReintroDueProvider]) and `testDone` while its result is shown
///   ([testDoneDueProvider]), once per test.
final buddyOffersProvider = Provider<Map<BuddyAnnouncement, String>>((ref) {
  final set = ref.watch(unseenTipSetProvider);
  final day = ref.watch(journeyRewardAnnouncementProvider);
  final testOffer = ref.watch(toleranceTestOfferDueProvider);
  final reintro = ref.watch(testReintroDueProvider);
  final done = ref.watch(testDoneDueProvider);
  return {
    if (set != null) BuddyAnnouncement.tipsArrived: set.id,
    if (day != null)
      BuddyAnnouncement.journeyReward: '$journeyRewardSuffix$day',
    if (ref.watch(patternsUnlockedDueProvider))
      BuddyAnnouncement.patternsUnlocked: onceSuffix,
    if (ref.watch(firstTipOfferDueProvider))
      BuddyAnnouncement.firstTipOffer: onceSuffix,
    if (ref.watch(weeklyTipsOfferDueProvider))
      BuddyAnnouncement.weeklyTipsOffer: onceSuffix,
    if (ref.watch(firstTipFailedProvider))
      BuddyAnnouncement.firstTipFailed: onceSuffix,
    if (testOffer != null)
      BuddyAnnouncement.testOffer: testOfferSuffix(testOffer),
    if (reintro != null)
      BuddyAnnouncement.testReintro: testReintroSuffix(reintro),
    if (done != null) BuddyAnnouncement.testDone: testDoneSuffix(done),
  };
});

/// Whether an announcement still applies as the Buddy plays it: when its
/// cue starts, and again right before its sheet opens (it may have waited
/// while Home was hidden). „Neue Tipps" needs the set still unseen. Both
/// offers go once the weekly tips are known to be on, so a profile still
/// (re)loading never withdraws a one-time offer (and so never has it marked
/// shown unplayed). The weekly-tips offer applies off the journey only, the
/// first-tip offer on it only, until day 3's offer was answered (e.g. in
/// „Deine Belohnungen") or skipped (the weekly tips were already on at day
/// 3). While the journey is undecided neither applies:
/// that is only before the first decision (signed out, a new user's
/// insights still loading), so this drops at most a previous user's cue
/// (its flag is that user's). A reached goal applies while it is still
/// the goal: one picked meanwhile (in „Dein Streak") withdraws it. A day's
/// reward applies while there is a day to announce
/// ([journeyRewardAnnouncementProvider]): superseded (day 3's offer stands
/// for it, the rewards gone), it doesn't celebrate for nothing. A test
/// offer applies while its subject is still the one to offer, its stats
/// loading included ([testOfferStillApplies]); a test line while its
/// condition holds for its test ([testLineStillApplies]). The others
/// always apply.
final offerStillAppliesProvider = Provider.family<bool, BuddyAnnouncement>(
  (ref, announcement) => switch (announcement) {
    BuddyAnnouncement.tipsArrived => ref.watch(unseenTipSetProvider) != null,
    BuddyAnnouncement.weeklyTipsOffer =>
      ref.watch(weeklyTipsEnabledProvider) != true &&
          ref.watch(journeyProvider) == false,
    BuddyAnnouncement.firstTipOffer => _firstTipOfferApplies(ref),
    BuddyAnnouncement.goalReached => _goalStillApplies(ref),
    BuddyAnnouncement.journeyReward =>
      ref.watch(journeyRewardAnnouncementProvider) != null,
    BuddyAnnouncement.testOffer => testOfferStillApplies(
      ref,
      suffix: _pendingSuffix(ref, announcement),
    ),
    BuddyAnnouncement.testReintro => testLineStillApplies(
      ref,
      done: false,
      suffix: _pendingSuffix(ref, announcement),
    ),
    BuddyAnnouncement.testDone => testLineStillApplies(
      ref,
      done: true,
      suffix: _pendingSuffix(ref, announcement),
    ),
    BuddyAnnouncement.saverUsed ||
    BuddyAnnouncement.streakBroken ||
    BuddyAnnouncement.saverEarned ||
    BuddyAnnouncement.patternsUnlocked ||
    BuddyAnnouncement.firstTipFailed => true,
  },
);

/// The flag suffix of the pending [kind] (its flag is
/// `<prefix><userId>_<kind>_<suffix>`); null while none is pending.
String? _pendingSuffix(Ref ref, BuddyAnnouncement kind) {
  final key = ref.watch(buddyProvider).value?.announcementKeys[kind];
  final marker = '_${kind.name}_';
  final at = key?.indexOf(marker) ?? -1;
  return at < 0 ? null : key!.substring(at + marker.length);
}

/// [offerStillAppliesProvider] of a reached goal: the goal it was announced
/// for ([BuddyStatus.reachedGoal]) is still the goal; unknown, it applies.
bool _goalStillApplies(Ref ref) {
  final status = ref.watch(buddyProvider).value;
  final reached = status?.reachedGoal;
  return reached == null || status!.state.streakGoal == reached;
}

/// [offerStillAppliesProvider] of the first-tip offer: on the journey,
/// while day 3 still waits for it ([Day3.waiting], [Day3.offerOpen]); its
/// rewards not read yet, never withdrawn meanwhile.
bool _firstTipOfferApplies(Ref ref) {
  final weeklyTips = ref.watch(weeklyTipsEnabledProvider);
  if (weeklyTips == true || ref.watch(journeyProvider) != true) return false;
  final rewards = ref.watch(journeyRewardsProvider);
  if (rewards == null) return true;
  return switch (day3Of(rewards, weeklyTips: weeklyTips)) {
    Day3.waiting || Day3.offerOpen => true,
    // Answered, or skipped (never offered): done.
    Day3.tip || Day3.recipe => false,
  };
}
