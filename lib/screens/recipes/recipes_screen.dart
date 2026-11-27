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
        // Named like its section on Entdecken; a back arrow like the
        // screens pushed from there.
        title: const Text('Meine Rezepte'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Zurück',
          onPressed: () => context.popOrGoDashboard(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Rezept hinzufügen',
            onPressed: () => showAddRecipeChooserSheet(context),
          ),
        ],
      ),
      body: const MyRecipesTab(),
    );
  }
}
