import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../models/recommendation.dart';
import '../../providers/recommendation_provider.dart';
import '../../widgets/common/bb_async_state.dart';
import '../../widgets/common/mascot_image.dart';
import 'widgets/recommendation_card.dart';
import 'widgets/recommendation_history.dart';
import 'widgets/recommendation_summary_card.dart';

class RecommendationsScreen extends ConsumerStatefulWidget {
  const RecommendationsScreen({super.key});

  static const emptyStateRefreshKey = Key(
    'recommendations_empty_refresh_button',
  );

  @override
  ConsumerState<RecommendationsScreen> createState() =>
      _RecommendationsScreenState();
}

class _RecommendationsScreenState extends ConsumerState<RecommendationsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final notifier = ref.read(recommendationProvider.notifier);
      await notifier.fetchRecommendations();
      await notifier.markAllAsSeen();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recommendationProvider);

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
        loading: () => _buildLoadingState(),
        error: (e, _) => _buildErrorState(e),
        data: (recommendations) {
          if (recommendations.isEmpty) return _buildEmptyState();
          return _buildDataState(recommendations);
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return const BbLoadingState(message: 'Analysiere deine Daten...');
  }

  Widget _buildErrorState(Object error) {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        BbErrorState(
          message: 'Fehler beim Laden der Empfehlungen.',
          onRetry: () =>
              ref.read(recommendationProvider.notifier).fetchRecommendations(),
        ),
      ],
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

  Widget _buildDataState(List<Recommendation> recommendations) {
    final latest = recommendations.first;
    final history = recommendations.length > 1
        ? recommendations.sublist(1)
        : <Recommendation>[];

    return ListView(
      padding: AppConstants.paddingMd,
      children: [
        RecommendationSummaryCard(recommendation: latest),
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

        ...latest.recommendations.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: AppConstants.spacing10),
            child: RecommendationCard(item: item),
          ),
        ),

        if (history.isNotEmpty) ...[
          AppConstants.gap20,
          RecommendationHistory(history: history),
        ],

        AppConstants.gap24,
      ],
    );
  }
}
