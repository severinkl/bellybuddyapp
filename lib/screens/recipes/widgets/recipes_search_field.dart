import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../providers/user_recipes_provider.dart';

class RecipesSearchField extends ConsumerStatefulWidget {
  const RecipesSearchField({super.key});

  @override
  ConsumerState<RecipesSearchField> createState() => _RecipesSearchFieldState();
}

class _RecipesSearchFieldState extends ConsumerState<RecipesSearchField> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    final initial = ref.read(userRecipesProvider.notifier).activeQuery;
    if (initial != null) _controller.text = initial;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    ref.read(userRecipesProvider.notifier).setQuery(null);
  }

  @override
  Widget build(BuildContext context) {
    final pillBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppConstants.radiusRound),
      borderSide: BorderSide.none,
    );
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _controller,
      builder: (context, value, _) {
        return TextField(
          controller: _controller,
          decoration: InputDecoration(
            hintText: 'Rezept suchen…',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(icon: const Icon(Icons.clear), onPressed: _clear),
            filled: true,
            fillColor: AppTheme.card,
            border: pillBorder,
            enabledBorder: pillBorder,
            focusedBorder: pillBorder,
            isDense: true,
          ),
          onChanged: (value) =>
              ref.read(userRecipesProvider.notifier).setQuery(value),
        );
      },
    );
  }
}
