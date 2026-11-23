import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/insights.dart';
import 'buddy_provider.dart';
import 'insights_provider.dart';
import 'profile_provider.dart';
import 'recommendation_provider.dart';

/// The flag suffix of [BuddyAnnouncement.weeklyTipsOffer]: offered once per
/// user, ever.
const weeklyTipsOfferSuffix = 'once';

/// Whether the Buddy offers the weekly tips: he sees first patterns (the
/// signed-in user's insights are loaded and unlocked) and the weekly tips
/// are known to be off. Only [AsyncData] counts: while another user's
/// insights load, the state still holds the previous user's.
final weeklyTipsOfferDueProvider = Provider<bool>((ref) {
  final unlocked = switch (ref.watch(insightsProvider)) {
    AsyncData<Insights>(:final value) => value.unlocked,
    _ => false,
  };
  return unlocked && ref.watch(weeklyTipsEnabledProvider) == false;
});

/// The announcements Home offers the Buddy while they apply, each with its
/// flag suffix ([BuddyNotifier.offerAnnouncement]): `tipsArrived` for the
/// unseen tip set (once per set), `weeklyTipsOffer` while it is due.
final buddyOffersProvider = Provider<Map<BuddyAnnouncement, String>>((ref) {
  final set = ref.watch(unseenTipSetProvider);
  return {
    if (set != null) BuddyAnnouncement.tipsArrived: set.id,
    if (ref.watch(weeklyTipsOfferDueProvider))
      BuddyAnnouncement.weeklyTipsOffer: weeklyTipsOfferSuffix,
  };
});
