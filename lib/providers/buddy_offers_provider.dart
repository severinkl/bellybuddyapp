import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/journey_rewards.dart';
import '../services/journey/journey_rules.dart';
import '../utils/settled_value.dart';
import 'buddy_provider.dart';
import 'insights_provider.dart';
import 'journey_provider.dart';
import 'journey_rewards_provider.dart';
import 'profile_provider.dart';
import 'recommendation_provider.dart';

/// The flag suffix of the announcements offered once per user, ever:
/// [BuddyAnnouncement.weeklyTipsOffer], [BuddyAnnouncement.firstTipOffer],
/// [BuddyAnnouncement.patternsUnlocked] and
/// [BuddyAnnouncement.firstTipFailed].
const onceSuffix = 'once';

/// The flag suffix of [BuddyAnnouncement.weeklyTipsOffer].
const weeklyTipsOfferSuffix = onceSuffix;

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
/// - `patternsUnlocked` once the journey's first patterns were unlocked;
/// - `firstTipOffer` while it is due ([firstTipOfferDueProvider]): after
///   „Muster frei!", so a journey user who reaches day 7 with the day-3
///   offer still open sees the celebration first and the offer once back
///   on Home;
/// - `weeklyTipsOffer` while it is due ([weeklyTipsOfferDueProvider]);
/// - `firstTipFailed` once the day-3 first tip failed.
final buddyOffersProvider = Provider<Map<BuddyAnnouncement, String>>((ref) {
  final set = ref.watch(unseenTipSetProvider);
  final day = ref.watch(journeyRewardAnnouncementProvider);
  return {
    if (set != null) BuddyAnnouncement.tipsArrived: set.id,
    if (day != null)
      BuddyAnnouncement.journeyReward: '$journeyRewardSuffix$day',
    if (ref.watch(patternsUnlockedDueProvider) &&
        ref.watch(journeyProvider) == true)
      BuddyAnnouncement.patternsUnlocked: onceSuffix,
    if (ref.watch(firstTipOfferDueProvider))
      BuddyAnnouncement.firstTipOffer: onceSuffix,
    if (ref.watch(weeklyTipsOfferDueProvider))
      BuddyAnnouncement.weeklyTipsOffer: weeklyTipsOfferSuffix,
    if (ref.watch(firstTipFailedProvider))
      BuddyAnnouncement.firstTipFailed: onceSuffix,
  };
});

/// Whether an announcement still applies as the Buddy plays it: when its
/// cue starts, and again right before its sheet opens (it may have waited
/// while Home was hidden). „Neue Tipps" needs the set still unseen. Both
/// offers go once the weekly tips are known to be on, so a profile still
/// (re)loading never withdraws a one-time offer (and so never has it marked
/// shown unplayed). The weekly-tips offer applies off the journey only, the
/// first-tip offer on it only, until day 3's offer was answered (e.g. in
/// „Deine Belohnungen"). While the journey is undecided neither applies:
/// that is only before the first decision (signed out, a new user's
/// insights still loading), so this drops at most a previous user's cue
/// (its flag is that user's). The others always apply.
final offerStillAppliesProvider = Provider.family<bool, BuddyAnnouncement>(
  (ref, announcement) => switch (announcement) {
    BuddyAnnouncement.tipsArrived => ref.watch(unseenTipSetProvider) != null,
    BuddyAnnouncement.weeklyTipsOffer =>
      ref.watch(weeklyTipsEnabledProvider) != true &&
          ref.watch(journeyProvider) == false,
    BuddyAnnouncement.firstTipOffer =>
      ref.watch(weeklyTipsEnabledProvider) != true &&
          ref.watch(journeyProvider) == true &&
          switch (ref.watch(journeyRewardsProvider)?.tipOffer) {
            // Answered, or skipped (never offered): done.
            TipOffer.accepted || TipOffer.declined || TipOffer.skipped => false,
            TipOffer.offered || null => true,
          },
    BuddyAnnouncement.saverUsed ||
    BuddyAnnouncement.streakBroken ||
    BuddyAnnouncement.saverEarned ||
    BuddyAnnouncement.goalReached ||
    BuddyAnnouncement.journeyReward ||
    BuddyAnnouncement.patternsUnlocked ||
    BuddyAnnouncement.firstTipFailed => true,
  },
);
