import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../services/recipes/recipe_copy.dart';

/// A recipe's numbered steps; the indexes in [changed] are the ones the
/// Buddy rewrote, tinted and with a primary number.
class RecipeSteps extends StatelessWidget {
  const RecipeSteps({super.key, required this.steps, this.changed = const {}});

  final List<String> steps;
  final Set<int> changed;

  static Key stepKey(int i) => ValueKey('recipe_step_$i');
  static Key numberKey(int i) => ValueKey('recipe_step_number_$i');

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppConstants.spacingSm),
            child: MergeSemantics(
              child: Semantics(
                hint: changed.contains(i) ? RecipeCopy.stepChanged : null,
                child: DecoratedBox(
                  key: stepKey(i),
                  decoration: BoxDecoration(
                    color: changed.contains(i) ? AppTheme.recipeChanged : null,
                    borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppConstants.spacingSm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DecoratedBox(
                          key: numberKey(i),
                          decoration: BoxDecoration(
                            color: changed.contains(i)
                                ? AppTheme.primary
                                : AppTheme.muted,
                            shape: BoxShape.circle,
                          ),
                          child: SizedBox(
                            width: AppConstants.recipeMarkSize,
                            height: AppConstants.recipeMarkSize,
                            child: Center(
                              child: Text(
                                '${i + 1}',
                                style: const TextStyle(
                                  fontSize: AppTheme.fontSizeCaption,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.foreground,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppConstants.spacing10),
                        Expanded(
                          child: Text(
                            steps[i],
                            style: const TextStyle(
                              fontSize: AppTheme.fontSizeBody,
                              color: AppTheme.foreground,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
