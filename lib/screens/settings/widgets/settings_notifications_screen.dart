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
                      : SwitchListTile(
                          title: const Text('Benachrichtigungen erlauben'),
                          value: allowed,
                          activeThumbColor: AppTheme.primary,
                          contentPadding: EdgeInsets.zero,
                          onChanged: _toggleMasterPermission,
                        ),
                ),
                AppConstants.gap16,

                IgnorePointer(
                  ignoring: !allowed,
                  child: AnimatedOpacity(
                    opacity: allowed ? 1.0 : AppConstants.disabledOpacity,
                    duration: AppConstants.animFast,
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
                              const Text(
                                'Erinnert dich daran, deine Mahlzeiten zu tracken.',
                                style: TextStyle(
                                  fontSize: AppTheme.fontSizeCaptionLG,
                                  color: AppTheme.mutedForeground,
                                ),
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
                              AppConstants.gap8,
                              const Divider(
                                color: AppTheme.border,
                                thickness: 0.5,
                              ),
                              AppConstants.gap8,

                              SwitchListTile(
                                title: const Text('Bauchgefühl'),
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
                              const Text(
                                'Erinnert dich daran, dein Bauchgefühl einzutragen.',
                                style: TextStyle(
                                  fontSize: AppTheme.fontSizeCaptionLG,
                                  color: AppTheme.mutedForeground,
                                ),
                              ),
                              if (profile.dailySummaryEnabled) ...[
                                AppConstants.gap8,
                                ReminderTimePicker(
                                  selectedTimes: [profile.dailySummaryTime],
                                  onChanged: (newTimes) {
                                    if (newTimes.isEmpty) return;
                                    _debounceSave(() {
                                      ref
                                          .read(profileProvider.notifier)
                                          .updateProfile(
                                            profile.copyWith(
                                              dailySummaryTime: newTimes.first,
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
