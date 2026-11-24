import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import 'recipe_page_parts.dart';

/// „Zubereitung" of the recipe editor: one multi-line field per step, a
/// remove button each and „Schritt hinzufügen". [onChanged] gets the raw
/// texts in order.
class RecipeStepsEditor extends StatefulWidget {
  const RecipeStepsEditor({
    super.key,
    required this.initial,
    required this.onChanged,
  });

  final List<String> initial;
  final ValueChanged<List<String>> onChanged;

  static const addKey = Key('steps_add');

  /// The field and the remove button of the step made [id]-th (the initial
  /// steps first, in order): a step keeps its id when one before it goes.
  static Key fieldKey(int id) => ValueKey('steps_field_$id');
  static Key removeKey(int id) => ValueKey('steps_remove_$id');

  @override
  State<RecipeStepsEditor> createState() => _RecipeStepsEditorState();
}

/// A step's field and its id ([RecipeStepsEditor.fieldKey]).
class _Step {
  _Step(this.id, [String text = ''])
    : controller = TextEditingController(text: text);

  final int id;
  final TextEditingController controller;
}

class _RecipeStepsEditorState extends State<RecipeStepsEditor> {
  late final List<_Step> _steps = [
    for (final (i, text) in widget.initial.indexed) _Step(i, text),
  ];
  late int _nextId = _steps.length;

  @override
  void dispose() {
    for (final s in _steps) {
      s.controller.dispose();
    }
    super.dispose();
  }

  void _emit() => widget.onChanged([for (final s in _steps) s.controller.text]);

  void _add() {
    setState(() => _steps.add(_Step(_nextId++)));
    _emit();
  }

  void _remove(_Step step) {
    setState(() => _steps.remove(step));
    _emit();
    // The field is still in this frame's tree; dispose after it.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => step.controller.dispose(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final full = _steps.length >= AppConstants.recipeStepsMax;
    return RecipeSectionCard(
      title: 'Zubereitung',
      trailing: const Text('optional', style: AppTheme.captionMutedStyle),
      children: [
        for (final (i, step) in _steps.indexed)
          Padding(
            // By the step, not its place: removing one before it keeps its
            // field (focus, cursor) with it.
            key: ObjectKey(step.controller),
            padding: const EdgeInsets.only(bottom: AppConstants.spacingSm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    top: AppConstants.spacing12,
                    right: AppConstants.spacing10,
                  ),
                  // Said with its field instead („Schritt 2").
                  child: ExcludeSemantics(
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        fontSize: AppTheme.fontSizeBody,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.mutedForeground,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Semantics(
                    label: 'Schritt ${i + 1}',
                    child: TextField(
                      key: RecipeStepsEditor.fieldKey(step.id),
                      controller: step.controller,
                      minLines: 1,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (_) => _emit(),
                      decoration: const InputDecoration(
                        hintText: 'Schritt beschreiben',
                      ),
                    ),
                  ),
                ),
                IconButton(
                  key: RecipeStepsEditor.removeKey(step.id),
                  icon: const Icon(Icons.close),
                  tooltip: 'Schritt entfernen',
                  onPressed: () => _remove(step),
                ),
              ],
            ),
          ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            key: RecipeStepsEditor.addKey,
            onPressed: full ? null : _add,
            icon: const Icon(Icons.add),
            label: const Text('Schritt hinzufügen'),
          ),
        ),
      ],
    );
  }
}
