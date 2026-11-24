import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../config/app_theme.dart';
import '../../providers/profile_provider.dart';
import '../../utils/logger.dart';

/// The „Wöchentliche Tipps" opt-in, with what it sends. It controls whether
/// the tips are made, not whether a push arrives. Shows nothing while the
/// profile is unknown.
class WeeklyTipsSwitch extends ConsumerStatefulWidget {
  const WeeklyTipsSwitch({super.key});

  static const title = 'Wöchentliche Tipps';
  static const sentence =
      'Dafür schicke ich deine Mahlzeiten und dein Bauchgefühl der letzten '
      'Woche an unseren KI-Dienst.';
  static const failure =
      'Wöchentliche Tipps konnten nicht gespeichert werden. '
      'Versuch es später nochmal.';
  static const switchKey = Key('weekly_tips_switch');

  @override
  ConsumerState<WeeklyTipsSwitch> createState() => _WeeklyTipsSwitchState();
}

class _WeeklyTipsSwitchState extends ConsumerState<WeeklyTipsSwitch> {
  static const _log = AppLogger('WeeklyTipsSwitch');
  bool _saving = false;

  Future<void> _set(bool enabled) async {
    if (_saving) return;
    _saving = true;
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await ref.read(profileProvider.notifier).setWeeklyTips(enabled);
    } catch (e, st) {
      _log.error('saving the weekly tips failed', e, st);
      messenger?.showSnackBar(
        const SnackBar(content: Text(WeeklyTipsSwitch.failure)),
      );
    } finally {
      _saving = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(weeklyTipsEnabledProvider);
    if (enabled == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          key: WeeklyTipsSwitch.switchKey,
          title: const Text(WeeklyTipsSwitch.title),
          value: enabled,
          activeThumbColor: AppTheme.primary,
          contentPadding: EdgeInsets.zero,
          onChanged: _set,
        ),
        const Text(
          WeeklyTipsSwitch.sentence,
          style: AppTheme.captionMutedStyle,
        ),
      ],
    );
  }
}
