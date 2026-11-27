import 'package:material_ui/material_ui.dart';
import '../../../../config/app_theme.dart';
import '../../../../config/constants.dart';

/// Rows of equal-height cells, [columns] wide (2 at large text sizes).
class DrinkTileGrid extends StatelessWidget {
  const DrinkTileGrid({
    super.key,
    required this.children,
    required this.normalColumns,
  });

  final List<Widget> children;

  /// Columns at normal text size; large text (at or above
  /// [AppConstants.drinkGridLargeTextScale]) uses two.
  final int normalColumns;

  @override
  Widget build(BuildContext context) {
    final columns = AppConstants.isLargeText(context)
        ? AppConstants.drinkGridLargeTextColumns
        : normalColumns;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i += columns) ...[
          if (i > 0) const SizedBox(height: AppConstants.spacingSm),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var c = 0; c < columns; c++) ...[
                  if (c > 0) const SizedBox(width: AppConstants.spacingSm),
                  Expanded(
                    child: i + c < children.length
                        ? children[i + c]
                        : const SizedBox(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// A tile's fill and border: selected is white with a 2 px `infoText` edge.
BoxDecoration drinkTileDecoration({required bool selected}) => BoxDecoration(
  color: selected ? AppTheme.background : AppTheme.card,
  borderRadius: BorderRadius.circular(AppConstants.radiusLg),
  border: Border.all(
    color: selected ? AppTheme.infoText : Colors.transparent,
    width: AppConstants.borderWidthLg,
  ),
);
