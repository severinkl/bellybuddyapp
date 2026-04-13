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
import '../../widgets/common/circle_icon_button.dart';
import '../../providers/profile_provider.dart';
import '../../router/route_names.dart';
import '../../widgets/common/tracker_card.dart';
import 'widgets/feature_card.dart';
import 'widgets/notification_opt_in_dialog.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await _loadData();
      _maybeShowNotificationModal();
    });
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
              SliverToBoxAdapter(
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
          icon: Icons.feedback_outlined,
          size: AppConstants.iconBadgeLg,
          onPressed: () => launchUrl(
            Uri.parse(AppConstants.feedbackFormUrl),
            mode: LaunchMode.externalApplication,
          ),
        ),
        const SizedBox(width: AppConstants.spacingSm),
        CircleIconButton(
          key: const Key('dashboard_settings_button'),
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
            key: const Key('tracker_card_gut_feeling'),
            svgPath: AppConstants.logoSvg,
            label: 'Bauchgefühl',
            onTap: () => context.push(RoutePaths.gutFeelingTracker),
          ),
        ),
        const SizedBox(width: AppConstants.spacing12),
        Expanded(
          child: TrackerCard(
            key: const Key('tracker_card_toilet'),
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
