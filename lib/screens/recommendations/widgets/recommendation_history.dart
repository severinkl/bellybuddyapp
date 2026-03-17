import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../config/app_theme.dart';
import '../../../models/recommendation.dart';
import '../../../widgets/common/bb_card.dart';
import '../../../config/constants.dart';
import 'recommendation_card.dart';

class RecommendationHistory extends StatefulWidget {
  final List<Recommendation> history;

  const RecommendationHistory({super.key, required this.history});

  @override
  State<RecommendationHistory> createState() => _RecommendationHistoryState();
}

class _RecommendationHistoryState extends State<RecommendationHistory> {
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
                const Icon(
                  Icons.history,
                  size: 20,
                  color: AppTheme.mutedForeground,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Verlauf',
                  style: TextStyle(
                    fontSize: AppTheme.fontSizeBodyLG,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.foreground,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.muted,
                    borderRadius: BorderRadius.circular(
                      AppConstants.radiusIcon,
                    ),
                  ),
                  child: Text(
                    '${widget.history.length}',
                    style: const TextStyle(
                      fontSize: AppTheme.fontSizeCaption,
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
                      fontSize: AppTheme.fontSizeCaptionLG,
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
              AppConstants.gap4,
              Text(
                rec.summary!,
                maxLines: isExpanded ? null : 2,
                overflow: isExpanded ? null : TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: AppTheme.fontSizeBody,
                  color: AppTheme.foreground,
                ),
              ),
            ],
            if (isExpanded && rec.recommendations.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...rec.recommendations.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: RecommendationCard(item: item, compact: true),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
