import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/app_theme.dart';
import '../../../../config/constants.dart';
import '../../../../models/drink.dart';
import '../../../../providers/drink_tracker_provider.dart';
import '../../../../services/haptic_service.dart';
import '../../../../utils/drink_helpers.dart';
import '../../../../utils/reduced_motion.dart';
import '../../../../widgets/common/bb_tap_area.dart';
import '../../../../widgets/common/dashed_border_painter.dart';
import 'drink_glyph.dart';
import 'drink_search.dart';
import 'drink_tile_grid.dart';

/// The „Was?" section: up to five drink tiles and „Anderes suchen", which
/// opens the search in place of the heading.
class QuickDrinkGrid extends ConsumerWidget {
  const QuickDrinkGrid({super.key});

  static Key tileKey(String drinkId) => Key('drink_tile_$drinkId');
  static const searchTileKey = Key('drink_tile_search');

  static const _searchLabel = 'Anderes suchen';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quickDrinks = ref.watch(
      drinkTrackerProvider.select((s) => s.quickDrinks),
    );
    final selectedDrink = ref.watch(
      drinkTrackerProvider.select((s) => s.selectedDrink),
    );
    final hasLastDrink = ref.watch(
      drinkTrackerProvider.select((s) => s.lastDrink != null),
    );
    final isSearchOpen = ref.watch(
      drinkTrackerProvider.select((s) => s.isSearchOpen),
    );
    // A pending save keeps its drink: the tiles do nothing meanwhile.
    final isSaving = ref.watch(drinkTrackerProvider.select((s) => s.isSaving));
    final notifier = ref.read(drinkTrackerProvider.notifier);

    final drinks = DrinkHelpers.tileDrinks(quickDrinks, selectedDrink);
    final cells = <Widget>[
      for (final drink in drinks)
        _DrinkTile(
          drink: drink,
          isSelected: selectedDrink?.id == drink.id,
          onTap: isSaving
              ? null
              : () {
                  HapticService.selection();
                  notifier.toggleDrink(drink);
                },
        ),
      _SearchTile(
        isOpen: isSearchOpen,
        onTap: () =>
            isSearchOpen ? notifier.closeSearch() : notifier.openSearch(),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isSearchOpen)
          const DrinkSearch(autofocus: true)
        else
          Semantics(
            header: true,
            child: Text(
              hasLastDrink && selectedDrink == null ? 'Oder wähle aus' : 'Was?',
              style: const TextStyle(
                fontSize: AppTheme.fontSizeSubtitle,
                fontWeight: FontWeight.w600,
                color: AppTheme.foreground,
              ),
            ),
          ),
        AppConstants.gap8,
        DrinkTileGrid(
          normalColumns: AppConstants.drinkGridColumns,
          children: cells,
        ),
      ],
    );
  }
}

TextStyle _nameStyle({bool selected = false}) => TextStyle(
  fontSize: AppTheme.fontSizeCaptionLG,
  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
  color: AppTheme.foreground,
);

class _DrinkTile extends StatelessWidget {
  const _DrinkTile({
    required this.drink,
    required this.isSelected,
    required this.onTap,
  });

  final Drink drink;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppTheme.infoText : AppTheme.foreground;
    return BbTapArea(
      tapKey: QuickDrinkGrid.tileKey(drink.id),
      label: drink.name,
      selected: isSelected,
      // One drink at a time (tapping it again clears it).
      exclusive: true,
      // The tile is at least drinkTileMinHeight (84) tall already.
      tapTarget: false,
      excludeChild: true,
      onTap: onTap,
      child: AnimatedContainer(
        duration: ReducedMotion.duration(context, AppConstants.animFast),
        constraints: const BoxConstraints(
          minHeight: AppConstants.drinkTileMinHeight,
        ),
        padding: const EdgeInsets.all(AppConstants.spacingXs),
        decoration: drinkTileDecoration(selected: isSelected),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DrinkGlyph.icon(DrinkHelpers.iconFor(drink), color: color),
            AppConstants.gap6,
            Text(
              drink.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: _nameStyle(selected: isSelected),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchTile extends StatelessWidget {
  const _SearchTile({required this.isOpen, required this.onTap});

  final bool isOpen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BbTapArea(
      tapKey: QuickDrinkGrid.searchTileKey,
      label: QuickDrinkGrid._searchLabel,
      expanded: isOpen,
      tapTarget: false,
      excludeChild: true,
      onTap: onTap,
      child: CustomPaint(
        foregroundPainter: const DashedBorderPainter(
          color: AppTheme.mutedForeground,
          dashLength: AppConstants.dashLengthSm,
          dashGap: AppConstants.dashGapSm,
        ),
        child: Container(
          constraints: const BoxConstraints(
            minHeight: AppConstants.drinkTileMinHeight,
          ),
          padding: const EdgeInsets.all(AppConstants.spacingXs),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.search,
                size: AppConstants.iconSizeMd,
                color: AppTheme.mutedForeground,
              ),
              AppConstants.gap6,
              Text(
                QuickDrinkGrid._searchLabel,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: _nameStyle(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
