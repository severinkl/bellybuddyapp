import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../models/dislike_category.dart';
import '../../../models/recommendation.dart';
import '../../../providers/recommendation_provider.dart';

/// Feedback component shown at the end of a recommendation page. Renders one
/// of three sub-views depending on the recommendation's [RecommendationState]:
///
/// - [RecommendationState.unrated]: heading + thumbs (up / down).
/// - [RecommendationState.liked]: filled thumb-up + "Danke!".
/// - [RecommendationState.disliked]: category chips + comment field +
///   "Diese Empfehlung ausblenden" button.
///
/// Hidden recommendations are filtered out upstream, so [RecommendationState
/// .hidden] collapses to an empty box.
class RecommendationFeedbackView extends ConsumerStatefulWidget {
  const RecommendationFeedbackView({super.key, required this.recommendation});

  final Recommendation recommendation;

  @override
  ConsumerState<RecommendationFeedbackView> createState() =>
      _RecommendationFeedbackViewState();
}

class _RecommendationFeedbackViewState
    extends ConsumerState<RecommendationFeedbackView> {
  late final TextEditingController _commentController;
  Timer? _commentDebounce;

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController(
      text: widget.recommendation.dislikeComment ?? '',
    );
  }

  @override
  void didUpdateWidget(covariant RecommendationFeedbackView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Resync the text controller when the underlying recommendation's comment
    // changes (e.g. if the server state arrived after an optimistic update).
    final serverComment = widget.recommendation.dislikeComment ?? '';
    if (serverComment != _commentController.text &&
        oldWidget.recommendation.dislikeComment !=
            widget.recommendation.dislikeComment) {
      _commentController.text = serverComment;
    }
  }

  @override
  void dispose() {
    _commentDebounce?.cancel();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _setState(
    RecommendationState target, {
    DislikeCategory? category,
    String? comment,
  }) async {
    try {
      await ref
          .read(recommendationProvider.notifier)
          .setRecommendationState(
            id: widget.recommendation.id,
            state: target,
            category: category,
            comment: comment,
          );
    } catch (_) {
      if (!mounted) return;
      _showSaveError();
    }
  }

  void _onCommentChanged(String value) {
    _commentDebounce?.cancel();
    _commentDebounce = Timer(AppConstants.debounceDuration, () async {
      if (!mounted) return;
      try {
        await ref
            .read(recommendationProvider.notifier)
            .setDislikeComment(
              id: widget.recommendation.id,
              comment: value.isEmpty ? null : value,
            );
      } catch (_) {
        if (!mounted) return;
        _showSaveError();
      }
    });
  }

  void _showSaveError() {
    // Hide any still-visible save-error snack before showing a new one so
    // rapid failures (e.g. offline + typing a comment) don't stack.
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(content: Text('Konnte nicht gespeichert werden.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.recommendation.state;
    return switch (state) {
      RecommendationState.unrated ||
      RecommendationState.liked => _buildRatedOrUnrated(state),
      RecommendationState.disliked => _buildDisliked(),
      RecommendationState.hidden => const SizedBox.shrink(),
    };
  }

  Widget _buildRatedOrUnrated(RecommendationState state) {
    final isLiked = state == RecommendationState.liked;
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
              color: AppTheme.foreground,
            ),
          ),
          AppConstants.gap8,
          Row(
            children: [
              IconButton(
                icon: Icon(isLiked ? Icons.thumb_up : Icons.thumb_up_outlined),
                color: isLiked ? AppTheme.primary : AppTheme.foreground,
                onPressed: () => _setState(RecommendationState.liked),
              ),
              IconButton(
                icon: const Icon(Icons.thumb_down_outlined),
                color: AppTheme.foreground,
                onPressed: () => _setState(RecommendationState.disliked),
              ),
              const Spacer(),
              if (isLiked)
                const Text(
                  'Danke!',
                  style: TextStyle(
                    fontSize: AppTheme.fontSizeBody,
                    color: AppTheme.mutedForeground,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDisliked() {
    final selectedCategory = DislikeCategory.fromDbValue(
      widget.recommendation.dislikeCategory,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Schade! Warum nicht?',
            style: TextStyle(
              fontSize: AppTheme.fontSizeBody,
              fontWeight: FontWeight.w600,
              color: AppTheme.foreground,
            ),
          ),
          AppConstants.gap8,
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.thumb_up_outlined),
                color: AppTheme.foreground,
                onPressed: () => _setState(RecommendationState.liked),
              ),
              IconButton(
                icon: const Icon(Icons.thumb_down),
                color: AppTheme.destructive,
                onPressed: () => _setState(RecommendationState.unrated),
              ),
            ],
          ),
          AppConstants.gap8,
          Wrap(
            spacing: AppConstants.spacingSm,
            runSpacing: AppConstants.spacingSm,
            children: [
              for (final c in DislikeCategory.values)
                ChoiceChip(
                  label: Text(c.label),
                  selected: selectedCategory == c,
                  onSelected: (_) => _setState(
                    RecommendationState.disliked,
                    category: c,
                    comment: _commentController.text.isEmpty
                        ? null
                        : _commentController.text,
                  ),
                ),
            ],
          ),
          AppConstants.gap12,
          TextField(
            controller: _commentController,
            onChanged: _onCommentChanged,
            maxLines: null,
            decoration: const InputDecoration(
              labelText: 'Noch etwas? (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          AppConstants.gap8,
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.destructive,
              ),
              onPressed: () => _setState(RecommendationState.hidden),
              child: const Text('Diese Empfehlung ausblenden'),
            ),
          ),
        ],
      ),
    );
  }
}
