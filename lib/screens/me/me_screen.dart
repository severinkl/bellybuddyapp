import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../providers/buddy_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/plus_provider.dart';
import '../../providers/rating_provider.dart';
import '../../providers/shares_provider.dart';
import '../../providers/tutorial_provider.dart';
import '../../providers/upgrade_gate_provider.dart';
import '../../router/navigation_extensions.dart';
import '../../router/route_names.dart';
import '../../services/app_version_service.dart';
import '../../services/plus/plus_copy.dart';
import '../../services/progress/progress_copy.dart';
import '../../services/purchases/purchases_gateway.dart';
import '../../utils/buddy_name.dart';
import '../../utils/logger.dart';
import '../../utils/url_utils.dart';
import '../../widgets/buddy/buddy.dart';
import '../../widgets/buddy/streak_chip.dart';
import '../../widgets/common/bb_settings_item.dart';
import '../dashboard/widgets/reminders_ask_sheet.dart';
import '../dashboard/widgets/streak_sheet.dart';
import 'widgets/rename_buddy_dialog.dart';

/// The Ich tab, without an app bar (its body sits in a [SafeArea], as
/// Home's does; the Buddy's name is the screen's heading): the Buddy with
/// his name („Umbenennen") and streak chip, then „Erinnerungen sind aus"
/// while notifications are off ([remindersOffProvider]; „Einschalten"),
/// Streak & Ziel („Dein Streak"), Dein Verlauf (always), Mit Berater:in
/// teilen, Einstellungen, Tutorial wiederholen, „Belly Buddy bewerten" and
/// Feedback geben, and the app version in small print.
///
/// Without a Buddy status (loading, error) the Buddy shows as 'Buddy',
/// without the chip, „Umbenennen" and the Streak row.
class MeScreen extends ConsumerStatefulWidget {
  const MeScreen({super.key, this.openUrl = launchUrl});

  static const renameKey = Key('me_rename');
  static const remindersKey = Key('me_reminders');
  static const streakKey = Key('me_streak');
  static const progressKey = Key('me_progress');
  static const shareKey = Key('me_share');
  static const plusKey = Key('me_plus');
  static const settingsKey = Key('me_settings');
  static const tutorialKey = Key('me_tutorial');
  static const rateKey = Key('me_rate');
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

  /// „Einschalten" is on its way (the OS dialog may be up).
  bool _turningOn = false;

