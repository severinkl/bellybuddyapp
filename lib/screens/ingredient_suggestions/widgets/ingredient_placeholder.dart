import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';

/// The picture of an ingredient that has none: a neutral food icon on a
/// muted circle, [size] across (no particular food, so it never suggests
/// the wrong one).
class IngredientPlaceholder extends StatelessWidget {
  const IngredientPlaceholder({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppTheme.muted,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.restaurant,
        size: size * 0.5,
        color: AppTheme.mutedForeground,
      ),
    );
  }
}
