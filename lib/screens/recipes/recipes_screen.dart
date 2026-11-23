import 'package:material_ui/material_ui.dart';

import '../../config/app_theme.dart';
import '../../router/navigation_extensions.dart';
import 'my_recipes_tab.dart';
import 'widgets/add_recipe_chooser_sheet.dart';

/// All of the user's own recipes (Entdecken → Meine Rezepte → „Alle ›"),
/// with search and „+" to add one.
class RecipesScreen extends StatelessWidget {
  const RecipesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.screenBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.screenBackground,
        title: const Text('Rezepte'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.popOrGoDashboard(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => showAddRecipeChooserSheet(context),
          ),
        ],
      ),
      body: const MyRecipesTab(),
    );
  }
}
