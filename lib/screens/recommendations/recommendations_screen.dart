import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../models/recommendation.dart';
import '../../providers/recommendation_index_provider.dart';
import '../../providers/recommendation_provider.dart';
import '../../services/haptic_service.dart';
import '../../utils/date_format_utils.dart';
import '../../utils/page_controller_utils.dart';
import '../../widgets/common/bb_async_state.dart';
import '../../widgets/common/circle_icon_button.dart';
import '../../widgets/common/mascot_image.dart';
import 'widgets/recommendation_card.dart';
import 'widgets/recommendation_feedback_view.dart';
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
  /// Eagerly constructed in initState (before the PageView mounts) so the
  /// scroll position attaches cleanly on first layout. Creating a
  /// `PageController` during the parent's build and handing it to a
  /// same-build PageView leaves the scroll position in a transitional
  /// state that blocks gesture input until a programmatic page change
  /// forces a re-settle — which presents as "swipe doesn't work until I
  /// tap a chevron once" at cold start.
  late final PageController _controller;

  /// The id of the latest recommendation the controller is currently anchored
  /// to. When a refresh brings a new latest in at index 0, this changes and
  /// we decide whether to re-anchor (see [_maybeAnchor]).
  String? _anchoredLatestId;

  /// The list length at the time of the last anchor. Used to detect whether
  /// the user was sitting on the previous latest when a new one arrives.
  int? _anchoredLength;

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

  /// On first data-resolve, jump the controller to the latest and seed the
  /// notifier. On refresh with a new latest, only jump if the user was
  /// sitting on the previous latest — otherwise leave them on the page
  /// they were reading (the `listIndex = (length-1) - pageIndex` mapping
  /// means the page they're looking at now shows the same recommendation,
  /// just shifted one slot deeper into the list).
  void _maybeAnchor(List<Recommendation> list) {
    if (list.isEmpty) return;
    final latestId = list.first.id;
    if (latestId == _anchoredLatestId) return;

    final isFirstAnchor = _anchoredLatestId == null;
    final previousLength = _anchoredLength;
    final targetPage = list.length - 1;

    _anchoredLatestId = latestId;
    _anchoredLength = list.length;

    final shouldJump =
        isFirstAnchor ||
        (_controller.hasClients &&
            (_controller.page ?? _controller.initialPage.toDouble()).round() ==
                (previousLength ?? 0) - 1);
    if (!shouldJump) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_controller.hasClients) {
        // `animateToPage` (not `jumpToPage`) — jumpToPage leaves the
        // PageView's scroll physics in a half-initialised state at cold
        // start, where gesture input is not routed until a subsequent
        // animateToPage call forces a re-settle. Symptom: swipe does
        // nothing until the user taps a chevron once. Keep the duration
        // short so the settle is imperceptible but real.
        _controller.animateToPage(
          targetPage,
          duration: const Duration(milliseconds: 50),
          curve: Curves.easeOut,
        );
        // animateToPage fires onPageChanged → notifier gets written.
      } else {
        // Controller didn't attach in time (unusual). Seed directly.
        ref.read(recommendationIndexProvider.notifier).set(targetPage);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recommendationProvider);

    ref.listen<int>(recommendationIndexProvider, (_, next) {
      animatePageControllerTo(
        _controller,
        next,
        duration: AppConstants.animNormal,
      );
    });

    return Scaffold(
      appBar: AppBar(
        leading: const _DashboardBackButton(),
        leadingWidth: 128,
        title: const _RecommendationsTitle(),
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
          return _SwipeLayout(
            recommendations: recommendations,
            controller: _controller,
          );
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
}

/// AppBar title — watches both providers so the position updates as the
/// user swipes. Kept as its own ConsumerWidget so page changes rebuild just
/// the title, not the whole outer Scaffold.
class _RecommendationsTitle extends ConsumerWidget {
  const _RecommendationsTitle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = ref
        .watch(recommendationProvider)
        .maybeWhen(data: (recs) => recs.length, orElse: () => 0);
    final rawIndex = ref.watch(recommendationIndexProvider);
    // Clamp against the current list length: when the user hides the
    // currently-viewed recommendation, the list shrinks below the raw
    // index for a frame before the post-frame animateToPage + onPageChanged
    // cycle brings the notifier back in range. Without this clamp the
    // header briefly renders "3 von 2" or similar.
    final displayIndex = total == 0 ? 0 : rawIndex.clamp(0, total - 1);

    final text = total > 0
        ? 'Empfehlungen (${displayIndex + 1} von $total)'
        : 'Empfehlungen';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.auto_awesome, size: 20),
        const SizedBox(width: AppConstants.spacingSm),
        Flexible(child: Text(text, overflow: TextOverflow.ellipsis)),
      ],
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
    final rawIndex = ref.watch(recommendationIndexProvider);
    // Clamp against the list: if the user just hid the currently-viewed
    // recommendation, the list shrunk and the notifier's raw value may
    // point past the new end. See `_RecommendationsTitle` for the rationale.
    final currentIndex = rawIndex.clamp(0, recommendations.length - 1);
    final isOldest = currentIndex == 0;
    final isLatest = currentIndex == recommendations.length - 1;
    // pageIndex 0 = oldest; pageIndex length-1 = latest. Convert to the
    // newest-first list index the provider returns.
    final listIndex = (recommendations.length - 1) - currentIndex;
    final safeIndex = listIndex.clamp(0, recommendations.length - 1);
    final createdAt = recommendations[safeIndex].createdAt;

    // If the raw notifier value was out of bounds, schedule a write-back so
    // the controller's ref.listen animates the PageView to a valid page on
    // the next frame. Avoids a stuck "controller at page N but list only
    // has N items" after a hide. Idempotent: the next rebuild sees
    // rawIndex == currentIndex and skips scheduling a second callback.
    if (rawIndex != currentIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ref.read(recommendationIndexProvider.notifier).set(currentIndex);
      });
    }

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
                const SizedBox(width: AppConstants.iconBadgeMd)
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
              if (createdAt != null)
                Flexible(
                  child: Text(
                    formatDateWeekday(createdAt),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: AppTheme.fontSizeBody,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.foreground,
                    ),
                  ),
                ),
              if (isLatest)
                const SizedBox(width: AppConstants.iconBadgeMd)
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

class _DashboardBackButton extends StatelessWidget {
  const _DashboardBackButton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AppConstants.spacingXs),
      child: TextButton.icon(
        onPressed: () => context.pop(),
        style: TextButton.styleFrom(
          foregroundColor: AppTheme.foreground,
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingSm,
          ),
        ),
        icon: const Icon(
          Icons.arrow_back_ios_new,
          size: AppConstants.iconSizeSm,
        ),
        label: const Text(
          'Dashboard',
          style: TextStyle(
            fontSize: AppTheme.fontSizeBody,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _RecommendationPage extends ConsumerWidget {
  const _RecommendationPage({required this.recommendation});

  final Recommendation recommendation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: () =>
          ref.read(recommendationProvider.notifier).fetchRecommendations(),
      child: ListView(
        padding: AppConstants.paddingMd,
        children: [
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
          AppConstants.gap16,
          RecommendationFeedbackView(recommendation: recommendation),
          AppConstants.gap24,
        ],
      ),
    );
  }
}
