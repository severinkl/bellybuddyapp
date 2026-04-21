import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/app_theme.dart';
import '../../../../config/constants.dart';
import '../../../../models/drink.dart';
import '../../../../providers/drink_tracker_provider.dart';
import '../../../../providers/core_providers.dart';
import '../../../../services/haptic_service.dart';

/// Drink autocomplete. Suggestions render inline under the TextField in the
/// normal widget tree — not in an OverlayPortal — so dragging inside the
/// list scrolls the enclosing page naturally and taps on the list do not
/// collapse the dropdown. Mirrors the pattern used in `IngredientSearch`.
class DrinkSearch extends ConsumerStatefulWidget {
  const DrinkSearch({super.key});

  @override
  ConsumerState<DrinkSearch> createState() => _DrinkSearchState();
}

class _DrinkSearchState extends ConsumerState<DrinkSearch> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    // Rebuild so the inline suggestion list shows/hides with focus.
    if (mounted) setState(() {});
  }

  bool get _shouldShowCreateOption {
    final query = _controller.text.trim();
    if (query.isEmpty) return false;
    final suggestions = ref.read(drinkTrackerProvider).suggestions;
    return !suggestions.any((d) => d.name.toLowerCase() == query.toLowerCase());
  }

  void _selectDrink(Drink drink) {
    HapticService.selection();
    _controller.clear();
    _focusNode.unfocus();
    ref.read(drinkTrackerProvider.notifier).toggleDrink(drink);
  }

  Future<void> _createDrink() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    HapticService.selection();
    final messenger = ScaffoldMessenger.of(context);
    _controller.clear();
    _focusNode.unfocus();
    try {
      await ref.read(drinkTrackerProvider.notifier).createDrink(query);
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('„$query" hinzugefügt')));
      }
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Getränk konnte nicht erstellt werden')),
        );
      }
    }
  }

  Future<void> _deleteDrink(Drink drink) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(drinkTrackerProvider.notifier).deleteDrink(drink);
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Getränk konnte nicht gelöscht werden')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = ref.watch(
      drinkTrackerProvider.select((s) => s.suggestions),
    );
    final currentUserId = ref.watch(currentUserIdProvider);
    final showCreate = _shouldShowCreateOption;
    final showSuggestions =
        _focusNode.hasFocus && (suggestions.isNotEmpty || showCreate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          decoration: InputDecoration(
            hintText: 'Getränk suchen...',
            prefixIcon: const Icon(Icons.search, size: 20),
            filled: true,
            fillColor: AppTheme.muted.withValues(alpha: 0.5),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusFull),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusFull),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusFull),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (q) {
            ref.read(drinkTrackerProvider.notifier).searchDrinks(q);
            // Rebuild so the "create" option re-evaluates against the query.
            if (mounted) setState(() {});
          },
        ),
        if (showSuggestions)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              children: [
                ...suggestions.map((drink) {
                  final isOwn =
                      currentUserId != null &&
                      drink.addedByUserId == currentUserId;
                  return ListTile(
                    title: Text(
                      drink.name,
                      style: const TextStyle(fontSize: AppTheme.fontSizeBody),
                    ),
                    dense: true,
                    onTap: () => _selectDrink(drink),
                    trailing: isOwn
                        ? IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: AppTheme.mutedForeground,
                            ),
                            onPressed: () => _deleteDrink(drink),
                          )
                        : null,
                  );
                }),
                if (showCreate)
                  ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.add,
                      size: 18,
                      color: AppTheme.primary,
                    ),
                    title: Text(
                      '„${_controller.text.trim()}" hinzufügen',
                      style: const TextStyle(
                        fontSize: AppTheme.fontSizeBody,
                        color: AppTheme.primary,
                      ),
                    ),
                    onTap: _createDrink,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
