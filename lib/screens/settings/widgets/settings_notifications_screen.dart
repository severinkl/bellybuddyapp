import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../config/timezone_options.dart';
import '../../../models/user_profile.dart';
import '../../../providers/profile_provider.dart';
import '../../../services/push_notification_service.dart';
import '../../../services/supabase_service.dart';
import '../../../widgets/common/settings_section_card.dart';
import 'reminder_time_picker.dart';

class SettingsNotificationsScreen extends ConsumerStatefulWidget {
  const SettingsNotificationsScreen({super.key});

  @override
  ConsumerState<SettingsNotificationsScreen> createState() =>
      _SettingsNotificationsScreenState();
}

class _SettingsNotificationsScreenState
    extends ConsumerState<SettingsNotificationsScreen> {
  Timer? _debounce;
  bool _debugExpanded = false;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _debounceSave(Function() doSave) {
    _debounce?.cancel();
    _debounce = Timer(AppConstants.debounceDuration, doSave);
  }

  Future<void> _togglePush(bool value, UserProfile profile) async {
    if (value) {
      final granted = await PushNotificationService.requestPermission();
      if (!granted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Benachrichtigungen sind in den Systemeinstellungen deaktiviert.',
            ),
          ),
        );
        return;
      }
    }
    ref
        .read(profileProvider.notifier)
        .updateProfile(profile.copyWith(pushEnabled: value));
  }

  Future<void> _pickDailySummaryTime(UserProfile profile) async {
    final current = _parseTime(profile.dailySummaryTime);
    final picked = await showTimePicker(
      context: context,
      initialTime: current,
      helpText: 'Zusammenfassung-Uhrzeit wählen',
      cancelText: 'Abbrechen',
      confirmText: 'Speichern',
    );
    if (picked == null) return;
    final formatted =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    ref
        .read(profileProvider.notifier)
        .updateProfile(profile.copyWith(dailySummaryTime: formatted));
  }

  TimeOfDay _parseTime(String time) {
    final parts = time.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Benachrichtigungen')),
      body: profileState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Kein Profil.'));
          }

          return SingleChildScrollView(
            padding: AppConstants.paddingLg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Reminders section
                SettingsSectionCard(
                  icon: Icons.alarm_outlined,
                  title: 'Erinnerungen',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile(
                        title: const Text('Erinnerungen'),
                        subtitle: const Text(
                          'Tägliche Erinnerungen zum Tracken',
                        ),
                        value: profile.remindersEnabled,
                        activeThumbColor: AppTheme.primary,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (v) {
                          ref
                              .read(profileProvider.notifier)
                              .updateProfile(
                                profile.copyWith(remindersEnabled: v),
                              );
                        },
                      ),
                      if (profile.remindersEnabled) ...[
                        const Divider(),
                        AppConstants.gap12,
                        const Text(
                          'Erinnerungszeiten',
                          style: TextStyle(
                            fontSize: AppTheme.fontSizeBodyLG,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        AppConstants.gap8,
                        ReminderTimePicker(
                          selectedTimes: profile.reminderTimes,
                          onChanged: (newTimes) {
                            _debounceSave(() {
                              ref
                                  .read(profileProvider.notifier)
                                  .updateProfile(
                                    profile.copyWith(reminderTimes: newTimes),
                                  );
                            });
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                AppConstants.gap16,

                // Daily summary section
                SettingsSectionCard(
                  icon: Icons.self_improvement_outlined,
                  title: 'Tägliche Zusammenfassung',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile(
                        title: const Text('Tägliche Zusammenfassung'),
                        subtitle: const Text(
                          'Abendliche Bauchgefühl-Erinnerung',
                        ),
                        value: profile.dailySummaryEnabled,
                        activeThumbColor: AppTheme.primary,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (v) {
                          ref
                              .read(profileProvider.notifier)
                              .updateProfile(
                                profile.copyWith(dailySummaryEnabled: v),
                              );
                        },
                      ),
                      if (profile.dailySummaryEnabled) ...[
                        const Divider(),
                        AppConstants.gap12,
                        Row(
                          children: [
                            const Text(
                              'Uhrzeit',
                              style: TextStyle(
                                fontSize: AppTheme.fontSizeBodyLG,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () => _pickDailySummaryTime(profile),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppConstants.spacing14,
                                  vertical: AppConstants.spacingSm,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary,
                                  borderRadius: BorderRadius.circular(
                                    AppConstants.radiusFull,
                                  ),
                                ),
                                child: Text(
                                  profile.dailySummaryTime,
                                  style: const TextStyle(
                                    fontSize: AppTheme.fontSizeBody,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.primaryForeground,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                AppConstants.gap16,

                // Timezone section
                SettingsSectionCard(
                  icon: Icons.public,
                  title: 'Zeitzone',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Für die Erinnerungen zur richtigen Ortszeit',
                        style: TextStyle(
                          fontSize: AppTheme.fontSizeCaptionLG,
                          color: AppTheme.mutedForeground,
                        ),
                      ),
                      AppConstants.gap12,
                      DropdownButtonFormField<String>(
                        initialValue: profile.timezone ?? 'Europe/Berlin',
                        isExpanded: true,
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: AppConstants.spacingMd,
                            vertical: AppConstants.spacing12,
                          ),
                        ),
                        items: timezoneOptions
                            .map(
                              (tz) => DropdownMenuItem(
                                value: tz.value,
                                child: Text(
                                  tz.label,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          _debounceSave(() {
                            ref
                                .read(profileProvider.notifier)
                                .updateProfile(profile.copyWith(timezone: v));
                          });
                        },
                      ),
                    ],
                  ),
                ),
                AppConstants.gap16,

                // Push notifications section
                SettingsSectionCard(
                  icon: Icons.notifications_outlined,
                  title: 'Push-Benachrichtigungen',
                  child: SwitchListTile(
                    title: const Text('Push-Benachrichtigungen'),
                    subtitle: const Text('Empfehlungen & Warnungen'),
                    value: profile.pushEnabled,
                    activeThumbColor: AppTheme.primary,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) => _togglePush(v, profile),
                  ),
                ),
                AppConstants.gap16,

                // Debug section
                SettingsSectionCard(
                  icon: Icons.bug_report_outlined,
                  title: 'Debug-Info',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () =>
                            setState(() => _debugExpanded = !_debugExpanded),
                        child: Row(
                          children: [
                            Text(
                              _debugExpanded
                                  ? 'Details ausblenden'
                                  : 'Details anzeigen',
                              style: const TextStyle(
                                fontSize: AppTheme.fontSizeBody,
                                color: AppTheme.mutedForeground,
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              _debugExpanded
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              color: AppTheme.mutedForeground,
                            ),
                          ],
                        ),
                      ),
                      if (_debugExpanded) ...[
                        AppConstants.gap12,
                        _DebugRow(
                          label: 'Plattform',
                          value: Platform.operatingSystem,
                        ),
                        _DebugRow(
                          label: 'Erinnerungen',
                          value: profile.remindersEnabled ? 'Ja' : 'Nein',
                        ),
                        _DebugRow(
                          label: 'Zusammenfassung',
                          value: profile.dailySummaryEnabled ? 'Ja' : 'Nein',
                        ),
                        _DebugRow(
                          label: 'Push',
                          value: profile.pushEnabled ? 'Ja' : 'Nein',
                        ),
                        _DebugRow(
                          label: 'Zeitzone',
                          value: profile.timezone ?? 'Europe/Berlin',
                        ),
                        _DebugRow(
                          label: 'Zeiten',
                          value: profile.reminderTimes.join(', '),
                        ),
                        _DebugRow(
                          label: 'Zusammenfassung',
                          value: profile.dailySummaryTime,
                        ),
                        _DebugRow(
                          label: 'FCM Token',
                          value: profile.fcmToken ?? '—',
                        ),
                        _DebugRow(
                          label: 'User ID',
                          value: SupabaseService.userId ?? '—',
                        ),
                      ],
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

class _DebugRow extends StatelessWidget {
  final String label;
  final String value;

  const _DebugRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spacing6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: AppConstants.debugLabelWidth,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: AppTheme.fontSizeCaptionLG,
                color: AppTheme.mutedForeground,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: AppTheme.fontSizeCaptionLG,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
