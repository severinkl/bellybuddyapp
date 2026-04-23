import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../models/recommendation.dart';
import '../../../providers/recommendation_provider.dart';
import 'recommendation_dislike_sheet.dart';

/// Feedback row shown at the bottom of a single recommendation page. Two
/// segmented pills ("Hilfreich" / "Nicht hilfreich"); tapping the latter
/// opens the [RecommendationDislikeSheet] for the category + comment flow.
/// Hidden state is unreachable here (hidden recommendations are filtered
/// upstream in the repository).
class RecommendationFeedbackView extends ConsumerWidget {
  const RecommendationFeedbackView({super.key, required this.recommendation});

  final Recommendation recommendation;

  Future<void> _setLiked(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(recommendationProvider.notifier)
          .setRecommendationState(
            id: recommendation.id,
            state: RecommendationState.liked,
          );
    } catch (_) {
      if (!context.mounted) return;
      _showSaveError(context);
    }
  }

  Future<void> _setDislikedAndOpenSheet(
    BuildContext context,
    WidgetRef ref,
  ) async {
    if (recommendation.state != RecommendationState.disliked) {
      try {
        await ref
            .read(recommendationProvider.notifier)
            .setRecommendationState(
              id: recommendation.id,
              state: RecommendationState.disliked,
              // Clear category on (re)entry — the user is about to pick one
              // in the sheet. Keep any prior comment so the sheet's TextField
              // shows what they wrote last time.
              category: null,
              comment: recommendation.dislikeComment,
            );
      } catch (_) {
        if (!context.mounted) return;
        _showSaveError(context);
        return;
      }
    }
    if (!context.mounted) return;
    await showRecommendationDislikeSheet(context, recommendation);
  }

  void _showSaveError(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(content: Text('Konnte nicht gespeichert werden.')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = recommendation.state;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'War diese Empfehlung hilfreich?',
            style: TextStyle(
              fontSize: AppTheme.fontSizeBody,
              fontWeight: FontWeight.w600,
              color: AppTheme.mutedForeground,
            ),
          ),
          AppConstants.gap8,
          Row(
            children: [
              Expanded(
                child: _FeedbackPill(
                  icon: '👍',
                  label: 'Hilfreich',
                  selected: state == RecommendationState.liked,
                  selectedColor: AppTheme.primary,
                  onTap: () => _setLiked(context, ref),
                ),
              ),
              const SizedBox(width: AppConstants.spacingSm),
              Expanded(
                child: _FeedbackPill(
                  icon: '👎',
                  label: 'Nicht hilfreich',
                  selected: state == RecommendationState.disliked,
                  selectedColor: AppTheme.destructive,
                  onTap: () => _setDislikedAndOpenSheet(context, ref),
                ),
              ),
            ],
          ),
          if (state == RecommendationState.liked) ...[
            AppConstants.gap8,
            const Text(
              '✓ Danke für dein Feedback',
              style: TextStyle(
                fontSize: AppTheme.fontSizeCaptionLG,
                color: AppTheme.primary,
              ),
            ),
          ] else if (state == RecommendationState.disliked) ...[
            AppConstants.gap8,
            Row(
              children: [
                const Text(
                  '✓ Wird berücksichtigt',
                  style: TextStyle(
                    fontSize: AppTheme.fontSizeCaptionLG,
                    color: AppTheme.destructive,
                  ),
                ),
                const SizedBox(width: AppConstants.spacingSm),
                TextButton(
                  onPressed: () =>
                      showRecommendationDislikeSheet(context, recommendation),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: AppTheme.foreground,
                  ),
                  child: const Text(
                    'Bearbeiten',
                    style: TextStyle(
                      fontSize: AppTheme.fontSizeCaptionLG,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _FeedbackPill extends StatelessWidget {
  const _FeedbackPill({
    required this.icon,
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  final String icon;
  final String label;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppConstants.radiusPill),
      child: AnimatedContainer(
        duration: AppConstants.animFast,
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: AppConstants.spacing12),
        decoration: BoxDecoration(
          color: selected ? selectedColor : AppTheme.card,
          border: Border.all(
            color: selected ? selectedColor : AppTheme.border,
            width: AppConstants.borderWidthMd,
          ),
          borderRadius: BorderRadius.circular(AppConstants.radiusPill),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              icon,
              style: const TextStyle(fontSize: AppTheme.fontSizeSubtitle),
            ),
            const SizedBox(width: AppConstants.spacingSm),
            Text(
              label,
              style: TextStyle(
                fontSize: AppTheme.fontSizeBody,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppTheme.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
