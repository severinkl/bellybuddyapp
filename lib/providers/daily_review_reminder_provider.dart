import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/notification_repository.dart';
import '../services/daily_review/daily_review_rules.dart';
import '../utils/date_format_utils.dart';
import '../utils/logger.dart';
import 'buddy_provider.dart';
import 'daily_review_provider.dart';
import 'entries_provider.dart';
import 'profile_provider.dart';
import 'today_provider.dart';

const _log = AppLogger('DailyReviewReminder');

/// Whether today's evening notice should be pending (spec §4.6): the
/// switch is on, today has a meal, [now] is before the review time
/// ([reviewMinutes]) and today's review is not closed ([closedDay]).
bool dailyReviewNoticeDue({
  required bool reminderOn,
  required int todayMeals,
  required DateTime now,
  required int reviewMinutes,
  required DateTime? closedDay,
}) {
  if (!reminderOn || todayMeals < 1) return false;
  if (now.hour * 60 + now.minute >= reviewMinutes) return false;
  return closedDay == null || !isSameDay(closedDay, now);
}

/// Schedules or cancels today's evening notice ([dailyReviewNoticeDue])
/// whenever the profile's switch or time, today's meals ([entriesProvider]
/// while it holds today), the day, the closed day or the Buddy's name
/// change; not every minute (a notice already due fires on its own).
/// Waits for the profile, the closed day and the Buddy's first load.
/// Errors are logged.
final dailyReviewReminderSyncProvider = Provider<void>((ref) {
  final settings = ref.watch(
    profileProvider.select((s) {
      final p = s.value;
      return p == null
          ? null
          : (on: p.dailyReviewReminder, time: p.dailyReviewTime);
    }),
  );
  final buddy = ref.watch(
    buddyProvider.select((s) {
      final status = s.value;
      return (
        firstLoad: s.isLoading && !s.hasValue && !s.hasError,
        name: status != null && status.hasRow ? status.state.name : null,
      );
    }),
  );
  final today = ref.watch(todayProvider);
  // Null while the entries hold another day (or none yet).
  final todayMeals = ref.watch(
    entriesProvider.select((e) {
      final day = e.day;
      if (day == null || !isSameDay(day, today)) return null;
      return e.meals.where((m) => onWallClockDay(m.trackedAt, today)).length;
    }),
  );
  final closed = ref.watch(dailyReviewClosedProvider);
  if (settings == null || buddy.firstLoad || closed.isLoading) return;
  // Unknown meals: an evening notice needs one, so only switching off acts.
  if (todayMeals == null && settings.on) return;

  final reviewMinutes = reviewMinutesOf(settings.time);
  final due = dailyReviewNoticeDue(
    reminderOn: settings.on,
    todayMeals: todayMeals ?? 0,
    now: ref.read(buddyClockProvider)(),
    reviewMinutes: reviewMinutes,
    closedDay: closed.value,
  );
  final notifications = ref.read(notificationRepositoryProvider);
  final sync = due
      ? notifications.scheduleDailyReview(
          hour: reviewMinutes ~/ 60,
          minute: reviewMinutes % 60,
          buddyName: buddy.name,
        )
      : notifications.cancelDailyReview();
  sync.catchError((Object e, StackTrace st) {
    _log.error('syncing the daily review notice failed', e, st);
  });
});
