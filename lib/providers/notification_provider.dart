import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/constants.dart';
import '../repositories/notification_repository.dart';
import '../utils/date_format_utils.dart';
import '../utils/logger.dart';
import 'app_foreground_provider.dart';
import 'auth_provider.dart';
import 'buddy_provider.dart';
import 'insights_provider.dart';
import 'profile_provider.dart';
import 'today_provider.dart';

const _log = AppLogger('NotificationProvider');

/// Schedules/cancels notifications whenever the profile changes. Waits for
/// the Buddy's first load (data or error), so a cold start syncs once with
/// the Buddy's name instead of once without and once with it.
final notificationSyncProvider = Provider<void>((ref) {
  final profileState = ref.watch(profileProvider);
  // Only the first load settling, a rename (or the row appearing) re-syncs;
  // streak changes do not.
  final buddy = ref.watch(
    buddyProvider.select((s) {
      final status = s.value;
      return (
        firstLoad: s.isLoading && !s.hasValue && !s.hasError,
        name: status != null && status.hasRow ? status.state.name : null,
      );
    }),
  );
  if (buddy.firstLoad) return;
  final buddyName = buddy.name;

  profileState.whenData((profile) {
    if (profile == null) return;
    ref
        .read(notificationRepositoryProvider)
        .syncNotifications(profile, buddyName: buddyName)
        .catchError((e, st) {
          _log.error('failed to sync notifications', e, st);
        });
  });
});

// The notification model: the profile's flags (`remindersEnabled`,
// `dailySummaryEnabled`, `pushEnabled`) say what the user wants; a
// notification arrives only while the OS allows them, too. The flags are
// only ever turned on together with the OS permission, and an answer
// without it („Später", a declined OS dialog) turns them off, so the
// profile never claims reminders the phone won't show. Settings shows a
// flag as on only while the OS allows notifications.

/// Turns reminders on: asks the OS for notification permissions, remembers
/// that the opt-in was offered ([markNotificationOptInOffered], so the
/// dashboard dialog doesn't show again) and stores the outcome: with
/// permission every notification is on, without it every one is off.
/// Returns whether permission was granted.
///
/// Does nothing and returns false while no profile is loaded. Errors (e.g.
/// saving the profile) are rethrown to the caller.
Future<bool> enableReminders(WidgetRef ref) async {
  final profile = ref.read(profileProvider).whenOrNull(data: (p) => p);
  if (profile == null) return false;

  // Read before the async gaps: the caller may unmount during the OS dialog.
  final notifications = ref.read(notificationRepositoryProvider);
  final profiles = ref.read(profileProvider.notifier);
  final markOffered = _optInOffered(ref);

  final granted = await notifications.requestAllPermissions();
  await markOffered();
  await profiles.updateProfile(profile.withNotifications(granted));
  return granted;
}

/// The reminder opt-in answered with „Später": remembers that it was
/// offered and, unless the OS already allows notifications, turns every
/// notification off (nothing would arrive). Settings turns them on later.
///
/// Errors (e.g. saving the profile) are rethrown to the caller.
Future<void> postponeReminders(WidgetRef ref) async {
  // Read before the async gaps: the caller may unmount meanwhile.
  final profile = ref.read(profileProvider).whenOrNull(data: (p) => p);
  final notifications = ref.read(notificationRepositoryProvider);
  final profiles = ref.read(profileProvider.notifier);

  await markNotificationOptInOffered(ref);
  if (profile == null || !profile.anyNotificationOn) return;
  final permission = await notifications.permissionStatus();
  if (permission == NotificationPermission.granted) return;
  await profiles.updateProfile(profile.withNotifications(false));
}

/// Remembers that the reminder opt-in was offered
/// ([AppConstants.keyNotificationModalShown]), so the dashboard's opt-in
/// dialog doesn't ask (again), and holds the Buddy's ask off for a week
/// from today, as an ask would ([reminderAskScheduled]).
Future<void> markNotificationOptInOffered(WidgetRef ref) =>
    _optInOffered(ref)();

/// [markNotificationOptInOffered], with [ref] read right away: it may run
/// after the caller is gone (e.g. after the OS dialog).
Future<void> Function() _optInOffered(WidgetRef ref) {
  final storeAskDay = _askDayStore(ref);
  return () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyNotificationModalShown, true);
    await storeAskDay(prefs, counts: false);
  };
}

