import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../providers/profile_provider.dart';
import '../../../repositories/notification_repository.dart';
import '../../../widgets/common/bb_card.dart';
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
  bool _notificationsAllowed = false;

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
      final granted = await ref
          .read(notificationRepositoryProvider)
          .requestPermission();
      setState(() => _notificationsAllowed = granted);
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Benachrichtigungen sind in den Systemeinstellungen deaktiviert.',
            ),
          ),
        );
      }
    } else {
      setState(() => _notificationsAllowed = false);
    }
  }

  @override
  void initState() {
    super.initState();
    // Check if notifications were previously enabled (any notification toggle is on)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = ref.read(profileProvider).whenOrNull(data: (p) => p);
      if (profile != null) {
        final hasAnyEnabled =
            profile.remindersEnabled ||
            profile.dailySummaryEnabled ||
            profile.pushEnabled;
        if (hasAnyEnabled) {
          setState(() => _notificationsAllowed = true);
        }
      }
    });
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
                // Master permission banner
                SettingsSectionCard(
                  icon: Icons.notifications_outlined,
                  title: 'Benachrichtigungen',
                  child: SwitchListTile(
                    title: const Text('Benachrichtigungen erlauben'),
                    subtitle: const Text(
                      'Erlaube Benachrichtigungen, um Erinnerungen zu erhalten.',
                    ),
                    value: _notificationsAllowed,
                    activeThumbColor: AppTheme.primary,
                    contentPadding: EdgeInsets.zero,
                    onChanged: _toggleMasterPermission,
                  ),
                ),
                AppConstants.gap16,

                // Notification settings card — greyed out when permission not granted
                IgnorePointer(
                  ignoring: !_notificationsAllowed,
                  child: AnimatedOpacity(
                    opacity: _notificationsAllowed ? 1.0 : 0.4,
                    duration: AppConstants.animFast,
                    child: BbCard(
                      child: Column(
                        children: [
                          // Row 1: Erinnerungen
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

                          const Divider(),

                          // Row 2: Tägliche Zusammenfassung
                          SwitchListTile(
                            title: const Text('Tägliche Zusammenfassung'),
                            subtitle: const Text(
                              'Abends dein Bauchgefühl-Rückblick',
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

                          const Divider(),

                          // Row 3: Empfehlungen & Tipps (Push)
                          SwitchListTile(
                            title: const Text('Empfehlungen & Tipps'),
                            subtitle: const Text('Push-Benachrichtigungen'),
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
                        ],
                      ),
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
