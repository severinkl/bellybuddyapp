import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../providers/buddy_offers_provider.dart';
import '../../providers/buddy_onboarding_gate_provider.dart';
import '../../providers/buddy_provider.dart';
import '../../providers/buddy_welcome_provider.dart';
import '../../providers/discover_news_provider.dart';
import '../../providers/entries_provider.dart';
import '../../providers/insights_provider.dart';
import '../../providers/journey_provider.dart';
import '../../providers/journey_rewards_provider.dart';
import '../../providers/upgrade_gate_provider.dart';
import '../../widgets/common/upgrade_available_dialog.dart';
import '../../providers/profile_provider.dart';
import '../../providers/recommendation_provider.dart';
import '../../router/route_names.dart';
import '../../providers/tutorial_provider.dart';
import 'widgets/buddy_hero.dart';
import 'widgets/insight_card.dart';
import 'widgets/journey_reward_line.dart';
import 'widgets/notification_opt_in_dialog.dart';
import 'widgets/tips_row.dart';
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
  /// The longest the first tour waits for the Buddy's welcome.
  static const _welcomeWait = Duration(seconds: 8);

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
    // New tips and the weekly-tips offer, whenever they apply: offered to
    // the Buddy in a microtask, never during a build. He queues each once.
    ref.listenManual<Map<BuddyAnnouncement, String>>(
      buddyOffersProvider,
      (_, offers) => Future.microtask(() => _offerToBuddy(offers)),
      fireImmediately: true,
    );
    // He drops an offer while he has no status (his load failed): once he
    // has one (or another user's), the offers go to him again.
    ref.listenManual<String?>(
      buddyProvider.select((buddy) => buddy.value?.state.userId),
      (previous, userId) {
        if (userId == null || userId == previous) return;
        Future.microtask(() {
          if (mounted) _offerToBuddy(ref.read(buddyOffersProvider));
        });
      },
    );
  }

  /// Hands each of [offers] to the Buddy ([BuddyNotifier.offerAnnouncement]).
  void _offerToBuddy(Map<BuddyAnnouncement, String> offers) {
    if (!mounted) return;
    final buddy = ref.read(buddyProvider.notifier);
    for (final MapEntry(key: kind, value: suffix) in offers.entries) {
      unawaited(buddy.offerAnnouncement(kind, suffix: suffix));
    }
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
    // Right after the Buddy onboarding he says his welcome first; the tour
    // would cover it. At most [_welcomeWait]: a welcome he never gets to say
    // (Home hidden) holds nothing up. tutorialSeenAt is persisted at the
    // tour's end.
    if (!replay) {
      await ref
          .read(buddyWelcomeProvider.notifier)
          .played
          .timeout(_welcomeWait, onTimeout: () {});
      if (!mounted || _tutorialHandle != null) return;
    }
    final handle = showDashboardTutorial(context);
    _tutorialHandle = handle;
    await handle.future;
    _tutorialHandle = null;
    if (!mounted) return;
    await ref.read(tutorialProvider.notifier).markSeen();
  }

  /// Loads what Home shows. Never throws: a part that fails (offline) is
  /// logged by its provider and Home shows what it has, so the first-run
  /// prompts and a replay request still follow; pull to refresh tries again.
  Future<void> _loadData({bool refreshTips = false}) async {
    try {
      await Future.wait<void>([
        ref.read(profileProvider.notifier).fetchProfile(),
        ref
            .read(entriesProvider.notifier)
            .loadEntries(ref.read(buddyClockProvider)(), refreshLatest: true),
        ref.read(buddyProvider.notifier).reload(),
        ref.read(insightsProvider.notifier).refresh(),
        // The first load leaves the tips to the app root's sign-in load.
        if (refreshTips) ref.read(discoverNewsProvider.notifier).refresh(),
      ]);
    } catch (_) {
      // Logged by entriesProvider, the one part that rethrows.
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
    ref.listen<bool>(tutorialProvider, (_, pending) {
      if (pending && _firstRunDone) Future.microtask(_maybeShowTutorial);
    });
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _loadData(refreshTips: true),
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
                // Only the card rebuilds with the insights. It shows only
                // AsyncData: after a user change, the value of a loading or
                // failed state is still the previous user's. The reward
                // line only while there is one.
                Consumer(
                  builder: (_, ref, _) => InsightCard(
                    key: TutorialKeys.insight,
                    insights: ref.watch(insightsProvider),
                    journey: ref.watch(journeyProvider),
                    journeyReward:
                        ref.watch(
                          journeyRewardLineProvider.select(
                            (line) => line != null,
                          ),
                        )
                        ? const JourneyRewardLineView()
                        : null,
                  ),
                ),
                // Only while a tip set is new.
                Consumer(
                  builder: (context, ref, _) {
                    final set = ref.watch(unseenTipSetProvider);
                    if (set == null) return const SizedBox.shrink();
                    return Column(
                      children: [
                        AppConstants.gap12,
                        TipsRow(
                          set: set,
                          onTap: () => context.push(RoutePaths.recommendations),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
