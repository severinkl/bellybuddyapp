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
  static Key fieldKey(int i) => ValueKey('steps_field_$i');
  static Key removeKey(int i) => ValueKey('steps_remove_$i');

  @override
  State<RecipeStepsEditor> createState() => _RecipeStepsEditorState();
}

class _RecipeStepsEditorState extends State<RecipeStepsEditor> {
  late final List<TextEditingController> _controllers = [
    for (final text in widget.initial) TextEditingController(text: text),
  ];

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _emit() => widget.onChanged([for (final c in _controllers) c.text]);

  void _add() {
    setState(() => _controllers.add(TextEditingController()));
    _emit();
  }

  void _remove(int i) {
    final removed = _controllers.removeAt(i);
    setState(() {});
    _emit();
    // The field is still in this frame's tree; dispose after it.
    WidgetsBinding.instance.addPostFrameCallback((_) => removed.dispose());
  }

  @override
  Widget build(BuildContext context) {
    final full = _controllers.length >= AppConstants.recipeStepsMax;
    return RecipeSectionCard(
      title: 'Zubereitung',
      trailing: const Text('optional', style: AppTheme.captionMutedStyle),
      children: [
        for (var i = 0; i < _controllers.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppConstants.spacingSm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    top: AppConstants.spacing12,
                    right: AppConstants.spacing10,
                  ),
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      fontSize: AppTheme.fontSizeBody,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.mutedForeground,
                    ),
                  ),
                ),
                Expanded(
                  child: TextField(
                    key: RecipeStepsEditor.fieldKey(i),
                    controller: _controllers[i],
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
                IconButton(
                  key: RecipeStepsEditor.removeKey(i),
                  icon: const Icon(Icons.close),
                  tooltip: 'Schritt entfernen',
                  onPressed: () => _remove(i),
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
