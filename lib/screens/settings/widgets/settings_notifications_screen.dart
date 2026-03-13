import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../providers/profile_provider.dart';
import '../../../services/edge_function_service.dart';

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

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
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

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Push toggle
                SwitchListTile(
                  title: const Text('Push-Benachrichtigungen'),
                  subtitle: const Text('Erinnerungen und Updates'),
                  value: _pushEnabled,
                  activeThumbColor: AppTheme.primary,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) {
                    setState(() => _pushEnabled = v);
                    // TODO: OneSignal opt-in/out
                  },
                ),
                const Divider(),
                const SizedBox(height: 16),

                const Text(
                  'Erinnerungszeiten',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ...List.generate(24, (hour) {
                  final isActive = reminderTimes.contains(hour);
                  return CheckboxListTile(
                    title: Text('${hour.toString().padLeft(2, '0')}:00 Uhr'),
                    value: isActive,
                    activeColor: AppTheme.primary,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) {
                      final newTimes = List<int>.from(reminderTimes);
                      if (v == true) {
                        newTimes.add(hour);
                      } else {
                        newTimes.remove(hour);
                      }
                      newTimes.sort();
                      _debounce?.cancel();
                      _debounce = Timer(AppConstants.debounceDuration, () {
                        ref
                            .read(profileProvider.notifier)
                            .updateProfile(profile.copyWith(reminderTimes: newTimes));
                      });
                    },
                  );
                }).where((w) {
                  // Show common hours only
                  return true;
                }),

                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: () async {
                    try {
                      await EdgeFunctionService.invoke('send-push-notification', body: {
                        'title': 'Test',
                        'body': 'Test-Benachrichtigung von Belly Buddy',
                      });
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Test-Benachrichtigung gesendet!')),
                        );
                      }
                    } catch (_) {}
                  },
                  child: const Text('Test-Benachrichtigung senden'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
