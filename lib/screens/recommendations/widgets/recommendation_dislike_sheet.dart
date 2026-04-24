import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../models/recommendation.dart';
import '../../../providers/recommendation_provider.dart';

/// Opens the "Warum nicht hilfreich?" bottom sheet for the given
/// recommendation. Callers do not await the returned Future unless they
/// want to know when the user dismisses the sheet — all data is persisted
/// before the sheet closes.
Future<void> showRecommendationDislikeSheet(
  BuildContext context,
  Recommendation recommendation,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    backgroundColor: AppTheme.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppConstants.radiusXl),
      ),
    ),
    builder: (_) => RecommendationDislikeSheet(recommendation: recommendation),
  );
}

class RecommendationDislikeSheet extends ConsumerStatefulWidget {
  const RecommendationDislikeSheet({super.key, required this.recommendation});

  final Recommendation recommendation;

  @override
  ConsumerState<RecommendationDislikeSheet> createState() =>
      _RecommendationDislikeSheetState();
}

class _RecommendationDislikeSheetState
    extends ConsumerState<RecommendationDislikeSheet> {
  late final TextEditingController _commentController;
  // Cached so dispose() can flush without touching ref — which some Riverpod
  // versions assert against after the widget is unmounted.
  late final RecommendationNotifier _notifier;
  Timer? _commentDebounce;

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController(
      text: widget.recommendation.dislikeComment ?? '',
    );
    _notifier = ref.read(recommendationProvider.notifier);
  }

  @override
  void dispose() {
    // If the user dismisses the sheet mid-debounce (fast Fertig-tap,
    // swipe-down), flush the pending comment fire-and-forget so ~800ms of
    // typing isn't silently discarded. We can't show a SnackBar post-dispose;
    // transient errors surface on the next read of the provider state.
    final hadPendingWrite = _commentDebounce?.isActive ?? false;
    _commentDebounce?.cancel();
    if (hadPendingWrite) {
      final value = _commentController.text;
      final id = widget.recommendation.id;
      // Defer into a microtask so the notifier's synchronous `state = …`
      // doesn't fire while we're still inside the widget's dispose pass —
      // Riverpod asserts against modifying a provider during build/dispose.
      unawaited(
        Future.microtask(
          () => _notifier.setDislikeComment(
            id: id,
            comment: value.isEmpty ? null : value,
          ),
        ),
      );
    }
    _commentController.dispose();
    super.dispose();
  }

  void _showSaveError() {
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(content: Text('Konnte nicht gespeichert werden.')),
    );
  }

  void _onCommentChanged(String value) {
    _commentDebounce?.cancel();
    _commentDebounce = Timer(AppConstants.debounceDuration, () async {
      if (!mounted) return;
      try {
        await _notifier.setDislikeComment(
          id: widget.recommendation.id,
          comment: value.isEmpty ? null : value,
        );
      } catch (_) {
        if (!mounted) return;
        _showSaveError();
      }
    });
  }

  Future<void> _hide() async {
    try {
      await _notifier.setRecommendationState(
        id: widget.recommendation.id,
        state: RecommendationState.hidden,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      _showSaveError();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppConstants.spacingMd,
          AppConstants.spacingSm,
          AppConstants.spacingMd,
          MediaQuery.viewInsetsOf(context).bottom + AppConstants.spacingMd,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: AppConstants.dragHandleWidth,
                height: AppConstants.dragHandleHeight,
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(
                    AppConstants.dragHandleRadius,
                  ),
                ),
              ),
            ),
            AppConstants.gap12,
            const Text(
              'Was hat dir nicht gefallen?',
              style: TextStyle(
                fontSize: AppTheme.fontSizeSubtitle,
                fontWeight: FontWeight.w600,
                color: AppTheme.foreground,
              ),
            ),
            AppConstants.gap4,
            const Text(
              'Deine Antwort hilft uns, bessere Tipps zu finden.',
              style: TextStyle(
                fontSize: AppTheme.fontSizeBody,
                color: AppTheme.mutedForeground,
              ),
            ),
            AppConstants.gap12,
            TextField(
              controller: _commentController,
              onChanged: _onCommentChanged,
              minLines: 2,
              maxLines: null,
              maxLength: AppConstants.dislikeCommentMaxLength,
              decoration: const InputDecoration(
                labelText: 'Erzähl uns warum ... (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            AppConstants.gap16,
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _hide,
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.destructive,
                  ),
                  child: const Text('Empfehlung ausblenden'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.foreground,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusMd,
                      ),
                    ),
                  ),
                  child: const Text('Fertig'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
