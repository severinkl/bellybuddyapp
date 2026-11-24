import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../services/recipes/recipe_copy.dart';
import '../../../services/recipes/recipe_fit.dart';

/// One ingredient line: a mark (✓ / ⚠ / ?) for how it fits the user, the
/// amount, and the name with what the Buddy changed (a swap, a removal).
class IngredientLineView extends StatelessWidget {
  const IngredientLineView({
    super.key,
    this.amount,
    required this.name,
    this.mark,
    this.because = const [],
    this.replaces,
    this.removed = false,
    this.note,
  });

  final String? amount;
  final String name;

  /// Null shows no mark (an own recipe, or nothing judged).
  final LineMark? mark;

  /// The intolerances a kritisch line hits.
  final List<String> because;

  /// The ingredient this line replaces („getauscht").
  final String? replaces;

  /// The line was left out („weggelassen").
  final bool removed;

  /// A muted caption below the name.
  final String? note;

  static const _struck = TextStyle(decoration: TextDecoration.lineThrough);

  String get _semanticsLabel {
    final swapped = replaces;
    if (swapped != null) return RecipeCopy.swappedSemantics(swapped, name);
    final head = [?amount, name].join(' ');
    if (removed) return '$head, ${RecipeCopy.removedSemantics}';
    return switch (mark) {
      LineMark.kritisch =>
        '$head, ${RecipeCopy.kritischSemantics}, '
            '${RecipeCopy.because(because)}',
      LineMark.fits => '$head, ${RecipeCopy.fitsSemantics}',
      LineMark.unknown => '$head, ${RecipeCopy.notInCatalog}',
      null => head,
    };
  }

  @override
  Widget build(BuildContext context) {
    final swapped = replaces != null;
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (mark != null) ...[
          _Mark(mark!),
          const SizedBox(width: AppConstants.spacing10),
        ],
        SizedBox(
          width: AppConstants.recipeAmountWidth,
          child: Text(
            amount ?? '',
            style: const TextStyle(
              fontSize: AppTheme.fontSizeBody,
              color: AppTheme.mutedForeground,
            ),
          ),
        ),
        Expanded(child: _nameBlock()),
      ],
    );
    return Semantics(
      container: true,
      label: _semanticsLabel,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingXs),
          child: swapped
              ? DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppTheme.primarySoft,
                    borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppConstants.spacingXs),
                    child: row,
                  ),
                )
              : row,
        ),
      ),
    );
  }

  Widget _nameBlock() {
    const body = TextStyle(
      fontSize: AppTheme.fontSizeBody,
      color: AppTheme.foreground,
    );
    const caption = TextStyle(
      fontSize: AppTheme.fontSizeCaption,
      color: AppTheme.mutedForeground,
    );
    const bold = TextStyle(fontWeight: FontWeight.w700);
    final swappedFrom = replaces;

    final Widget title;
    if (swappedFrom != null) {
      title = Text.rich(
        TextSpan(
          style: body,
          children: [
            TextSpan(text: swappedFrom, style: _struck),
            const TextSpan(text: ' → '),
            TextSpan(text: name, style: bold),
            const TextSpan(text: ' ${RecipeCopy.swapped}', style: caption),
          ],
        ),
      );
    } else if (removed) {
      title = Text.rich(
        TextSpan(
          style: body,
          children: [
            TextSpan(text: name, style: _struck),
            const TextSpan(text: ' ${RecipeCopy.removed}', style: caption),
          ],
        ),
      );
    } else if (mark == LineMark.kritisch) {
      title = Text(
        '$name ${RecipeCopy.kritischSuffix}',
        style: body.copyWith(
          fontWeight: FontWeight.w700,
          color: AppTheme.gutFeelingNeutralIcon,
        ),
      );
    } else {
      title = Text(name, style: body);
    }

    final below = [
      if (mark == LineMark.kritisch && swappedFrom == null && !removed)
        RecipeCopy.because(because),
      if (mark == LineMark.unknown && swappedFrom == null && !removed)
        RecipeCopy.notInCatalog,
      ?note,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        title,
        for (final line in below) Text(line, style: caption),
      ],
    );
  }
}

class _Mark extends StatelessWidget {
  const _Mark(this.mark);

  final LineMark mark;

  @override
  Widget build(BuildContext context) {
    final (icon, color, fill, border) = switch (mark) {
      LineMark.fits => (
        Icons.check,
        AppTheme.gutFeelingGoodIcon,
        AppTheme.gutFeelingGoodSoft,
        null,
      ),
      LineMark.kritisch => (
        Icons.warning_amber_rounded,
        AppTheme.gutFeelingNeutralIcon,
        Colors.white,
        AppTheme.gutFeelingNeutral,
      ),
      LineMark.unknown => (
        Icons.help_outline,
        AppTheme.mutedForeground,
        null,
        null,
      ),
    };
    return Container(
      width: AppConstants.recipeMarkSize,
      height: AppConstants.recipeMarkSize,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: border == null
            ? null
            : Border.all(color: border, width: AppConstants.borderWidthMd),
      ),
      child: Icon(icon, size: AppConstants.iconSizeXs, color: color),
    );
  }
}
