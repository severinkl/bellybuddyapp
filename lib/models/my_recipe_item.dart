import 'recipe.dart';
import 'user_recipe.dart';

/// One entry of „Meine Rezepte": a recipe the user wrote or one they saved
/// from the collection.
sealed class MyRecipeItem {
  const MyRecipeItem();

  /// Sorts the list, newest first: when an own recipe was created, when a
  /// recipe was saved.
  DateTime get at;
}

final class OwnRecipe extends MyRecipeItem {
  const OwnRecipe(this.recipe);

  final UserRecipe recipe;

  @override
  DateTime get at => recipe.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
}

final class SavedRecipe extends MyRecipeItem {
  const SavedRecipe(this.recipe, this.at);

  final Recipe recipe;

  @override
  final DateTime at;
}

/// [own] and [saved] in one list, newest [MyRecipeItem.at] first; on a tie
/// the own recipe comes first, then the input order.
List<MyRecipeItem> mergeMyRecipes(
  List<UserRecipe> own,
  List<SavedRecipe> saved,
) {
  final items = <MyRecipeItem>[...own.map(OwnRecipe.new), ...saved];
  final order = {for (var i = 0; i < items.length; i++) items[i]: i};
  return items..sort((a, b) {
    final byTime = b.at.compareTo(a.at);
    return byTime != 0 ? byTime : order[a]!.compareTo(order[b]!);
  });
}
