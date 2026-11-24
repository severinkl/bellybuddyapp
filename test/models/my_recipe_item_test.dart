import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/models/my_recipe_item.dart';
import 'package:belly_buddy/models/user_recipe.dart';

import '../helpers/fakes.dart';
import '../helpers/fixtures.dart';

void main() {
  UserRecipe own(String id, DateTime? at) => at == null
      ? UserRecipe(id: id, userId: testUserId, title: id)
      : testUserRecipe(id: id, createdAt: at);
  SavedRecipe saved(String id, DateTime at) =>
      SavedRecipe(testRecipe(id: id), at);

  List<String> ids(List<MyRecipeItem> items) => [
    for (final i in items)
      switch (i) {
        OwnRecipe(:final recipe) => 'own:${recipe.id}',
        SavedRecipe(:final recipe) => 'saved:${recipe.id}',
      },
  ];

  test('newest first, own before saved on a tie', () {
    final items = mergeMyRecipes(
      [own('a', DateTime(2026, 11, 20)), own('b', DateTime(2026, 11, 22))],
      [saved('s', DateTime(2026, 11, 21)), saved('t', DateTime(2026, 11, 22))],
    );
    expect(ids(items), ['own:b', 'saved:t', 'saved:s', 'own:a']);
  });

  test('an own recipe without a date counts as the epoch (last)', () {
    final items = mergeMyRecipes(
      [own('a', null)],
      [saved('s', DateTime(2020))],
    );
    expect(ids(items), ['saved:s', 'own:a']);
    expect(items.last.at, DateTime.fromMillisecondsSinceEpoch(0));
  });

  test('equal dates keep the input order', () {
    final at = DateTime(2026, 11, 20);
    final items = mergeMyRecipes([own('a', at), own('b', at)], const []);
    expect(ids(items), ['own:a', 'own:b']);
  });
}