  /// „Belly Buddy bewerten" is opening the store: further taps wait.
  bool _rating = false;

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
        SnackBar(
          content: Text(
            BuddyNameRules.refusedAsTooLong(e)
                ? BuddyNameRules.tooManySymbols
                : 'Umbenennen hat nicht geklappt. Versuch es später nochmal.',
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

  /// „Erinnerungen sind aus · Einschalten": as the Buddy's ask does
  /// ([turnOnRemindersOrSay]); one at a time.
  Future<void> _turnOnReminders() async {
    if (_turningOn) return;
    _turningOn = true;
    try {
      await turnOnRemindersOrSay(context, ref);
    } finally {
      _turningOn = false;
    }
  }

  /// „Belly Buddy bewerten": the store page for a review, else the plain
  /// store page, else a message. Never counts as the Buddy's rating ask.
  Future<void> _rate() async {
    if (_rating) return;
    _rating = true;
    try {
      final messenger = ScaffoldMessenger.of(context);
      final ok = await _openListing() || await _openStorePage();
      if (!ok) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Der Store konnte nicht geöffnet werden.'),
          ),
        );
      }
    } finally {
      _rating = false;
    }
  }

  /// The store page, ready for a review; whether it opened.
  Future<bool> _openListing() async {
    try {
      await ref.read(ratingLauncherProvider).openStoreListing();
      return true;
    } catch (e, st) {
      _log.error('Opening the store listing failed', e, st);
      return false;
    }
  }

  /// The plain store page; whether it opened.
  Future<bool> _openStorePage() async {
    try {
      final opened = await ref.read(appVersionServiceProvider).openStore();
      if (!opened) _log.error('The store page did not open');
      return opened;
    } catch (e, st) {
      _log.error('Opening the store failed', e, st);
      return false;
    }
  }

  /// The share list is on its way: a second tap in the same frame opens
  /// nothing. From the next frame the pushed route covers this screen and
  /// takes the taps, so the flag is cleared then, not when the push
  /// completes: a `go` that replaces the stack never completes it.
  bool _openingShare = false;

  /// The share row: the list; with no share (or no list) the create screen
  /// on top of it.
  void _openShare() {
    if (_openingShare) return;
    _openingShare = true;
    unawaited(ref.read(shareRowBadgeProvider.notifier).markTapped());
    final shares = ref.read(sharesProvider).value;
    WidgetsBinding.instance.addPostFrameCallback((_) => _openingShare = false);
    unawaited(context.push(RoutePaths.shares));
    // Without a share the create screen goes on top of the list at once —
    // the paywall instead while Plus is locked (a new share needs it).
    if (shares == null || shares.isEmpty) {
      final locked = ref.read(plusLockedProvider);
      unawaited(
        locked ? context.openPlus() : context.push(RoutePaths.shareCreate),
      );
    }
  }

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
    final remindersOff = ref.watch(remindersOffProvider).value ?? false;
    // Watched so the list is loaded when the row is tapped; only whether it
    // is empty matters here.
    ref.watch(sharesProvider.select((s) => s.value?.isEmpty));
    // Without an SDK key (R14) nothing can be bought: no row.
    final paywallOn =
        ref.watch(paywallEnabledProvider) &&
        ref.watch(purchasesGatewayProvider.select((g) => g.available));
    // While the status loads or fails the row shows without a subtitle: any
    // line could be wrong for a subscriber. The value is not enough: after
    // an account switch Riverpod keeps the previous (blanked) value while
    // the next user's status loads.
    final plusSubtitle = paywallOn
        ? ref.watch(
            plusProvider.select(
              (p) => p.isLoading || p.hasError ? null : p.value,
            ),
          )
        : null;
    final showShareBadge = ref.watch(shareRowBadgeProvider).value ?? false;

    final rows = [
      if (remindersOff)
        BbSettingsItem(
          key: MeScreen.remindersKey,
          icon: Icons.notifications_off_outlined,
          title: 'Erinnerungen sind aus',
          subtitle: remindersTurnOnLabel,
          onTap: () => unawaited(_turnOnReminders()),
        ),
      if (status != null)
        BbSettingsItem(
          key: MeScreen.streakKey,
          icon: Icons.local_fire_department_outlined,
          title: 'Streak & Ziel',
          subtitle: _streakSubtitle(status),
          onTap: () => unawaited(_openStreak()),
        ),
      BbSettingsItem(
        key: MeScreen.progressKey,
        icon: Icons.calendar_view_week_outlined,
        title: ProgressCopy.title,
        subtitle: ProgressCopy.meSubtitle,
        onTap: () => context.push(RoutePaths.progress),
      ),
      BbSettingsItem(
        key: MeScreen.shareKey,
        icon: Icons.person_add_alt_1_outlined,
        title: 'Mit Berater:in teilen',
        subtitle: 'Tagebuch für Diätolog:in oder Ärzt:in freigeben',
        badge: showShareBadge ? 'Neu' : null,
        onTap: _openShare,
      ),
      if (paywallOn)
        BbSettingsItem(
          key: MeScreen.plusKey,
          icon: Icons.workspace_premium_outlined,
          title: PlusCopy.title,
          subtitle: plusSubtitle == null
              ? null
              : PlusCopy.statusLine(plusSubtitle),
          onTap: () => unawaited(context.openPlus()),
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
        key: MeScreen.rateKey,
        icon: Icons.star_outline,
        title: 'Belly Buddy bewerten',
        subtitle: 'Sag anderen, wie dir die App gefällt',
        onTap: () => unawaited(_rate()),
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
      body: SafeArea(
        child: SingleChildScrollView(
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
              Semantics(
                header: true,
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: AppTheme.fontSizeHeading,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.foreground,
                  ),
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
