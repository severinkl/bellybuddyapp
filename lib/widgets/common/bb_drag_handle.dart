import 'package:material_ui/material_ui.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';

/// The grab bar at the top of a bottom sheet, centred horizontally.
class BbDragHandle extends StatelessWidget {
  const BbDragHandle({super.key, this.color = AppTheme.muted});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: AppConstants.dragHandleWidth,
        height: AppConstants.dragHandleHeight,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppConstants.dragHandleRadius),
        ),
      ),
    );
  }
}
