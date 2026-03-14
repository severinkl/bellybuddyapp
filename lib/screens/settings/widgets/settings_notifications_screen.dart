import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../config/timezone_options.dart';
import '../../../providers/profile_provider.dart';
import '../../../services/edge_function_service.dart';
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
  bool _pushEnabled = true;
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

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Benachrichtigungen')),
      body: profileState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (profile) {
          if (profile == null) return const Center(child: Text('Kein Profil.'));
          final reminderTimes = profile.reminderTimes;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Push + reminder section
                SettingsSectionCard(
                  icon: Icons.notifications_outlined,
                  title: 'Benachrichtigungen',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile(
                        title: const Text('Push-Benachrichtigungen'),
                        subtitle: const Text('Erinnerungen und Updates'),
                        value: _pushEnabled,
                        activeThumbColor: AppTheme.primary,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (v) {
                          setState(() => _pushEnabled = v);
                          // FIXME(feature): Implement OneSignal opt-in/out toggle
                        },
                      ),
                      const Divider(),
                      const SizedBox(height: 12),
                      const Text(
                        'Erinnerungszeiten',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      ReminderTimePicker(
                        selectedTimes: reminderTimes,
                        onChanged: (newTimes) {
                          _debounceSave(() {
                            ref.read(profileProvider.notifier).updateProfile(
                                  profile.copyWith(reminderTimes: newTimes),
                                );
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () async {
                          try {
                            await EdgeFunctionService.invoke(
                              'send-push-notification',
                              body: {
                                'title': 'Test',
                                'body': 'Test-Benachrichtigung von Belly Buddy',
                                'userId': SupabaseService.userId,
                              },
                            );
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Test-Benachrichtigung gesendet!')),
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Fehler: $e')),
                            );
                          }
                        },
                        child: const Text('Test-Benachrichtigung senden'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Timezone section
                SettingsSectionCard(
                  icon: Icons.public,
                  title: 'Zeitzone',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Für die Erinnerungen zur richtigen Ortszeit',
                        style: TextStyle(fontSize: 13, color: AppTheme.mutedForeground),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: profile.timezone ?? 'Europe/Berlin',
                        isExpanded: true,
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        items: timezoneOptions
                            .map((tz) => DropdownMenuItem(
                                  value: tz.value,
                                  child: Text(tz.label, overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          _debounceSave(() {
                            ref.read(profileProvider.notifier).updateProfile(
                                  profile.copyWith(timezone: v),
                                );
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Debug section
                SettingsSectionCard(
                  icon: Icons.bug_report_outlined,
                  title: 'Debug-Info',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => _debugExpanded = !_debugExpanded),
                        child: Row(
                          children: [
                            Text(
                              _debugExpanded ? 'Details ausblenden' : 'Details anzeigen',
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppTheme.mutedForeground,
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              _debugExpanded ? Icons.expand_less : Icons.expand_more,
                              color: AppTheme.mutedForeground,
                            ),
                          ],
                        ),
                      ),
                      if (_debugExpanded) ...[
                        const SizedBox(height: 12),
                        _DebugRow(label: 'Plattform', value: Platform.operatingSystem),
                        _DebugRow(label: 'Push aktiviert', value: _pushEnabled ? 'Ja' : 'Nein'),
                        _DebugRow(label: 'Zeitzone', value: profile.timezone ?? 'Europe/Berlin'),
                        _DebugRow(
                          label: 'Erinnerungen',
                          value: reminderTimes.map((h) => '${h.toString().padLeft(2, '0')}:00').join(', '),
                        ),
                        _DebugRow(label: 'User ID', value: SupabaseService.userId ?? '—'),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 32),
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
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppTheme.mutedForeground),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}
