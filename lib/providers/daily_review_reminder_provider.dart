import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/notification_repository.dart';
import '../services/daily_review/daily_review_rules.dart';
import '../utils/date_format_utils.dart';
import '../utils/logger.dart';
import 'auth_provider.dart';
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

/// Runs the notice's schedule / cancel calls one after another, so an
/// older call never lands after a newer one. While one runs, only the
/// latest request waits (last state wins). Errors are logged.
class DailyReviewNoticeQueue {
  Future<void> Function()? _next;
  Future<void>? _running;

  /// When the last requested schedule fires (in this app run); null after a
  /// cancel. Lets the sync cancel a notice still pending after the review
  /// time moved before now.
  DateTime? scheduledAt;

  /// Done once every request so far has run.
  Future<void> get idle => _running ?? Future.value();

  void request(Future<void> Function() run) {
    _next = run;
    _running ??= _drain();
  }

  Future<void> _drain() async {
    for (var run = _next; run != null; run = _next) {
      _next = null;
      try {
        await run();
      } catch (e, st) {
        _log.error('syncing the daily review notice failed', e, st);
      }
    }
    _running = null;
  }
}

/// The one queue of the evening notice's calls ([DailyReviewNoticeQueue]).
final dailyReviewNoticeQueueProvider = Provider<DailyReviewNoticeQueue>(
  (ref) => DailyReviewNoticeQueue(),
);

/// Schedules or cancels today's evening notice ([dailyReviewNoticeDue])
/// whenever the profile's switch or time, today's meals ([entriesProvider]
/// while it holds today), the day, the closed day or the Buddy's name
/// change; not every minute (a notice already due fires on its own).
/// From the review time on nothing is cancelled (the shown notice stays in
/// the tray) unless a notice for a later time is pending. Signed out:
/// cancelled. Waits for the profile, the closed day and the
/// Buddy's first load. The calls go through [dailyReviewNoticeQueueProvider].
final dailyReviewReminderSyncProvider = Provider<void>((ref) {
  final queue = ref.watch(dailyReviewNoticeQueueProvider);
  final notifications = ref.read(notificationRepositoryProvider);
  // After any schedule still in flight, also after the sign-out cancelAll.
  if (ref.watch(currentUserIdProvider) == null) {
    queue.scheduledAt = null;
    queue.request(notifications.cancelDailyReview);
    return;
  }
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
  final now = ref.read(buddyClockProvider)();
  final due = dailyReviewNoticeDue(
    reminderOn: settings.on,
    todayMeals: todayMeals ?? 0,
    now: now,
    reviewMinutes: reviewMinutes,
    closedDay: closed.value,
  );
  if (due) {
    queue.scheduledAt = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(Duration(minutes: reviewMinutes));
    queue.request(
      () => notifications.scheduleDailyReview(
        hour: reviewMinutes ~/ 60,
        minute: reviewMinutes % 60,
        buddyName: buddy.name,
      ),
    );
    return;
  }
  // From the review time on, today's one-shot has fired (or was never
  // set): a cancel would only take the shown notice out of the tray. Only
  // a notice set for later (the time moved before now) is still cancelled.
  final pastTime = now.hour * 60 + now.minute >= reviewMinutes;
  if (pastTime && !(queue.scheduledAt?.isAfter(now) ?? false)) return;
  queue.scheduledAt = null;
  queue.request(notifications.cancelDailyReview);
});
