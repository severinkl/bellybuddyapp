import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/providers/auth_provider.dart';
import 'package:belly_buddy/repositories/recipe_repository.dart';
import 'package:belly_buddy/router/route_names.dart';
import 'package:belly_buddy/screens/recommendations/widgets/tip_recipe_link.dart';

import '../../../helpers/app_host.dart';
import '../../../helpers/fakes.dart';
import '../../../helpers/fixtures.dart';

void main() {
  late FakeRecipeRepository repo;
  late GoRouter router;

  setUp(() {
    repo = FakeRecipeRepository()
      ..collection = [testRecipe(id: 'r-1', title: 'Hirse-Bowl')];
  });

  Future<void> pump(WidgetTester tester, TipRecipeLink link) async {
    router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          // Under a tip's texts, as in its card.
          builder: (_, _) => Scaffold(
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [const Text('Zwiebel'), const Text('Grund'), link],
            ),
          ),
        ),
        ...stubRoutes([RoutePaths.collectionRecipe]),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recipeRepositoryProvider.overrideWithValue(repo),
          currentUserIdProvider.overrideWithValue(testUserId),
        ],
        child: germanRouterApp(router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('one button node labelled „Passendes Rezept: <title>"', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester, const TipRecipeLink(recipeId: 'r-1'));

    expect(
      tester.getSemantics(find.byKey(TipRecipeLink.keyFor('r-1'))),
      isSemantics(
        label: 'Passendes Rezept: Hirse-Bowl',
        isButton: true,
        hasTapAction: true,
      ),
    );
    expect(find.semantics.byLabel('Passendes Rezept: Hirse-Bowl'), findsOne);
    expect(find.semantics.byLabel('Hirse-Bowl'), findsNothing);
    expect(find.semantics.byLabel(RegExp('^Passendes Rezept')), findsOne);

    tester.semantics.tap(
      find.semantics.byLabel('Passendes Rezept: Hirse-Bowl'),
    );
    await tester.pumpAndSettle();
    expect(
      router.routerDelegate.currentConfiguration.last.matchedLocation,
      RoutePaths.collectionRecipeFor('r-1'),
    );
    handle.dispose();
  });

  testWidgets("its own title wins over the collection's", (tester) async {
    await pump(
      tester,
      const TipRecipeLink(recipeId: 'r-1', title: 'Hirse-Bowl mit Tahini'),
    );

    expect(
      find.text('Passendes Rezept: Hirse-Bowl mit Tahini'),
      findsOneWidget,
    );
  });
}
