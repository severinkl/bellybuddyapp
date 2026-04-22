import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../models/recommendation.dart';
import '../../providers/recommendation_index_provider.dart';
import '../../providers/recommendation_provider.dart';
import '../../services/haptic_service.dart';
import '../../utils/date_format_utils.dart';
import '../../widgets/common/bb_async_state.dart';
import '../../widgets/common/circle_icon_button.dart';
import '../../widgets/common/mascot_image.dart';
import 'widgets/recommendation_card.dart';
import 'widgets/recommendation_summary_card.dart';

class RecommendationsScreen extends ConsumerStatefulWidget {
  const RecommendationsScreen({super.key});

  static const emptyStateRefreshKey = Key(
    'recommendations_empty_refresh_button',
  );
  static const previousRecommendationKey = Key('recommendations_previous');
  static const nextRecommendationKey = Key('recommendations_next');

  @override
  ConsumerState<RecommendationsScreen> createState() =>
      _RecommendationsScreenState();
}

class _RecommendationsScreenState extends ConsumerState<RecommendationsScreen> {
  late final PageController _controller;

  /// The id of the latest recommendation the controller is currently anchored
  /// to. When a refresh brings a new latest in at index 0, this changes and
  /// we re-anchor the controller to the new `length - 1`.
  String? _anchoredLatestId;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    Future.microtask(() async {
      final notifier = ref.read(recommendationProvider.notifier);
      await notifier.fetchRecommendations();
      await notifier.markAllAsSeen();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Seed / re-seed the controller + index notifier when the data resolves
  /// or when a new latest recommendation arrives.
  void _maybeAnchor(List<Recommendation> list) {
    if (list.isEmpty) return;
    final latestId = list.first.id;
    if (latestId == _anchoredLatestId) return;
    _anchoredLatestId = latestId;

    final targetPage = list.length - 1;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_controller.hasClients) {
        _controller.jumpToPage(targetPage);
      }
      ref.read(recommendationIndexProvider.notifier).set(targetPage);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recommendationProvider);

    ref.listen<int>(recommendationIndexProvider, (_, next) {
      if (!_controller.hasClients) return;
      final current = (_controller.page ?? _controller.initialPage.toDouble())
          .round();
      if (current == next) return;
      _controller.animateToPage(
        next,
        duration: AppConstants.animNormal,
        curve: Curves.easeOut,
      );
    });

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, size: 20),
            SizedBox(width: AppConstants.spacingSm),
            Text('Empfehlungen'),
          ],
        ),
      ),
      body: state.when(
        loading: () =>
            const BbLoadingState(message: 'Analysiere deine Daten...'),
        error: (e, _) => ListView(
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.2),
            BbErrorState(
              message: 'Fehler beim Laden der Empfehlungen.',
              onRetry: () => ref
                  .read(recommendationProvider.notifier)
                  .fetchRecommendations(),
            ),
          ],
        ),
        data: (recommendations) {
          if (recommendations.isEmpty) return _buildEmptyState();
          _maybeAnchor(recommendations);
          return _buildSwipeLayout(recommendations);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const MascotImage(
                assetPath: AppConstants.mascotHappy,
                width: 96,
                height: 96,
              ),
              AppConstants.gap16,
              const Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingXl,
                ),
                child: Text(
                  'Noch keine Empfehlungen — sobald Belly Buddy deine Daten analysiert hat, siehst du sie hier.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: AppTheme.fontSizeBodyLG,
                    color: AppTheme.mutedForeground,
                  ),
                ),
              ),
              AppConstants.gap16,
              TextButton.icon(
                key: RecommendationsScreen.emptyStateRefreshKey,
                onPressed: () => ref
                    .read(recommendationProvider.notifier)
                    .fetchRecommendations(),
                icon: const Icon(Icons.refresh, size: AppConstants.iconSizeSm),
                label: const Text('Aktualisieren'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSwipeLayout(List<Recommendation> recommendations) {
    return _SwipeLayout(
      recommendations: recommendations,
      controller: _controller,
    );
  }
}

/// Separate widget so `ref.watch(recommendationIndexProvider)` rebuilds only
/// this subtree on page change — not the whole screen (AppBar + state.when).
class _SwipeLayout extends ConsumerWidget {
  const _SwipeLayout({required this.recommendations, required this.controller});

  final List<Recommendation> recommendations;
  final PageController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(recommendationIndexProvider);
    final isOldest = currentIndex == 0;
    final isLatest = currentIndex == recommendations.length - 1;
    const chevronSlotWidth = 44.0;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingMd,
            vertical: AppConstants.spacingSm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (isOldest)
                const SizedBox(width: chevronSlotWidth)
              else
                CircleIconButton(
                  tapKey: RecommendationsScreen.previousRecommendationKey,
                  icon: Icons.chevron_left,
                  onPressed: () {
                    HapticService.light();
                    ref
                        .read(recommendationIndexProvider.notifier)
                        .set(currentIndex - 1);
                  },
                ),
              Text(
                '${currentIndex + 1} von ${recommendations.length} Empfehlungen',
                style: const TextStyle(
                  fontSize: AppTheme.fontSizeBody,
                  color: AppTheme.mutedForeground,
                ),
              ),
              if (isLatest)
                const SizedBox(width: chevronSlotWidth)
              else
                CircleIconButton(
                  tapKey: RecommendationsScreen.nextRecommendationKey,
                  icon: Icons.chevron_right,
                  onPressed: () {
                    HapticService.light();
                    ref
                        .read(recommendationIndexProvider.notifier)
                        .set(currentIndex + 1);
                  },
                ),
            ],
          ),
        ),
        Expanded(
          child: PageView.builder(
            controller: controller,
            itemCount: recommendations.length,
            onPageChanged: (index) {
              HapticService.light();
              ref.read(recommendationIndexProvider.notifier).set(index);
            },
            itemBuilder: (context, pageIndex) {
              // pageIndex 0 = oldest; pageIndex length-1 = latest.
              // Our list from the provider is newest-first, so convert:
              final listIndex = (recommendations.length - 1) - pageIndex;
              return _RecommendationPage(
                recommendation: recommendations[listIndex],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RecommendationPage extends ConsumerWidget {
  const _RecommendationPage({required this.recommendation});

  final Recommendation recommendation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final createdAt = recommendation.createdAt;
    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: () =>
          ref.read(recommendationProvider.notifier).fetchRecommendations(),
      child: ListView(
        padding: AppConstants.paddingMd,
        children: [
          if (createdAt != null) ...[
            Text(
              formatDateWeekday(createdAt),
              style: const TextStyle(
                fontSize: AppTheme.fontSizeBody,
                fontWeight: FontWeight.w500,
                color: AppTheme.mutedForeground,
              ),
            ),
            AppConstants.gap12,
          ],
          RecommendationSummaryCard(recommendation: recommendation),
          AppConstants.gap20,
          const Text(
            'Empfehlungen',
            style: TextStyle(
              fontSize: AppTheme.fontSizeTitle,
              fontWeight: FontWeight.w600,
              color: AppTheme.foreground,
            ),
          ),
          AppConstants.gap12,
          ...recommendation.recommendations.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: AppConstants.spacing10),
              child: RecommendationCard(item: item),
            ),
          ),
          AppConstants.gap24,
        ],
      ),
    );
  }
}
