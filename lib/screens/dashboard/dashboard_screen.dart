import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../providers/buddy_onboarding_gate_provider.dart';
import '../../providers/buddy_provider.dart';
import '../../providers/entries_provider.dart';
import '../../providers/ingredient_suggestion_provider.dart';
import '../../providers/recommendation_provider.dart';
import '../../providers/upgrade_gate_provider.dart';
import '../../widgets/common/circle_icon_button.dart';
import '../../widgets/common/upgrade_available_dialog.dart';
import '../../providers/profile_provider.dart';
import '../../providers/tutorial_provider.dart';
import '../../router/route_names.dart';
import '../../utils/logger.dart';
import '../../widgets/common/tracker_card.dart';
import 'widgets/buddy_hero.dart';
import 'widgets/feature_card.dart';
import 'widgets/notification_opt_in_dialog.dart';
import 'widgets/tutorial/show_dashboard_tutorial.dart';
import 'widgets/tutorial/tutorial_keys.dart';

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

  Future<void> _maybeShowTutorial() async {
    if (!mounted) return;
    final shouldShow = ref.read(tutorialProvider.notifier).shouldShow();
    if (!shouldShow) return;
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
      ref.read(entriesProvider.notifier).loadEntries(DateTime.now()),
      ref.read(ingredientSuggestionProvider.notifier).fetchSuggestions(),
      _refreshBuddy(),
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
    ref.watch(ingredientSuggestionProvider); // rebuild on data changes
    final newSuggestionCount = ref
        .read(ingredientSuggestionProvider.notifier)
        .newCount;
    final newRecommendationCount =
        ref
            .watch(unseenRecommendationCountProvider)
            .whenOrNull(data: (count) => count) ??
        0;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppTheme.primary,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppConstants.spacingLg,
                    AppConstants.spacingSm,
                    AppConstants.spacingLg,
                    0,
                  ),
                  // The header icons sit top-right on the hero's streak row.
                  child: Stack(
                    children: [
                      BuddyHero(key: TutorialKeys.buddy),
                      const Positioned(
                        top: 0,
                        right: 0,
                        child: _DashboardHeader(),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: AppConstants.gap24),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppConstants.spacing12,
                  ),
                  child: _TrackerCards(),
                ),
              ),
              const SliverToBoxAdapter(child: AppConstants.gap32),
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacing12,
                  ),
                  child: _ForYouSection(
                    newSuggestionCount: newSuggestionCount,
                    newRecommendationCount: newRecommendationCount,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleIconButton(
          key: TutorialKeys.feedback,
          icon: Icons.feedback_outlined,
          size: AppConstants.iconBadgeLg,
          onPressed: () => launchUrl(
            Uri.parse(AppConstants.feedbackFormUrl),
            mode: LaunchMode.externalApplication,
          ),
        ),
        const SizedBox(width: AppConstants.spacingSm),
        CircleIconButton(
          key: TutorialKeys.settings,
          icon: Icons.settings,
          size: AppConstants.iconBadgeLg,
          onPressed: () => context.push(RoutePaths.settings),
        ),
      ],
    );
  }
}

class _TrackerCards extends StatelessWidget {
  const _TrackerCards();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TrackerCard(
            key: TutorialKeys.bauchgefuehl,
            svgPath: AppConstants.logoSvg,
            label: 'Bauchgefühl',
            onTap: () => context.push(RoutePaths.gutFeelingTracker),
          ),
        ),
        const SizedBox(width: AppConstants.spacing12),
        Expanded(
          child: TrackerCard(
            key: TutorialKeys.klo,
            svgPath: AppConstants.toiletPaperSvg,
            label: 'Klo',
            onTap: () => context.push(RoutePaths.toiletTracker),
          ),
        ),
      ],
    );
  }
}

class _ForYouSection extends StatelessWidget {
  final int newSuggestionCount;
  final int newRecommendationCount;

  const _ForYouSection({
    required this.newSuggestionCount,
    required this.newRecommendationCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.spacingMd,
        AppConstants.spacing20,
        AppConstants.spacingMd,
        AppConstants.spacingMd,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.beige,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusXl),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(
              left: AppConstants.spacingXs,
              bottom: AppConstants.spacingMd,
            ),
            child: Text(
              'Für dich erstellt',
              style: TextStyle(
                fontSize: AppTheme.fontSizeTitle,
                fontWeight: FontWeight.w600,
                color: AppTheme.foreground,
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: FeatureCard(
                  key: TutorialKeys.fuerDich,
                  imageAsset: AppConstants.fuerDichCard,
                  label: 'Tipps',
                  icon: Icons.auto_awesome,
                  iconColor: AppTheme.foreground,
                  hasNew: newRecommendationCount > 0,
                  onTap: () => context.push(RoutePaths.recommendations),
                ),
              ),
              const SizedBox(width: AppConstants.spacing12),
              Expanded(
                child: FeatureCard(
                  key: TutorialKeys.alternativen,
                  imageAsset: AppConstants.alternativenCard,
                  label: 'Alternativen',
                  icon: Icons.eco,
                  iconColor: AppTheme.foreground,
                  badgeCount: newSuggestionCount,
                  onTap: () => context.push(RoutePaths.ingredientSuggestions),
                ),
              ),
            ],
          ),
          AppConstants.gap12,
          Row(
            children: [
              Expanded(
                child: FeatureCard(
                  key: TutorialKeys.rezepte,
                  imageAsset: AppConstants.rezepteCard,
                  label: 'Rezepte',
                  icon: Icons.restaurant_menu,
                  iconColor: AppTheme.foreground,
                  onTap: () => context.push(RoutePaths.recipes),
                ),
              ),
              const SizedBox(width: AppConstants.spacing12),
              Expanded(
                child: FeatureCard(
                  key: TutorialKeys.wissen,
                  imageAsset: AppConstants.susiPhone,
                  label: 'Wissen',
                  icon: Icons.menu_book,
                  iconColor: AppTheme.foreground,
                  onTap: () => launchUrl(
                    Uri.parse('https://www.myfodmap.at/blog'),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
