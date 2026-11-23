import 'package:material_ui/material_ui.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';

/// A rounded bar, [height] tall, filled from the left to [value] (0..1,
/// clamped) in the primary colour on a muted track. Draws only; callers
/// give it a semantics label.
class BbProgressBar extends StatelessWidget {
  const BbProgressBar({super.key, required this.value, required this.height});

  final double value;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(AppConstants.radiusFull),
    child: SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: AppTheme.muted),
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: value.clamp(0.0, 1.0),
            child: const ColoredBox(color: AppTheme.primary),
          ),
        ],
      ),
    ),
  );
}
