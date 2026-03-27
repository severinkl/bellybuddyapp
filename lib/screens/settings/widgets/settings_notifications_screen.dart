import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../models/user_profile.dart';
import '../../../providers/profile_provider.dart';
import '../../../repositories/notification_repository.dart';
import '../../../widgets/common/bb_async_state.dart';
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
  bool? _permissionGranted;
  bool _isRequestingPermission = false;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _debounceSave(Function() doSave) {
    _debounce?.cancel();
    _debounce = Timer(AppConstants.debounceDuration, doSave);
  }

  Future<void> _toggleMasterPermission(bool value) async {
    if (value) {
      setState(() => _isRequestingPermission = true);
      try {
        final granted = await ref
            .read(notificationRepositoryProvider)
            .requestPermission();
        if (!mounted) return;
        setState(() {
          _permissionGranted = granted;
          _isRequestingPermission = false;
        });
        if (!granted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Benachrichtigungen sind in den Systemeinstellungen deaktiviert.',
              ),
            ),
          );
        }
      } catch (_) {
        if (mounted) setState(() => _isRequestingPermission = false);
      }
    } else {
      setState(() => _permissionGranted = false);
    }
  }

  bool _isAllowed(UserProfile profile) {
    if (_permissionGranted != null) return _permissionGranted!;
    return profile.remindersEnabled ||
        profile.dailySummaryEnabled ||
        profile.pushEnabled;
  }

  Future<void> _pickDailySummaryTime(UserProfile profile) async {
    final parts = profile.dailySummaryTime.split(':');
    final current = TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: current,
      helpText: 'Uhrzeit wählen',
      cancelText: 'Abbrechen',
      confirmText: 'Speichern',
    );
    if (picked == null || !mounted) return;
    final formatted =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    ref
        .read(profileProvider.notifier)
        .updateProfile(profile.copyWith(dailySummaryTime: formatted));
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

          final allowed = _isAllowed(profile);

          return SingleChildScrollView(
            padding: AppConstants.paddingLg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Master permission
                SettingsSectionCard(
                  icon: Icons.notifications_outlined,
                  title: 'Benachrichtigungen',
                  child: _isRequestingPermission
                      ? const Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: AppConstants.spacingMd,
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
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
                      : SwitchListTile(
                          title: const Text('Benachrichtigungen erlauben'),
                          value: allowed,
                          activeThumbColor: AppTheme.primary,
                          contentPadding: EdgeInsets.zero,
                          onChanged: _toggleMasterPermission,
                        ),
                ),
                AppConstants.gap16,

                // Gated sections
                IgnorePointer(
                  ignoring: !allowed,
                  child: AnimatedOpacity(
                    opacity: allowed ? 1.0 : AppConstants.disabledOpacity,
                    duration: AppConstants.animFast,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Erinnerungen
                        SettingsSectionCard(
                          icon: Icons.alarm_outlined,
                          title: 'Erinnerungen',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SwitchListTile(
                                title: const Text('Erinnerungen'),
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
                                AppConstants.gap8,
                                ReminderTimePicker(
                                  selectedTimes: profile.reminderTimes,
                                  onChanged: (newTimes) {
                                    _debounceSave(() {
                                      ref
                                          .read(profileProvider.notifier)
                                          .updateProfile(
                                            profile.copyWith(
                                              reminderTimes: newTimes,
                                            ),
                                          );
                                    });
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                        AppConstants.gap16,

                        // Tägliche Zusammenfassung
                        SettingsSectionCard(
                          icon: Icons.self_improvement_outlined,
                          title: 'Tägliche Zusammenfassung',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SwitchListTile(
                                title: const Text('Tägliche Zusammenfassung'),
                                value: profile.dailySummaryEnabled,
                                activeThumbColor: AppTheme.primary,
                                contentPadding: EdgeInsets.zero,
                                onChanged: (v) {
                                  ref
                                      .read(profileProvider.notifier)
                                      .updateProfile(
                                        profile.copyWith(
                                          dailySummaryEnabled: v,
                                        ),
                                      );
                                },
                              ),
                              if (profile.dailySummaryEnabled) ...[
                                AppConstants.gap8,
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
                                      onTap: () =>
                                          _pickDailySummaryTime(profile),
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

                        // Empfehlungen & Tipps
                        SettingsSectionCard(
                          icon: Icons.lightbulb_outline,
                          title: 'Empfehlungen & Tipps',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SwitchListTile(
                                title: const Text('Empfehlungen & Tipps'),
                                value: profile.pushEnabled,
                                activeThumbColor: AppTheme.primary,
                                contentPadding: EdgeInsets.zero,
                                onChanged: (v) {
                                  ref
                                      .read(profileProvider.notifier)
                                      .updateProfile(
                                        profile.copyWith(pushEnabled: v),
                                      );
                                },
                              ),
                              const Text(
                                'Wir benachrichtigen dich, wenn Belly Buddy deine Daten analysiert hat und neue Tipps für dich bereit sind.',
                                style: TextStyle(
                                  fontSize: AppTheme.fontSizeCaptionLG,
                                  color: AppTheme.mutedForeground,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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
