import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../providers/recipe_search_provider.dart';
import '../../../widgets/common/bb_labeled_field.dart';

/// The search of the [host] it sits on ([recipeSearchProvider]), kept
/// alive while the field shows.
class RecipesSearchField extends ConsumerStatefulWidget {
  const RecipesSearchField({super.key, required this.host});

  final RecipeSearchHost host;

  @override
  ConsumerState<RecipesSearchField> createState() => _RecipesSearchFieldState();
}

class _RecipesSearchFieldState extends ConsumerState<RecipesSearchField> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    final initial = ref
        .read(recipeSearchProvider(widget.host).notifier)
        .activeQuery;
    if (initial != null) _controller.text = initial;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    ref.read(recipeSearchProvider(widget.host).notifier).setQuery(null);
  }

  @override
  Widget build(BuildContext context) {
    final search = ref.watch(recipeSearchProvider(widget.host).notifier);
    final pillBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppConstants.radiusRound),
      borderSide: BorderSide.none,
    );
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _controller,
      builder: (context, value, _) {
        return BbLabeledField(
          label: 'Rezept suchen',
          child: TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: 'z. B. Porridge',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: value.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: 'Suche löschen',
                      onPressed: _clear,
                    ),
              filled: true,
              fillColor: AppTheme.card,
              border: pillBorder,
              enabledBorder: pillBorder,
              focusedBorder: pillBorder,
              isDense: true,
            ),
            onChanged: search.setQuery,
          ),
        );
      },
    );
  }
}