// --- Asking again --------------------------------------------------------------

/// Whether notifications are off: the profile has every one off, or the OS
/// doesn't allow them (read again whenever the app is back in the
/// foreground, e.g. from the Settings app). False while no profile is
/// loaded (nothing to offer).
final remindersOffProvider = FutureProvider.autoDispose<bool>((ref) async {
  final wanted = ref.watch(
    profileProvider.select((p) => p.value?.anyNotificationOn),
  );
  if (wanted == null) return false;
  if (!wanted) return true;
  ref.watch(appForegroundProvider);
  final permission = await ref
      .read(notificationRepositoryProvider)
      .permissionStatus();
  return permission != NotificationPermission.granted;
});

/// How often the Buddy may ask again for reminders, in all.
const reminderAsksMax = 4;

/// Active days before his first and his second ask.
const reminderAskFirstDays = 2, reminderAskSecondDays = 7;

/// Days from one ask to the next, from the third on.
const reminderAskInterval = 30;

/// Days at least from one ask to the next (also from the first offer, or
/// from switching them off in Einstellungen, to the first).
const reminderAskMinGap = 7;

/// Whether the Buddy's next ask for reminders is due [today], after [asks]
/// asks, the last one on [lastAsk], with [activeDays] days with an entry
/// (the insights' `activeDays`): the first once there are
/// [reminderAskFirstDays], the second once there are
/// [reminderAskSecondDays], then [reminderAskInterval] days after the
/// last; at most [reminderAsksMax] in all, and never within
/// [reminderAskMinGap] days of [lastAsk] (which the first offer and a
/// switch-off in Einstellungen set, too, [holdOffReminderAsks]).
bool reminderAskScheduled({
  required int asks,
  required DateTime? lastAsk,
  required int activeDays,
  required DateTime today,
}) {
  if (asks >= reminderAsksMax) return false;
  if (lastAsk != null && _daysBetween(lastAsk, today) < reminderAskMinGap) {
    return false;
  }
  return switch (asks) {
    0 => activeDays >= reminderAskFirstDays,
    1 => activeDays >= reminderAskSecondDays,
    _ => lastAsk == null || _daysBetween(lastAsk, today) >= reminderAskInterval,
  };
}

/// Calendar days from [from] to [to] (local dates; DST doesn't count).
int _daysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

/// Whether the Buddy asks again for reminders now ([reminderAskScheduled]):
/// they are off ([remindersOffProvider]), the first offer (the onboarding's
/// step or Home's one-time dialog) was made, and his next ask is due today.
/// Follows the day, the profile, the OS permission and the active days.
final reminderAskDueProvider = FutureProvider.autoDispose<bool>((ref) async {
  final off = ref.watch(remindersOffProvider.future);
  final userId = ref.watch(currentUserIdProvider);
  final today = ref.watch(todayProvider);
  if (userId == null || !await off) return false;
  // Only while off: the insights load only for this then.
  final activeDays = await ref.watch(
    insightsProvider.selectAsync((i) => i.progress.activeDays),
  );
  final prefs = await SharedPreferences.getInstance();
  if (!(prefs.getBool(AppConstants.keyNotificationModalShown) ?? false)) {
    return false;
  }
  final lastAsk = prefs.getString(
    '${AppConstants.keyReminderAskedOnPrefix}$userId',
  );
  return reminderAskScheduled(
    asks: prefs.getInt('${AppConstants.keyReminderAsksPrefix}$userId') ?? 0,
    lastAsk: lastAsk == null ? null : DateTime.tryParse(lastAsk),
    activeDays: activeDays,
    today: today,
  );
});

/// Counts an ask of the Buddy for reminders, today
/// ([reminderAskDueProvider] then holds off until the next one is due).
Future<void> recordReminderAsk(WidgetRef ref) async {
  final storeAskDay = _askDayStore(ref);
  await storeAskDay(await SharedPreferences.getInstance(), counts: true);
}

/// Reminders were switched off on purpose (Einstellungen): the Buddy
/// doesn't ask for them again for [reminderAskMinGap] days; today counts
/// as his last ask, without counting as one.
Future<void> holdOffReminderAsks(WidgetRef ref) async {
  final storeAskDay = _askDayStore(ref);
  await storeAskDay(await SharedPreferences.getInstance(), counts: false);
}

