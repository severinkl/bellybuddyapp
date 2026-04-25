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
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _controller.text.isNotEmpty;
    return TextField(
      controller: _controller,
      decoration: InputDecoration(
        hintText: 'Rezept suchen…',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: hasText
            ? IconButton(icon: const Icon(Icons.clear), onPressed: _clear)
            : null,
        filled: true,
        fillColor: AppTheme.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusRound),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusRound),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusRound),
          borderSide: BorderSide.none,
        ),
        isDense: true,
      ),
      onChanged: (value) {
        ref.read(userRecipesProvider.notifier).setQuery(value);
        setState(() {}); // rebuild to show/hide the clear icon
      },
    );
  }
}
