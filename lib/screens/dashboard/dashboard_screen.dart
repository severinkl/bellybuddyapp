import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../providers/entries_provider.dart';
import '../../providers/ingredient_suggestion_provider.dart';
import '../../providers/recommendation_provider.dart';
import '../../providers/upgrade_gate_provider.dart';
import '../../widgets/common/circle_icon_button.dart';
import '../../widgets/common/upgrade_available_dialog.dart';
import '../../providers/profile_provider.dart';
import '../../providers/tutorial_provider.dart';
import '../../router/route_names.dart';
import '../../widgets/common/tracker_card.dart';
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
      await _maybeShowTutorial();
      if (!mounted) return;
      _maybeShowNotificationModal();
    });
    // Show the soft-nudge dialog on the dashboard's first frame if the
    // splash decided the installed app is below `latest_version`. One-shot:
    // reset the flag immediately so a rebuild / hot-reload doesn't re-trigger.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(softNudgePendingProvider)) {
        ref.read(softNudgePendingProvider.notifier).set(false);
        showUpgradeAvailableDialog(context);
      }
    });
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
    ]);
  }

  Future<void> _maybeShowNotificationModal() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(AppConstants.keyNotificationModalShown) ?? false) return;
    if (!mounted) return;
    showNotificationOptInDialog(context);
  }

  @override
  Widget build(BuildContext context) {
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
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppConstants.spacingLg,
                    AppConstants.spacingLg,
                    AppConstants.spacingLg,
                    0,
                  ),
                  child: _DashboardHeader(),
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
      mainAxisAlignment: MainAxisAlignment.end,
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
                  label: 'Für dich',
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
