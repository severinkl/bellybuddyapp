import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../models/recommendation.dart';
import '../../models/recommendation_item.dart';
import '../../providers/recommendation_provider.dart';
import '../../widgets/common/bb_card.dart';
import '../../widgets/common/mascot_image.dart';

class RecommendationsScreen extends ConsumerStatefulWidget {
  const RecommendationsScreen({super.key});

  @override
  ConsumerState<RecommendationsScreen> createState() =>
      _RecommendationsScreenState();
}

class _RecommendationsScreenState
    extends ConsumerState<RecommendationsScreen> {
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(recommendationProvider.notifier).fetchRecommendations());
  }

  Future<void> _generate() async {
    setState(() => _isGenerating = true);
    try {
      await ref.read(recommendationProvider.notifier).refreshRecommendations();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Neue Empfehlungen erstellt')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
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
            SizedBox(width: 8),
            Text('Empfehlungen'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _isGenerating ? null : _generate,
            icon: _isGenerating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.primary),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: _generate,
        child: state.when(
          loading: () => _buildLoadingState(),
          error: (e, _) => _buildErrorState(e),
          data: (recommendations) {
            if (recommendations.isEmpty) return _buildEmptyState();
            return _buildDataState(recommendations);
          },
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MascotImage(
            assetPath: AppConstants.mascotHappy,
            width: 96,
            height: 96,
          ),
          SizedBox(height: 16),
          Text(
            'Analysiere deine Daten...',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.mutedForeground,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const MascotImage(
                assetPath: AppConstants.mascotSad,
                width: 96,
                height: 96,
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Fehler beim Laden der Empfehlungen.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: AppTheme.mutedForeground,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _generate,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Erneut versuchen'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(200, 48),
                ),
              ),
            ],
          ),
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
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Noch keine Empfehlungen vorhanden.',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(fontSize: 15, color: AppTheme.mutedForeground),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _generate,
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text('Empfehlungen erstellen'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(220, 48),
                ),
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
      padding: const EdgeInsets.all(16),
      children: [
        // Summary card
        _RecommendationSummaryCard(recommendation: latest),
        const SizedBox(height: 20),

        // Section heading
        const Text(
          'Empfehlungen',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.foreground,
          ),
        ),
        const SizedBox(height: 12),

        // Recommendation cards
        ...latest.recommendations.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RecommendationCard(item: item),
            )),

        // History section
        if (history.isNotEmpty) ...[
          const SizedBox(height: 20),
          _RecommendationHistory(history: history),
        ],

        const SizedBox(height: 24),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Summary Card
// ---------------------------------------------------------------------------
class _RecommendationSummaryCard extends StatelessWidget {
  final Recommendation recommendation;

  const _RecommendationSummaryCard({required this.recommendation});

  @override
  Widget build(BuildContext context) {
    return BbCard(
      color: AppTheme.primary.withValues(alpha: 0.1),
      showBorder: false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MascotImage(
            assetPath: AppConstants.mascotProfessor,
            width: 80,
            height: 80,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (recommendation.summary != null)
                  Text(
                    recommendation.summary!,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.foreground,
                    ),
                  ),
                if (recommendation.createdAt != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Erstellt ${_formatTimeAgo(recommendation.createdAt!)}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDateRange(recommendation.createdAt!),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.mutedForeground,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'gerade eben';
    if (diff.inMinutes < 60) return 'vor ${diff.inMinutes} Min.';
    if (diff.inHours < 24) return 'vor ${diff.inHours} Std.';
    if (diff.inDays == 1) return 'vor 1 Tag';
    return 'vor ${diff.inDays} Tagen';
  }

  String _formatDateRange(DateTime createdAt) {
    final end = createdAt;
    final start = end.subtract(const Duration(days: 7));
    final df = DateFormat('d. MMM', 'de_DE');
    final yearFmt = DateFormat('yyyy');
    return 'Analysiert: ${df.format(start)} \u2013 ${df.format(end)} ${yearFmt.format(end)}';
  }
}

// ---------------------------------------------------------------------------
// Recommendation Card (typed: substitute / try)
// ---------------------------------------------------------------------------
class _RecommendationCard extends StatelessWidget {
  final RecommendationItem item;
  final bool compact;

  const _RecommendationCard({required this.item, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final isSubstitute = item.isSubstitute;
    final bgColor = isSubstitute
        ? AppTheme.warning.withValues(alpha: 0.1)
        : AppTheme.success.withValues(alpha: 0.1);
    final accentColor = isSubstitute ? AppTheme.warning : AppTheme.success;
    final icon = isSubstitute ? Icons.swap_horiz : Icons.eco;
    final label = isSubstitute ? 'Ersetzen' : 'Probieren';

    return BbCard(
      color: bgColor,
      showBorder: false,
      padding: EdgeInsets.all(compact ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: compact ? 18 : 20, color: accentColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.ingredient,
                  style: TextStyle(
                    fontSize: compact ? 14 : 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.foreground,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: accentColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 6 : 8),
          Text(
            item.reason,
            style: TextStyle(
              fontSize: compact ? 13 : 14,
              color: AppTheme.mutedForeground,
            ),
          ),
          if (item.alternative != null) ...[
            SizedBox(height: compact ? 4 : 6),
            Text(
              '\u2192 Alternative: ${item.alternative}',
              style: TextStyle(
                fontSize: compact ? 13 : 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.success,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// History Section (collapsible)
// ---------------------------------------------------------------------------
class _RecommendationHistory extends StatefulWidget {
  final List<Recommendation> history;

  const _RecommendationHistory({required this.history});

  @override
  State<_RecommendationHistory> createState() => _RecommendationHistoryState();
}

class _RecommendationHistoryState extends State<_RecommendationHistory> {
  bool _showHistory = false;
  String? _expandedId;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Toggle bar
        GestureDetector(
          onTap: () => setState(() => _showHistory = !_showHistory),
          child: BbCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.history, size: 20, color: AppTheme.mutedForeground),
                const SizedBox(width: 8),
                const Text(
                  'Verlauf',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.foreground,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.muted,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${widget.history.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.mutedForeground,
                    ),
                  ),
                ),
                const Spacer(),
                Icon(
                  _showHistory
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: AppTheme.mutedForeground,
                ),
              ],
            ),
          ),
        ),

        // History items
        if (_showHistory)
          ...widget.history.map((rec) => _buildHistoryItem(rec)),
      ],
    );
  }

  Widget _buildHistoryItem(Recommendation rec) {
    final isExpanded = _expandedId == rec.id;
    final dateFmt = DateFormat('d. MMM yyyy', 'de_DE');

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: BbCard(
        onTap: () => setState(() {
          _expandedId = isExpanded ? null : rec.id;
        }),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (rec.createdAt != null)
                  Text(
                    dateFmt.format(rec.createdAt!),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.mutedForeground,
                    ),
                  ),
                const Spacer(),
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 20,
                  color: AppTheme.mutedForeground,
                ),
              ],
            ),
            if (rec.summary != null) ...[
              const SizedBox(height: 4),
              Text(
                rec.summary!,
                maxLines: isExpanded ? null : 2,
                overflow: isExpanded ? null : TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, color: AppTheme.foreground),
              ),
            ],
            if (isExpanded && rec.recommendations.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...rec.recommendations.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _RecommendationCard(item: item, compact: true),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}
