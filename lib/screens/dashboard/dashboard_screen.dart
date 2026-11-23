import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../providers/buddy_onboarding_gate_provider.dart';
import '../../providers/buddy_provider.dart';
import '../../providers/entries_provider.dart';
import '../../providers/insight_progress_provider.dart';
import '../../providers/upgrade_gate_provider.dart';
import '../../widgets/common/upgrade_available_dialog.dart';
import '../../providers/profile_provider.dart';
import '../../providers/tutorial_provider.dart';
import '../../utils/logger.dart';
import 'widgets/buddy_hero.dart';
import 'widgets/insight_card.dart';
import 'widgets/notification_opt_in_dialog.dart';
import 'widgets/tutorial/show_dashboard_tutorial.dart';
import 'widgets/tutorial/tutorial_keys.dart';

/// Home: the Buddy hero (streak chip, the Buddy in his care ring, the next
/// action) and what he is learning about the user's gut ([InsightCard]).
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  static const _log = AppLogger('Dashboard');

  // Active tutorial handle; non-null while the overlay is open. Cancelled
  // in dispose() so the OverlayEntry + its AnimationController don't leak
  // if the screen is torn down mid-tour (e.g. sign-out).
  TutorialHandle? _tutorialHandle;

  // Set once the first load is done and no Buddy onboarding takes over.
  // From then on a replay request starts the tour right away; before, the
  // post-load path takes it.
  bool _firstRunDone = false;

  @override
  void initState() {
    super.initState();
    // Order is load-bearing: _loadData awaits fetchProfile, so by the time
    // _maybeShowTutorial reads profileProvider.shouldShow() the profile is
    // guaranteed to be AsyncData (or AsyncError).
    Future.microtask(() async {
      await _loadData();
      // A pending Buddy onboarding is about to replace the dashboard (router
      // gate): no first-run prompts underneath it. They run when the
      // onboarding comes back here.
      if (!mounted || ref.read(buddyOnboardingRequiredProvider)) return;
      _firstRunDone = true;
      await _maybeShowTutorial();
      if (!mounted) return;
      _maybeShowNotificationModal();
    });
    // The soft nudge may already be pending when the dashboard mounts (e.g.
    // the user signed in after the decision resolved). If it resolves later,
    // the listener in build() picks it up instead.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowSoftNudge());
  }

  /// Shows the "update available" dialog if a soft nudge is pending. The flag
  /// is consumed before showing, so the dialog appears at most once.
  void _maybeShowSoftNudge() {
    if (!mounted) return;
    if (!ref.read(softNudgePendingProvider.notifier).consume()) return;
    showUpgradeAvailableDialog(context, ref);
  }

  @override
  void dispose() {
    _tutorialHandle?.cancel();
    _tutorialHandle = null;
    super.dispose();
  }

  /// Shows the tour to a new user, and again for each replay requested in
  /// the Ich tab („Tutorial wiederholen"), even when it was seen. The
  /// request is taken here, so each one shows the tour once.
  Future<void> _maybeShowTutorial() async {
    if (!mounted) return;
    final tutorial = ref.read(tutorialProvider.notifier);
    // Taken even while a tour is up: that tour answers the request.
    final replay = tutorial.consumeReplay();
    if (_tutorialHandle != null) return;
    if (!replay && !tutorial.shouldShow()) return;
    // The Buddy onboarding already welcomed the user: the spotlight tour
    // starts right away. tutorialSeenAt is persisted at its end.
    final handle = showDashboardTutorial(context);
    _tutorialHandle = handle;
    await handle.future;
    _tutorialHandle = null;
    if (!mounted) return;
    await ref.read(tutorialProvider.notifier).markSeen();
  }

  Future<void> _loadData() async {
    await Future.wait<void>([
      ref.read(profileProvider.notifier).fetchProfile(),
      ref
          .read(entriesProvider.notifier)
          .loadEntries(ref.read(buddyClockProvider)()),
      _refreshBuddy(),
      ref.read(insightProgressProvider.notifier).refresh(),
    ]);
  }

  /// Re-evaluates the Buddy's streak. Never throws: a missing backend table
  /// or a network error only hides the streak chip, so pull-to-refresh
  /// still completes.
  Future<void> _refreshBuddy() async {
    try {
      final buddy = ref.read(buddyProvider);
      if (buddy.isLoading && !buddy.hasValue) {
        // The first load (started by the hero) is still running; wait for
        // it instead of syncing twice.
        await ref.read(buddyProvider.future);
      } else {
        await ref.read(buddyProvider.notifier).refresh();
      }
    } catch (e, st) {
      _log.error('Refreshing the Buddy failed', e, st);
    }
  }

  Future<void> _maybeShowNotificationModal() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(AppConstants.keyNotificationModalShown) ?? false) return;
    if (!mounted) return;
    showNotificationOptInDialog(context);
  }

  @override
  Widget build(BuildContext context) {
    // The upgrade decision usually resolves after the first frame (the
    // dashboard renders under the splash), so react when the flag flips.
    ref.listen<bool>(softNudgePendingProvider, (_, pending) {
      if (pending) _maybeShowSoftNudge();
    });
    // „Tutorial wiederholen" while Home is already built (the shell keeps
    // the tab): the Ich tab requests, then goes Home, and the tour starts in
    // that same frame. Taken in a microtask, not inside this notification;
    // before the first load is done, the post-load path takes it instead.
    ref.listen<bool>(tutorialReplayProvider, (_, pending) {
      if (pending && _firstRunDone) Future.microtask(_maybeShowTutorial);
    });
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppTheme.primary,
          // Not lazy: every tour target is built and laid out, even below
          // the fold, for the tour to scroll to.
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppConstants.spacingLg,
              AppConstants.spacingSm,
              AppConstants.spacingLg,
              AppConstants.spacingLg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BuddyHero(key: TutorialKeys.buddy),
                AppConstants.gap16,
                // Only the card rebuilds with its progress.
                Consumer(
                  builder: (_, ref, _) => InsightCard(
                    key: TutorialKeys.insight,
                    progress: ref.watch(insightProgressProvider),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
