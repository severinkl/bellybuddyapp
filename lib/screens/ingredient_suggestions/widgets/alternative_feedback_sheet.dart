import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../models/alternative_choice.dart';
import '../../../models/ingredient_suggestion_group.dart';
import '../../../models/replacement_ingredient.dart';
import '../../../providers/alternative_choices_provider.dart';
import '../../../services/daily_review/daily_review_copy.dart';
import '../../../widgets/common/bb_drag_handle.dart';

/// The words of a verdict on an alternative, one wording across the app.
abstract final class AlternativeVerdictCopy {
  static const fits = 'Passt für mich';
  static const tryIt = DailyReviewCopy.tryIt;
  static const skip = DailyReviewCopy.skip;
  static const reset = 'Zurücksetzen';

  /// The app's text for a write that did not get through.
  static const failed = 'Konnte nicht gespeichert werden.';

  static String of(AlternativeChoiceKind kind) => switch (kind) {
    AlternativeChoiceKind.fits => fits,
    AlternativeChoiceKind.tryIt => tryIt,
    AlternativeChoiceKind.skip => skip,
  };
}

/// Opens the verdict sheet for [replacement] in [group] (spec §6.2). It
/// closes on a choice; the choice shows at once and is undone with
/// [AlternativeVerdictCopy.failed] when it cannot be stored.
Future<void> showAlternativeFeedbackSheet(
  BuildContext context, {
  required IngredientSuggestionGroup group,
  required ReplacementIngredient replacement,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: AppTheme.background,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(
      top: Radius.circular(AppConstants.radiusXl),
    ),
  ),
  builder: (_) =>
      AlternativeFeedbackSheet(group: group, replacement: replacement),
);

/// [replacement]'s name and „Passt für mich", „Probiere ich", „Passt nicht
/// für mich"; „Zurücksetzen" once a verdict is set. The current verdict is
/// marked (and read as selected).
class AlternativeFeedbackSheet extends ConsumerWidget {
  const AlternativeFeedbackSheet({
    super.key,
    required this.group,
    required this.replacement,
  });

  final IngredientSuggestionGroup group;
  final ReplacementIngredient replacement;

  static const fitsKey = Key('alternative_feedback_fits');
  static const tryKey = Key('alternative_feedback_try');
  static const skipKey = Key('alternative_feedback_skip');
  static const resetKey = Key('alternative_feedback_reset');

  /// Closes the sheet, then runs [write]; false from it: the snackbar.
  Future<void> _write(
    BuildContext context,
    Future<bool> Function() write,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    if (!await write()) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text(AlternativeVerdictCopy.failed)),
        );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final choice = ref.watch(
      alternativeChoiceForPairProvider((group.ingredientId, replacement.id)),
    );
    final notifier = ref.read(alternativeChoicesProvider.notifier);

    Widget verdict(Key key, AlternativeChoiceKind kind) {
      final selected = choice?.kind == kind;
      final label = Text(AlternativeVerdictCopy.of(kind));
      void onPressed() => selected
          ? Navigator.of(context).pop()
          : _write(
              context,
              () => notifier.choose(
                ingredientId: group.ingredientId,
                ingredientName: group.ingredientName,
                replacement: replacement,
                kind: kind,
              ),
            );
      return Padding(
        padding: const EdgeInsets.only(bottom: AppConstants.spacingSm),
        child: Semantics(
          selected: selected,
          child: selected
              ? ElevatedButton.icon(
                  key: key,
                  onPressed: onPressed,
                  icon: const Icon(Icons.check),
                  label: label,
                )
              : OutlinedButton(key: key, onPressed: onPressed, child: label),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppConstants.spacingMd,
            AppConstants.spacingSm,
            AppConstants.spacingMd,
            AppConstants.spacingMd,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const BbDragHandle(color: AppTheme.border),
              AppConstants.gap12,
              Semantics(
                header: true,
                child: Text(
                  replacement.name,
                  style: const TextStyle(
                    fontSize: AppTheme.fontSizeTitle,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.foreground,
                  ),
                ),
              ),
              AppConstants.gap4,
              Text(
                'statt ${group.ingredientName}',
                style: const TextStyle(
                  fontSize: AppTheme.fontSizeBody,
                  color: AppTheme.mutedForeground,
                ),
              ),
              AppConstants.gap16,
              verdict(fitsKey, AlternativeChoiceKind.fits),
              verdict(tryKey, AlternativeChoiceKind.tryIt),
              verdict(skipKey, AlternativeChoiceKind.skip),
              if (choice != null)
                TextButton(
                  key: resetKey,
                  onPressed: () =>
                      _write(context, () => notifier.remove(choice.id)),
                  child: const Text(AlternativeVerdictCopy.reset),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
