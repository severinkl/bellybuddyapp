import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../providers/buddy_provider.dart';
import '../../providers/tutorial_provider.dart';
import '../../providers/upgrade_gate_provider.dart';
import '../../router/route_names.dart';
import '../../utils/logger.dart';
import '../../utils/url_utils.dart';
import '../../widgets/buddy/buddy.dart';
import '../../widgets/buddy/streak_chip.dart';
import '../../widgets/common/bb_settings_item.dart';
import '../dashboard/widgets/streak_sheet.dart';
import 'widgets/rename_buddy_dialog.dart';

/// The Ich tab: the Buddy with his name („Umbenennen") and streak chip,
/// then Streak & Ziel („Dein Streak"), Einstellungen, Tutorial wiederholen
/// and Feedback geben, and the app version in small print.
///
/// Without a Buddy status (loading, error) the Buddy shows as 'Buddy',
/// without the chip, „Umbenennen" and the Streak row.
class MeScreen extends ConsumerStatefulWidget {
  const MeScreen({super.key, this.openUrl = launchUrl});

  static const renameKey = Key('me_rename');
  static const streakKey = Key('me_streak');
  static const settingsKey = Key('me_settings');
  static const tutorialKey = Key('me_tutorial');
  static const feedbackKey = Key('me_feedback');

  /// Opens the feedback form.
  final UrlOpener openUrl;

  @override
  ConsumerState<MeScreen> createState() => _MeScreenState();
}

class _MeScreenState extends ConsumerState<MeScreen> {
  static const _log = AppLogger('MeScreen');

  final _buddy = BuddyController(mood: BuddyMood.happy);

  /// „Dein Streak" or the rename dialog is open, or what was chosen there
  /// still saves ([_oneSheet]).
  bool _sheetOpen = false;

  @override
  void dispose() {
    _buddy.dispose();
    super.dispose();
  }

  /// Runs [sheet] (a sheet or dialog and the save of what was chosen in it)
  /// unless one already runs: a second one (a tap while the first closes,
  /// chip and row) would start from the old status and race its write.
  Future<void> _oneSheet(Future<void> Function() sheet) async {
    if (_sheetOpen) return;
    _sheetOpen = true;
    try {
      await sheet();
    } finally {
      _sheetOpen = false;
    }
  }

  /// „Umbenennen": saves a new, different name; a failing save says so and
  /// the old name stays.
  Future<void> _rename() => _oneSheet(() async {
    final current = ref.read(buddyProvider).value?.state.name;
    if (current == null) return;
    final name = await showRenameBuddyDialog(context, current: current);
    if (name == null || name == current || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(buddyProvider.notifier).setName(name);
    } catch (e, st) {
      _log.error('Renaming the Buddy failed', e, st);
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Umbenennen hat nicht geklappt. Versuch es später nochmal.',
          ),
        ),
      );
    }
  });

  /// „Dein Streak", saving a goal chosen there.
  Future<void> _openStreak() => _oneSheet(() async {
    final status = ref.read(buddyProvider).value;
    if (status == null) return;
    await openStreakSheetAndSaveGoal(
      context,
      ref,
      status: status,
      today: ref.read(buddyClockProvider)(),
    );
  });

  Future<void> _openFeedback() => openExternalUrl(
    context,
    AppConstants.feedbackFormUrl,
    failureMessage: 'Das Feedback-Formular konnte nicht geöffnet werden.',
    open: widget.openUrl,
  );

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(buddyProvider).value;
    final version = ref.watch(currentVersionProvider).value;

    final rows = [
      if (status != null)
        BbSettingsItem(
          key: MeScreen.streakKey,
          icon: Icons.local_fire_department_outlined,
          title: 'Streak & Ziel',
          subtitle: _streakSubtitle(status),
          onTap: () => unawaited(_openStreak()),
        ),
      BbSettingsItem(
        key: MeScreen.settingsKey,
        icon: Icons.settings_outlined,
        title: 'Einstellungen',
        subtitle: 'Profil, Benachrichtigungen, Konto',
        onTap: () => context.push(RoutePaths.settings),
      ),
      BbSettingsItem(
        key: MeScreen.tutorialKey,
        icon: Icons.replay,
        title: 'Tutorial wiederholen',
        subtitle: 'Die Tour durch Home nochmal ansehen',
        onTap: () => ref.read(tutorialProvider.notifier).replayFrom(context),
      ),
      BbSettingsItem(
        key: MeScreen.feedbackKey,
        icon: Icons.feedback_outlined,
        title: 'Feedback geben',
        subtitle: 'Teile uns deine Ideen und Wünsche mit',
        onTap: () => unawaited(_openFeedback()),
      ),
    ];

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Ich')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppConstants.spacingMd,
          AppConstants.spacingSm,
          AppConstants.spacingMd,
          AppConstants.spacingLg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              controller: _buddy,
              status: status,
              onRename: () => unawaited(_rename()),
              onStreak: () => unawaited(_openStreak()),
            ),
            AppConstants.gap24,
            for (final (i, row) in rows.indexed) ...[
              if (i > 0) AppConstants.gap12,
              row,
            ],
            if (version != null) ...[
              AppConstants.gap24,
              Text(
                'Version $version',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: AppTheme.fontSizeCaption,
                  color: AppTheme.mutedForeground,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// „🔥 3 Tage · Ziel: 14 Tage", or „· Noch kein Ziel".
  static String _streakSubtitle(BuddyStatus status) {
    final streak = status.streak;
    final goal = status.state.streakGoal;
    final days = '$streak ${streak == 1 ? 'Tag' : 'Tage'}';
    return '🔥 $days · ${goal == null ? 'Noch kein Ziel' : 'Ziel: $goal Tage'}';
  }
}

/// The Buddy, his name with „Umbenennen", and the streak chip (both only
/// with a [status]).
class _Header extends StatelessWidget {
  const _Header({
    required this.controller,
    required this.status,
    required this.onRename,
    required this.onStreak,
  });

  final BuddyController controller;
  final BuddyStatus? status;
  final VoidCallback onRename;
  final VoidCallback onStreak;

  @override
  Widget build(BuildContext context) {
    final status = this.status;
    final name = status?.state.name ?? 'Buddy';
    return Row(
      children: [
        SizedBox.square(
          dimension: AppConstants.meBuddySize,
          child: AnimatedBuddy(controller: controller, name: name),
        ),
        const SizedBox(width: AppConstants.spacingMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: AppTheme.fontSizeHeading,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.foreground,
                ),
              ),
              if (status != null) ...[
                TextButton(
                  key: MeScreen.renameKey,
                  onPressed: onRename,
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  child: const Text('Umbenennen'),
                ),
                StreakChip(
                  streak: status.streak,
                  todayCounted: status.todayCounted,
                  onTap: onStreak,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
