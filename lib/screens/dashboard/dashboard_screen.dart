import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../providers/entries_provider.dart';
import '../../providers/ingredient_suggestion_provider.dart';
import '../../providers/profile_provider.dart';
import '../../router/route_names.dart';
import '../../widgets/common/tracker_card.dart';
import 'widgets/feature_card.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(_loadData);
  }

  Future<void> _loadData() async {
    await Future.wait<void>([
      ref.read(profileProvider.notifier).fetchProfile(),
      ref.read(entriesProvider.notifier).loadEntries(DateTime.now()),
      ref.read(ingredientSuggestionProvider.notifier).fetchSuggestions(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final newCount =
        ref.watch(ingredientSuggestionProvider.notifier).newCount;

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
                  padding: EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: _DashboardHeader(),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: _TrackerCards(),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
              SliverFillRemaining(
                hasScrollBody: false,
                child: _ForYouSection(newCount: newCount),
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
        GestureDetector(
          onTap: () => context.push(RoutePaths.settings),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.beige,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.settings,
              color: AppTheme.foreground,
              size: 20,
            ),
          ),
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
            svgPath: AppConstants.logoSvg,
            label: 'Bauchgefühl',
            onTap: () => context.push(RoutePaths.gutFeelingTracker),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TrackerCard(
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
  final int newCount;

  const _ForYouSection({required this.newCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: const BoxDecoration(
        color: AppTheme.beige,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 16),
            child: Text(
              'Für dich erstellt',
              style: TextStyle(
                fontSize: 18,
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
                  iconColor: AppTheme.primary,
                  onTap: () => context.push(RoutePaths.recommendations),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FeatureCard(
                  imageAsset: AppConstants.alternativenCard,
                  label: 'Alternativen',
                  icon: Icons.eco,
                  iconColor: AppTheme.chipGluten,
                  badgeCount: newCount,
                  onTap: () => context.push(RoutePaths.ingredientSuggestions),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
              const SizedBox(width: 12),
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
