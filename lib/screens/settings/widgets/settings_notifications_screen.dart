import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../models/user_profile.dart';
import '../../../providers/notification_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../repositories/notification_repository.dart';
import '../../../services/daily_review/daily_review_rules.dart';
import '../../../utils/logger.dart';
import '../../../widgets/common/bb_async_state.dart';
import '../../../widgets/common/bb_card.dart';
import '../../../widgets/common/settings_section_card.dart';
import '../../../widgets/common/weekly_tips_switch.dart';
import 'reminder_time_picker.dart';

/// The notification settings. A switch shows on only while the OS allows
/// notifications and the profile wants it (see `enableReminders` for the
/// model): „Benachrichtigungen erlauben" asks the OS, and points to the
/// system settings when the OS won't ask any more. Switching every
/// notification off here holds the Buddy's ask for them off for a week
/// ([holdOffReminderAsks]).
class SettingsNotificationsScreen extends ConsumerStatefulWidget {
  const SettingsNotificationsScreen({super.key});

  /// The „Ab" row of the daily review's time.
  static const dailyReviewTimeKey = Key('settings_daily_review_time');

  @override
  ConsumerState<SettingsNotificationsScreen> createState() =>
      _SettingsNotificationsScreenState();
}

class _SettingsNotificationsScreenState
    extends ConsumerState<SettingsNotificationsScreen> {
  static const _log = AppLogger('NotificationSettings');
  Timer? _debounce;
  late final AppLifecycleListener _lifecycle;

  /// The OS permission; null until read.
  NotificationPermission? _permission;
  bool _isRequestingPermission = false;

  /// The user turned „Benachrichtigungen erlauben" on, but the OS won't ask:
  /// the hint to the Settings app shows, and allowing it there turns the
  /// reminders on once the user is back.
  bool _waitingForSettingsApp = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _readPermission);
    _readPermission();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _readPermission() async {
    final permission = await ref
        .read(notificationRepositoryProvider)
        .permissionStatus();
    if (!mounted) return;
    setState(() => _permission = permission);
    if (permission != NotificationPermission.granted ||
        !_waitingForSettingsApp) {
      return;
    }
    setState(() => _waitingForSettingsApp = false);
    _saveSwitch((p) => p.withNotifications(true));
  }

  /// Saves [change] made to the profile as it is now, not as it was when
  /// the screen last built: writes close together (a debounced time, a
  /// switch) never undo each other. A failure is logged.
  void _updateLatest(
    UserProfile Function(UserProfile) change, {
    bool holdOffIfAllOff = false,
  }) {
    final latest = ref.read(profileProvider).value;
    if (latest == null) return;
    final profile = change(latest);
    if (holdOffIfAllOff) _holdOffIfAllOff(profile);
    ref
        .read(profileProvider.notifier)
        .updateProfile(profile)
        .catchError((Object e) => _log.error('saving failed', e));
  }

  /// A switch of one notification (or all): saved; the last one off holds
  /// the Buddy's ask off ([_holdOffIfAllOff]).
  void _saveSwitch(UserProfile Function(UserProfile) change) =>
      _updateLatest(change, holdOffIfAllOff: true);

  /// Every notification off on purpose: the Buddy doesn't ask for them
  /// again for a week ([holdOffReminderAsks]).
  void _holdOffIfAllOff(UserProfile profile) {
    if (profile.anyNotificationOn) return;
    holdOffReminderAsks(
      ref,
    ).catchError((Object e) => _log.error('storing the hold-off failed', e));
  }

  void _debounceSave(Function() doSave) {
    _debounce?.cancel();
    _debounce = Timer(AppConstants.debounceDuration, doSave);
  }

  Future<void> _toggleMasterPermission(bool value) async {
    if (!value) {
      setState(() => _waitingForSettingsApp = false);
      _saveSwitch((p) => p.withNotifications(false));
      return;
    }
    setState(() => _isRequestingPermission = true);
    final notifications = ref.read(notificationRepositoryProvider);
    try {
      // Shows the OS dialog only while it was never asked.
      final granted = await notifications.requestAllPermissions();
      final permission = granted
          ? NotificationPermission.granted
          : await notifications.permissionStatus();
      if (!mounted) return;
      setState(() {
        _permission = permission;
        _isRequestingPermission = false;
        _waitingForSettingsApp = !granted;
      });
      if (granted) _saveSwitch((p) => p.withNotifications(true));
    } catch (e) {
      _log.error('failed to request permission', e);
      if (mounted) setState(() => _isRequestingPermission = false);
    }
  }

  /// The daily review's time from the system time picker (24 h), stored at
  /// once as `HH:MM`, clamped to the allowed range ([reviewMinutesOf]).
  Future<void> _pickReviewTime(UserProfile profile) async {
    final minutes = reviewMinutesOf(profile.dailyReviewTime);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
      helpText: 'Uhrzeit wählen',
      cancelText: 'Abbrechen',
      confirmText: 'Speichern',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    final time = _formatMinutes(
      reviewMinutesOf(_formatMinutes(picked.hour * 60 + picked.minute)),
    );
    if (time == ref.read(profileProvider).value?.dailyReviewTime) return;
    _updateLatest((p) => p.copyWith(dailyReviewTime: time));
  }

  static String _formatMinutes(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
      '${(minutes % 60).toString().padLeft(2, '0')}';

  /// The system settings where this app's notifications are allowed (iOS
  /// and Android); a SnackBar if they don't open.
  Future<void> _openSettingsApp() async {
    final messenger = ScaffoldMessenger.of(context);
    final opened = await ref
        .read(notificationRepositoryProvider)
        .openNotificationSettings();
    if (!opened) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Die Einstellungen konnten nicht geöffnet werden.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: AppTheme.screenBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.screenBackground,
        title: const Text('Benachrichtigungen'),
      ),
      body: profileState.when(
        loading: () => const BbLoadingState(),
        error: (e, _) => BbErrorState(
          message: 'Fehler beim Laden der Einstellungen.',
          onRetry: () => ref.read(profileProvider.notifier).fetchProfile(),
        ),
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Kein Profil.'));
          }
          final permission = _permission;
          if (permission == null) return const BbLoadingState();

          final osAllows = permission == NotificationPermission.granted;
          final allowed = osAllows && profile.anyNotificationOn;
          // Asked in vain, or turned off in the OS after the user wanted them.
          final showSettingsHint =
              !osAllows &&
              (_waitingForSettingsApp ||
                  (permission == NotificationPermission.denied &&
                      profile.anyNotificationOn));
          final mealOn = allowed && profile.remindersEnabled;
          final gutOn = allowed && profile.dailySummaryEnabled;
          final tipsOn = allowed && profile.pushEnabled;
          final reviewNoticeOn = allowed && profile.dailyReviewReminder;

          return SingleChildScrollView(
            padding: AppConstants.paddingLg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BbCard(
                  child: _isRequestingPermission
                      ? const Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: AppConstants.spacingMd,
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: AppConstants.spinnerSize,
                                height: AppConstants.spinnerSize,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.primary,
                                ),
                              ),
                              SizedBox(width: AppConstants.spacingSm),
                              Text('Benachrichtigungen werden aktiviert...'),
                            ],
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SwitchListTile(
                              title: const Text('Benachrichtigungen erlauben'),
                              value: allowed,
                              activeThumbColor: AppTheme.primary,
                              contentPadding: EdgeInsets.zero,
                              onChanged: _toggleMasterPermission,
                            ),
                            if (showSettingsHint) ...[
                              const Text(
                                'Benachrichtigungen sind für Belly Buddy in '
                                'den Einstellungen deines Geräts '
                                'ausgeschaltet. Dort kannst du sie erlauben.',
                                style: TextStyle(
                                  fontSize: AppTheme.fontSizeCaptionLG,
                                  color: AppTheme.mutedForeground,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: _openSettingsApp,
                                icon: const Icon(Icons.settings_outlined),
                                label: const Text('Einstellungen öffnen'),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  foregroundColor: AppTheme.primaryForeground,
                                ),
                              ),
                            ],
                          ],
                        ),
                ),
                AppConstants.gap16,
                _Greyed(
                  enabled: allowed,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SettingsSectionCard(
                        icon: Icons.alarm_outlined,
                        title: 'Erinnerungen',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SwitchListTile(
                              title: const Text('Mahlzeiten'),
                              value: mealOn,
                              activeThumbColor: AppTheme.primary,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (v) => _saveSwitch(
                                (p) => p.copyWith(remindersEnabled: v),
                              ),
                            ),
                            const Text(
                              'Erinnert dich daran, dein Essen einzutragen.',
                              style: TextStyle(
                                fontSize: AppTheme.fontSizeCaptionLG,
                                color: AppTheme.mutedForeground,
                              ),
                            ),
                            if (mealOn) ...[
                              AppConstants.gap8,
                              ReminderTimePicker(
                                selectedTimes: profile.mealReminderTimes,
                                onChanged: (newTimes) {
                                  _debounceSave(
                                    () => _updateLatest(
                                      (p) => p.copyWith(
                                        mealReminderTimes: newTimes,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                            AppConstants.gap8,
                            const Divider(
                              color: AppTheme.border,
                              thickness: AppConstants.dividerThickness,
                            ),
                            AppConstants.gap8,
                            SwitchListTile(
                              title: const Text('Bauchgefühl'),
                              value: gutOn,
                              activeThumbColor: AppTheme.primary,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (v) => _saveSwitch(
                                (p) => p.copyWith(dailySummaryEnabled: v),
                              ),
                            ),
                            const Text(
                              'Erinnert dich daran, dein Bauchgefühl einzutragen.',
                              style: TextStyle(
                                fontSize: AppTheme.fontSizeCaptionLG,
                                color: AppTheme.mutedForeground,
                              ),
                            ),
                            if (gutOn) ...[
                              AppConstants.gap8,
                              ReminderTimePicker(
                                selectedTimes: profile.moodReminderTimes,
                                onChanged: (newTimes) {
                                  _debounceSave(
                                    () => _updateLatest(
                                      (p) => p.copyWith(
                                        moodReminderTimes: newTimes,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                AppConstants.gap16,
                SettingsSectionCard(
                  icon: Icons.nightlight_outlined,
                  title: 'Tagesrückblick',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // It rules when Home shows the review: never greyed.
                      ListTile(
                        key: SettingsNotificationsScreen.dailyReviewTimeKey,
                        title: const Text('Ab'),
                        trailing: Text(
                          _formatMinutes(
                            reviewMinutesOf(profile.dailyReviewTime),
                          ),
                          style: const TextStyle(
                            fontSize: AppTheme.fontSizeBody,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        contentPadding: EdgeInsets.zero,
                        onTap: () => _pickReviewTime(profile),
                      ),
                      const Text(
                        'Ab dieser Uhrzeit zeigt dir Home deinen Rückblick '
                        'auf den Tag.',
                        style: AppTheme.captionMutedStyle,
                      ),
                      AppConstants.gap8,
                      const Divider(
                        color: AppTheme.border,
                        thickness: AppConstants.dividerThickness,
                      ),
                      AppConstants.gap8,
                      _Greyed(
                        enabled: allowed,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SwitchListTile(
                              title: const Text('Erinnerung am Abend'),
                              value: reviewNoticeOn,
                              activeThumbColor: AppTheme.primary,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (v) => _saveSwitch(
                                (p) => p.copyWith(dailyReviewReminder: v),
                              ),
                            ),
                            const Text(
                              'Ich sag dir Bescheid, wenn er da ist – nur an '
                              'Tagen mit eingetragener Mahlzeit.',
                              style: AppTheme.captionMutedStyle,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                AppConstants.gap16,
                SettingsSectionCard(
                  icon: Icons.lightbulb_outline,
                  title: 'Tipps',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Generation, not delivery: never greyed.
                      const WeeklyTipsSwitch(),
                      AppConstants.gap8,
                      const Divider(
                        color: AppTheme.border,
                        thickness: AppConstants.dividerThickness,
                      ),
                      AppConstants.gap8,
                      _Greyed(
                        enabled: allowed,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SwitchListTile(
                              title: const Text('Tipps per Push'),
                              value: tipsOn,
                              activeThumbColor: AppTheme.primary,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (v) => _saveSwitch(
                                (p) => p.copyWith(pushEnabled: v),
                              ),
                            ),
                            const Text(
                              'Ich sag dir Bescheid, sobald neue Tipps da sind.',
                              style: AppTheme.captionMutedStyle,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                AppConstants.gap32,
              ],
            ),
          );
        },
      ),
    );
  }
}

/// [child] greyed out and untouchable unless [enabled] (while the OS
/// notifications are not allowed).
class _Greyed extends StatelessWidget {
  const _Greyed({required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !enabled,
      child: AnimatedOpacity(
        opacity: enabled ? 1.0 : AppConstants.disabledOpacity,
        duration: AppConstants.animFast,
        child: child,
      ),
    );
  }
}
