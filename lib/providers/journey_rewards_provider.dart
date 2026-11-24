import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/constants.dart';
import '../models/insights.dart';
import '../models/journey_rewards.dart';
import '../services/journey/journey_rules.dart';
import '../utils/logger.dart';
import '../utils/settled_value.dart';
import 'auth_provider.dart';
import 'buddy_provider.dart';
import 'insights_provider.dart';
import 'journey_provider.dart';
import 'profile_provider.dart';
import 'recipe_collection_provider.dart';

/// The signed-in journey user's rewards of the first 7 days, kept per user
/// and device under `journey_rewards_<userId>`; null while signed out,
/// while [journeyProvider] isn't true, and until the stored value is read.
///
/// Moved on by the settled insights, the weekly tips and the checked
/// recipes ([advanceRewards], [fillPicks]), so nothing is ever taken away:
/// the earned day never goes down and a stored pick never changes. Stored
/// only when changed, one write after another; a read or write that fails
/// is logged (an unreadable value starts afresh, a failed write still
/// applies in memory).
class JourneyRewardsNotifier extends Notifier<JourneyRewards?> {
  static const _log = AppLogger('JourneyRewards');

  /// The user whose rewards [state] holds; null until they are read.
  String? _userId;

  /// The latest settled insights of this build's user.
  Insights? _insights;

  /// The writes, one after another, so an older one never lands last.
  Future<void> _writes = Future.value();

  @override
  JourneyRewards? build() {
    _userId = null;
    _insights = null;
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null || ref.watch(journeyProvider) != true) return null;
    ref
      ..listen(insightsProvider, (_, next) {
        // Settled only: a load or rebuild may still carry another user's.
        if (next.settledValue case final insights?) {
          _insights = insights;
          unawaited(_apply(_same));
        }
      }, fireImmediately: true)
      ..listen(weeklyTipsEnabledProvider, (_, _) => unawaited(_apply(_same)))
      ..listen(rankedRecipesProvider, (_, _) => unawaited(_apply(_same)));
    unawaited(_load(userId));
    return null;
  }

  /// Answers the day-3 offer: [TipOffer.offered] becomes accepted or
  /// declined; any other offer stays. Completes once stored.
  Future<void> answerTipOffer({required bool accepted}) => _apply(
    (r) => r.tipOffer == TipOffer.offered
        ? r.copyWith(tipOffer: accepted ? TipOffer.accepted : TipOffer.declined)
        : r,
  );

  /// Sets the state of the first tip ([firstTip]). Completes once stored.
  Future<void> setFirstTip(FirstTipState firstTip) =>
      _apply((r) => r.copyWith(firstTip: firstTip));

  static JourneyRewards _same(JourneyRewards r) => r;

  /// Every change: [change] applied to the read rewards, then [_moved];
  /// stored when that changed them. Nothing before they are read, or once
  /// another user is signed in. Completes once the rewards as now are
  /// stored.
  Future<void> _apply(JourneyRewards Function(JourneyRewards) change) {
    final userId = _userId;
    if (userId == null || !ref.isCurrentUser(userId)) return _writes;
    final current = state;
    if (current == null) return _writes;
    final next = _moved(change(current));
    if (next == current) return _writes;
    state = next;
    return _store(userId, next);
  }

  /// [r] moved on by the settled insights and the weekly tips, with the
  /// recipes picked from the settled ranking; [r] until the insights
  /// settled (day 5 needs their calm-day ingredients).
  JourneyRewards _moved(JourneyRewards r) {
    final insights = _insights;
    if (insights == null) return r;
    final advanced = advanceRewards(
      r,
      insights: insights,
      weeklyTips: ref.read(weeklyTipsEnabledProvider),
    );
    final ranked = ref.read(rankedRecipesProvider).settledValue;
    if (ranked == null) return advanced;
    return fillPicks(
      advanced,
      ranked: ranked,
      calmKeys: insights.calmDayIngredients,
    );
  }

  /// Reads [userId]'s stored rewards, once the pending writes landed, and
  /// moves them on.
  Future<void> _load(String userId) async {
    final opRef = ref;
    await _writes;
    if (!opRef.isCurrentUser(userId)) return;
    final stored = await _read(userId);
    if (!opRef.isCurrentUser(userId)) return;
    _userId = userId;
    final next = _moved(stored);
    state = next;
    if (next != stored) await _store(userId, next);
  }

  /// [userId]'s stored rewards; none when nothing is stored, and when it
  /// can't be read.
  Future<JourneyRewards> _read(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(userId));
      if (raw == null) return const JourneyRewards();
      final rewards = JourneyRewards.fromJson(jsonDecode(raw));
      if (rewards == null) _log.warn('Stored journey rewards unreadable');
      return rewards ?? const JourneyRewards();
    } catch (e, st) {
      _log.error('Reading the journey rewards failed', e, st);
      return const JourneyRewards();
    }
  }

  /// Stores [rewards] for [userId] after the writes before it.
  Future<void> _store(String userId, JourneyRewards rewards) {
    final key = _key(userId), json = jsonEncode(rewards.toJson());
    return _writes = _writes.then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(key, json);
      } catch (e, st) {
        _log.error('Storing the journey rewards failed', e, st);
      }
    });
  }

  static String _key(String userId) =>
      '${AppConstants.keyJourneyRewardsPrefix}$userId';
}

final journeyRewardsProvider =
    NotifierProvider<JourneyRewardsNotifier, JourneyRewards?>(
      JourneyRewardsNotifier.new,
    );

/// The reward line below the journey's counters, as of the app's clock;
/// null without rewards, and unless the insights settled, locked.
final journeyRewardLineProvider = Provider<JourneyRewardLine?>((ref) {
  final rewards = ref.watch(journeyRewardsProvider);
  final insights = ref.watch(insightsProvider).settledValue;
  if (rewards == null || insights == null || insights.unlocked) return null;
  return rewardLine(
    rewards,
    insights: insights,
    now: ref.watch(buddyClockProvider)(),
    weeklyTips: ref.watch(weeklyTipsEnabledProvider),
  );
});

/// The day the Buddy announces ([announcementDay]); null without rewards.
final journeyRewardAnnouncementProvider = Provider<int?>((ref) {
  final rewards = ref.watch(journeyRewardsProvider);
  return rewards == null ? null : announcementDay(rewards);
});

/// Whether the journey's first patterns were unlocked (the day-7 reward).
final patternsUnlockedDueProvider = Provider<bool>(
  (ref) => ref.watch(journeyRewardsProvider)?.patternsFreed ?? false,
);

/// Whether the day-3 first tip failed.
final firstTipFailedProvider = Provider<bool>(
  (ref) => ref.watch(journeyRewardsProvider)?.firstTip == FirstTipState.failed,
);