/// Stores today as the day of the signed-in user's last ask (and, if it
/// [counts], one more ask), then has [reminderAskDueProvider] check again.
/// Reads [ref] right away: it may run after the caller is gone.
Future<void> Function(SharedPreferences prefs, {required bool counts})
_askDayStore(WidgetRef ref) {
  final userId = ref.read(currentUserIdProvider);
  final today = ref.read(todayProvider);
  final container = ProviderScope.containerOf(ref.context, listen: false);
  return (prefs, {required counts}) async {
    if (userId == null) return;
    if (counts) {
      final asksKey = '${AppConstants.keyReminderAsksPrefix}$userId';
      await prefs.setInt(asksKey, (prefs.getInt(asksKey) ?? 0) + 1);
    }
    await prefs.setString(
      '${AppConstants.keyReminderAskedOnPrefix}$userId',
      formatIsoDate(today),
    );
    container.invalidate(reminderAskDueProvider);
  };
}

/// What „Einschalten" (the Buddy's ask, Ich's row) came to.
enum RemindersTurnOn {
  /// Allowed: every notification is on.
  on,

  /// The OS dialog was declined: every notification stays off.
  declined,

  /// The OS won't ask any more: the system settings opened; allowed there,
  /// the notifications turn on once the app is back
  /// ([reminderSettingsReturnProvider]).
  settingsOpened,

  /// Nothing happened: no profile loaded yet, or the settings didn't open.
  failed,
}

/// „Einschalten": turns notifications on ([enableReminders], the OS dialog
/// while it still asks). When the OS won't ask any more (denied for good,
/// [NotificationPermission.denied]) it opens the system settings instead,
/// so the button never does nothing. Errors (e.g. saving the profile) are
/// rethrown to the caller.
Future<RemindersTurnOn> turnOnReminders(WidgetRef ref) async {
  if (ref.read(profileProvider).value == null) return RemindersTurnOn.failed;
  // Read before the async gaps: the caller may unmount meanwhile.
  final notifications = ref.read(notificationRepositoryProvider);
  final settingsReturn = ref.read(reminderSettingsReturnProvider.notifier);

  Future<RemindersTurnOn> openSettings() async {
    if (!await notifications.openNotificationSettings()) {
      return RemindersTurnOn.failed;
    }
    settingsReturn.waitForReturn();
    return RemindersTurnOn.settingsOpened;
  }

  if (await notifications.permissionStatus() == NotificationPermission.denied) {
    return openSettings();
  }
  if (await enableReminders(ref)) return RemindersTurnOn.on;
  // Android 13+, denied for good after the local-notifications plugin's
  // request: firebase_messaging never recorded a request, so it reports
  // never asked, and a request shows nothing: only the settings can allow
  // them. (A dialog just declined reads as denied.)
  if (await notifications.permissionStatus() ==
      NotificationPermission.notDetermined) {
    return openSettings();
  }
  return RemindersTurnOn.declined;
}

/// Whether „Einschalten" sent the user to the system settings and the app
/// waits for them to come back: back in the foreground with notifications
/// allowed there, every notification turns on (as allowing them in the app
/// would).
class ReminderSettingsReturnNotifier extends Notifier<bool> {
  static const _log = AppLogger('ReminderSettingsReturn');

  @override
  bool build() {
    ref.listen(appForegroundProvider, (_, _) => unawaited(_back()));
    return false;
  }

  void waitForReturn() => state = true;

  Future<void> _back() async {
    if (!state) return;
    state = false;
    final permission = await ref
        .read(notificationRepositoryProvider)
        .permissionStatus();
    final profile = ref.read(profileProvider).value;
    if (!ref.mounted ||
        permission != NotificationPermission.granted ||
        profile == null ||
        profile.anyNotificationOn) {
      return;
    }
    try {
      await ref
          .read(profileProvider.notifier)
          .updateProfile(profile.withNotifications(true));
    } catch (e, st) {
      _log.error('turning the notifications on failed', e, st);
    }
  }
}

final reminderSettingsReturnProvider =
    NotifierProvider<ReminderSettingsReturnNotifier, bool>(
      ReminderSettingsReturnNotifier.new,
    );
