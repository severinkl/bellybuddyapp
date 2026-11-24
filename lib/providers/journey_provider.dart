import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/constants.dart';
import '../models/insight_rules.dart';
import '../models/insights.dart';
import '../utils/logger.dart';
import '../utils/settled_value.dart';
import 'auth_provider.dart';
import 'insights_provider.dart';

/// Whether the signed-in user sees the first-patterns journey (the 7 dots
/// instead of Stage 2's progress card); null while undecided or signed out.
///
/// Decided once per user and device, on the first loaded [Insights]: users
/// who are new (locked, under [InsightRules.daysNeeded] active days) get
/// it; users already past that keep the card they know. The decision is
/// stored under `insight_journey_<userId>` and never changes, so the same
/// flag can carry later rewards.
///
/// Prefs that can't be read or written are logged; the computed value is
/// used for this build, unstored.
class JourneyNotifier extends Notifier<bool?> {
  static const _log = AppLogger('Journey');

  @override
  bool? build() {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return null;
    final prefs = _prefs();
    var decided = false;
    ref.listen(insightsProvider, (_, next) {
      // Settled only: a load, refresh or error may still carry the
      // previous user's value.
      final insights = next.settledValue;
      if (decided || insights == null) return;
      decided = true;
      _decide(userId, insights, prefs);
    }, fireImmediately: true);
    return null;
  }

  Future<SharedPreferences?> _prefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (e, st) {
      _log.error('Journey flag unavailable', e, st);
      return null;
    }
  }

  Future<void> _decide(
    String userId,
    Insights insights,
    Future<SharedPreferences?> prefsFuture,
  ) async {
    final key = '${AppConstants.keyInsightJourneyPrefix}$userId';
    final prefs = await prefsFuture;
    if (!ref.isCurrentUser(userId)) return;
    bool? stored;
    try {
      stored = prefs?.getBool(key);
    } catch (e, st) {
      _log.error('Reading the journey flag failed', e, st);
    }
    if (stored != null) {
      state = stored;
      return;
    }
    final value =
        !insights.unlocked &&
        insights.progress.activeDays < InsightRules.daysNeeded;
    state = value;
    try {
      await prefs?.setBool(key, value);
    } catch (e, st) {
      _log.error('Storing the journey flag failed', e, st);
    }
  }
}

final journeyProvider = NotifierProvider<JourneyNotifier, bool?>(
  JourneyNotifier.new,
);
