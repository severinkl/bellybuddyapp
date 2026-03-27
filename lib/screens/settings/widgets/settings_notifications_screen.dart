import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../models/user_profile.dart';
import '../../../providers/profile_provider.dart';
import '../../../repositories/notification_repository.dart';
import '../../../widgets/common/bb_async_state.dart';
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

  /// Tracks whether the user has granted notification permission this session.
  /// `null` means not yet determined — derived from profile on first build.
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
    // If user has explicitly toggled this session, use that.
    if (_permissionGranted != null) return _permissionGranted!;
    // Otherwise derive from profile: if any notification is on, assume allowed.
    return profile.remindersEnabled ||
        profile.dailySummaryEnabled ||
        profile.pushEnabled;
  }

  SwitchListTile _buildToggle({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      activeThumbColor: AppTheme.primary,
      contentPadding: EdgeInsets.zero,
      onChanged: onChanged,
    );
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
                      : _buildToggle(
                          title: 'Benachrichtigungen erlauben',
                          subtitle:
                              'Erlaube Benachrichtigungen, um Erinnerungen zu erhalten.',
                          value: allowed,
                          onChanged: _toggleMasterPermission,
                        ),
                ),
                AppConstants.gap16,
                IgnorePointer(
                  ignoring: !allowed,
                  child: AnimatedOpacity(
                    opacity: allowed ? 1.0 : AppConstants.disabledOpacity,
                    duration: AppConstants.animFast,
                    child: BbCard(
                      child: Column(
                        children: [
                          _buildToggle(
                            title: 'Erinnerungen',
                            subtitle: 'Tägliche Erinnerungen zum Tracken',
                            value: profile.remindersEnabled,
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
                          _buildToggle(
                            title: 'Tägliche Zusammenfassung',
                            subtitle: 'Abends dein Bauchgefühl-Rückblick',
                            value: profile.dailySummaryEnabled,
                            onChanged: (v) {
                              ref
                                  .read(profileProvider.notifier)
                                  .updateProfile(
                                    profile.copyWith(dailySummaryEnabled: v),
                                  );
                            },
                          ),
                          const Divider(),
                          _buildToggle(
                            title: 'Empfehlungen & Tipps',
                            subtitle: 'Push-Benachrichtigungen',
                            value: profile.pushEnabled,
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
