import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../router/route_names.dart';
import '../../../widgets/common/bb_drag_handle.dart';
import 'recent_meal_picker_sheet.dart';

Future<void> showAddRecipeChooserSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    // Above the bottom bar when opened from Entdecken.
    useRootNavigator: true,
    useSafeArea: true,
    // The sheet draws its own handle.
    showDragHandle: false,
    backgroundColor: AppTheme.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppConstants.radiusXl),
      ),
    ),
    builder: (sheetContext) => SafeArea(
      top: false,
      child: _AddRecipeChooserSheet(rootContext: context),
    ),
  );
}

class _AddRecipeChooserSheet extends StatelessWidget {
  final BuildContext rootContext;

  const _AddRecipeChooserSheet({required this.rootContext});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: AppConstants.spacingSm),
        const BbDragHandle(),
        const Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppConstants.spacingMd,
            vertical: AppConstants.spacingMd,
          ),
          child: Text(
            'Rezept hinzufügen',
            style: TextStyle(
              fontSize: AppTheme.fontSizeTitle,
              fontWeight: FontWeight.w600,
              color: AppTheme.foreground,
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.history),
          title: const Text('Aus kürzlicher Mahlzeit'),
          onTap: () {
            Navigator.of(context).pop();
            showRecentMealPickerSheet(rootContext);
          },
        ),
        ListTile(
          leading: const Icon(Icons.add),
          title: const Text('Neu erstellen'),
          onTap: () {
            Navigator.of(context).pop();
            rootContext.push(RoutePaths.recipeNew);
          },
        ),
        const SizedBox(height: AppConstants.spacingMd),
      ],
    );
  }
}
