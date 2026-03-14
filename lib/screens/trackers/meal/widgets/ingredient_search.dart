import 'package:flutter/material.dart';
import '../../../../config/app_theme.dart';

class IngredientSearch extends StatefulWidget {
  final List<String> ingredients;
  final List<String> suggestions;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;

  const IngredientSearch({
    super.key,
    required this.ingredients,
    required this.suggestions,
    required this.onSearch,
    required this.onAdd,
    required this.onRemove,
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

  void _submitIngredient(String value) {
    widget.onAdd(value);
    _controller.clear();
    widget.onSearch('');
    setState(() => _isAdding = false);
  }

  @override
  Widget build(BuildContext context) {
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
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Zutat hinzufügen...',
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
              onSubmitted: _submitIngredient,
            ),
            if (widget.suggestions.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  children: widget.suggestions.map((s) {
                    return ListTile(
                      title: Text(s),
                      dense: true,
                      onTap: () => _submitIngredient(s),
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
