import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_theme.dart';
import '../../providers/recommendation_provider.dart';
import '../../widgets/common/bb_card.dart';

class RecommendationsScreen extends ConsumerStatefulWidget {
  const RecommendationsScreen({super.key});

  @override
  ConsumerState<RecommendationsScreen> createState() =>
      _RecommendationsScreenState();
}

class _RecommendationsScreenState
    extends ConsumerState<RecommendationsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(recommendationProvider.notifier).fetchRecommendations());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recommendationProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Empfehlungen')),
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: () =>
            ref.read(recommendationProvider.notifier).refreshRecommendations(),
        child: state.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
          error: (e, _) => Center(child: Text('Fehler: $e')),
          data: (recommendations) {
            if (recommendations.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Noch keine Empfehlungen. Tracke mehr Mahlzeiten, um personalisierte Tipps zu erhalten!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.mutedForeground, fontSize: 15),
                  ),
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: recommendations.length,
              itemBuilder: (context, index) {
                final rec = recommendations[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: BbCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (rec.summary != null)
                          Text(
                            rec.summary!,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.foreground,
                            ),
                          ),
                        if (rec.recommendations != null) ...[
                          const SizedBox(height: 8),
                          ...(rec.recommendations!).map((r) {
                            final text = r is Map ? r['text'] ?? r.toString() : r.toString();
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('• ', style: TextStyle(fontSize: 15)),
                                  Expanded(
                                    child: Text(
                                      text.toString(),
                                      style: const TextStyle(fontSize: 15),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
