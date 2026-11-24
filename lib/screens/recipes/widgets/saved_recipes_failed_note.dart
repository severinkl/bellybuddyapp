import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../services/recipes/recipe_copy.dart';

/// „Meine Rezepte"'s quiet line when the saved recipes couldn't be loaded
/// (e.g. offline), with its retry. The own recipes and „Erstes Rezept
/// erstellen" stay above it.
class SavedRecipesFailedNote extends StatelessWidget {
  const SavedRecipesFailedNote({
    super.key,
    required this.onRetry,
    this.centered = false,
  });

  final VoidCallback onRetry;

  /// Centred, as under the empty state; else at the start.
  final bool centered;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: centered ? WrapAlignment.center : WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          RecipeCopy.savedFailed,
          textAlign: centered ? TextAlign.center : TextAlign.start,
          style: AppTheme.captionMutedStyle,
        ),
        TextButton(onPressed: onRetry, child: const Text(RecipeCopy.retry)),
      ],
    );
  }
}
