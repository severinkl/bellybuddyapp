import 'package:flutter/material.dart';
import '../../../../config/app_theme.dart';
import '../../../../services/ingredient_service.dart';

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
  bool _isAdding = false;

  @override
  void dispose() {
    _controller.dispose();
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Zutaten',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (_isAdding) ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Mind. 3 Zeichen...',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _controller.clear();
                          widget.onSearch('');
                          setState(() => _isAdding = false);
                        },
                      ),
                    ),
                    onChanged: widget.onSearch,
                    onSubmitted: (_) => _submitIngredient(),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _submitIngredient,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
            if (filteredSuggestions.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  children: filteredSuggestions.map((s) {
                    return ListTile(
                      title: Text(s.name),
                      dense: true,
                      onTap: () {
                        _controller.text = s.name;
                        _controller.selection = TextSelection.fromPosition(
                          TextPosition(offset: s.name.length),
                        );
                        widget.onSearch('');
                      },
                      trailing: s.isOwn
                          ? IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  size: 20, color: AppTheme.mutedForeground),
                              onPressed: () =>
                                  widget.onDeleteIngredient(s.id),
                            )
                          : null,
                    );
                  }).toList(),
                ),
              ),
            const SizedBox(height: 8),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...widget.ingredients.map((ingredient) {
                return Chip(
                  label: Text(ingredient),
                  labelStyle: const TextStyle(color: Colors.black),
                  onDeleted: () => widget.onRemove(ingredient),
                );
              }),
              ActionChip(
                backgroundColor: AppTheme.primary,
                label: const Text('+ Hinzufügen'),
                onPressed: () => setState(() => _isAdding = true),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
