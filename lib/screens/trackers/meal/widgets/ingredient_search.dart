import 'package:flutter/material.dart';
import '../../../../config/app_theme.dart';
import '../../../../services/ingredient_service.dart';
import '../../../../config/constants.dart';

class IngredientSearch extends StatefulWidget {
  final List<String> ingredients;
  final List<IngredientSuggestion> suggestions;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;
  final ValueChanged<String> onDeleteIngredient;

  const IngredientSearch({
    super.key,
    required this.ingredients,
    required this.suggestions,
    required this.onSearch,
    required this.onAdd,
    required this.onRemove,
    required this.onDeleteIngredient,
  });

  @override
  State<IngredientSearch> createState() => _IngredientSearchState();
}

class _IngredientSearchState extends State<IngredientSearch> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _isAdding = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submitIngredient() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    widget.onAdd(value);
    _controller.clear();
    widget.onSearch('');
    setState(() => _isAdding = false);
  }

  @override
  Widget build(BuildContext context) {
    // Filter out already-added ingredients
    final filteredSuggestions = widget.suggestions
        .where((s) => !widget.ingredients.contains(s.name))
        .toList();

    return Container(
      padding: AppConstants.paddingMd,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row: "Zutaten" + hinzufügen button or inline search field
          Row(
            children: [
              const Text(
                'Zutaten',
                style: TextStyle(
                  fontSize: AppTheme.fontSizeSubtitle,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 12),
              if (_isAdding)
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    style: const TextStyle(fontSize: AppTheme.fontSizeBody),
                    decoration: InputDecoration(
                      hintText: 'Mind. 3 Zeichen...',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      suffixIcon: GestureDetector(
                        onTap: () {
                          _controller.clear();
                          widget.onSearch('');
                          setState(() => _isAdding = false);
                        },
                        child: const Icon(Icons.close, size: 18),
                      ),
                      suffixIconConstraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                    onChanged: widget.onSearch,
                    onSubmitted: (_) => _submitIngredient(),
                  ),
                )
              else
                GestureDetector(
                  onTap: () {
                    setState(() => _isAdding = true);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _focusNode.requestFocus();
                    });
                  },
                  child: const Text(
                    '+ Hinzufügen',
                    style: TextStyle(
                      fontSize: AppTheme.fontSizeBody,
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          if (_isAdding && filteredSuggestions.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                children: filteredSuggestions.map((s) {
                  return ListTile(
                    title: Text(s.name),
                    dense: true,
                    onTap: () {
                      widget.onAdd(s.name);
                      _controller.clear();
                      widget.onSearch('');
                      setState(() => _isAdding = false);
                    },
                    trailing: s.isOwn
                        ? IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 20,
                              color: AppTheme.mutedForeground,
                            ),
                            onPressed: () => widget.onDeleteIngredient(s.id),
                          )
                        : null,
                  );
                }).toList(),
              ),
            ),
          ],
          if (widget.ingredients.isNotEmpty) ...[
            AppConstants.gap8,
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.ingredients.map((ingredient) {
                return Chip(
                  label: Text(ingredient),
                  labelStyle: const TextStyle(color: Colors.black),
                  onDeleted: () => widget.onRemove(ingredient),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
