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

  static const searchFieldKey = Key('drink_search_field');
  static const suggestionsKey = Key('drink_search_suggestions');

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

  bool _shouldShowCreateOption(List<Drink> suggestions) {
    final query = _controller.text.trim();
    if (query.isEmpty) return false;
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
    final showCreate = _shouldShowCreateOption(suggestions);
    final showSuggestions =
        _focusNode.hasFocus && (suggestions.isNotEmpty || showCreate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: DrinkSearch.searchFieldKey,
          controller: _controller,
          focusNode: _focusNode,
          // The inline suggestion list replaces the old onTapOutside-to-
          // dismiss path. Expose an explicit keyboard submit so the user
          // can collapse the dropdown without selecting an item.
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _focusNode.unfocus(),
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
          onChanged: ref.read(drinkTrackerProvider.notifier).searchDrinks,
        ),
        if (showSuggestions)
          Container(
            key: DrinkSearch.suggestionsKey,
            margin: const EdgeInsets.only(top: AppConstants.spacingXs),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              border: Border.all(color: AppTheme.border),
            ),
            // Clip so ListTile ripples stay inside the rounded corners.
            clipBehavior: Clip.antiAlias,
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
                            icon: Icon(
                              Icons.delete_outline,
                              size: AppConstants.iconSizeSm,
                              color: AppTheme.destructive.withValues(
                                alpha: 0.6,
                              ),
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
                      size: AppConstants.iconSizeSm,
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
