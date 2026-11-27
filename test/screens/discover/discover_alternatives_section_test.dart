import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/models/ingredient_suggestion_group.dart';
import 'package:belly_buddy/providers/plus_provider.dart';
import 'package:belly_buddy/router/route_names.dart';
import 'package:belly_buddy/screens/discover/widgets/discover_alternatives_section.dart';
import 'package:belly_buddy/widgets/common/plus_locked_card.dart';

import '../../helpers/app_host.dart';
import '../../helpers/fixtures.dart';

const _today =
    'Noch keine Alternativen – sie entstehen nach deinen Mahlzeiten.';
const _note =
    'Alternativen zu auffälligen Zutaten gibt es mit Belly Buddy Plus.';

Future<void> _pump(
  WidgetTester tester,
  List<IngredientSuggestionGroup> groups,
  Override plus,
) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(
          body: DiscoverAlternativesSection(
            groups: AsyncData(groups),
            newCount: 0,
            onOpen: () {},
          ),
        ),
      ),
      GoRoute(
        path: RoutePaths.plus,
        builder: (_, _) => const Scaffold(body: Text('page:/plus')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(overrides: [plus], child: germanRouterApp(router)),
  );
  await tester.pumpAndSettle();
}

void main() {
  final locked = plusAccessProvider.overrideWithValue(PlusAccess.locked);
  final open = plusAccessProvider.overrideWithValue(PlusAccess.open);
  final switchOff = paywallEnabledProvider.overrideWithValue(false);
  final groups = [testSuggestionGroup()];

  testWidgets('locked and none: the Plus note and a link to /plus', (
    tester,
  ) async {
    await _pump(tester, const [], locked);

    expect(find.text(_note), findsOneWidget);
    expect(find.text(_today), findsNothing);
    expect(find.text('Alle ›'), findsNothing);

    await tester.tap(find.byKey(PlusLink.openKey));
    await tester.pumpAndSettle();
    expect(find.text('page:/plus'), findsOneWidget);
  });

  testWidgets('locked with groups: the groups stay, no note', (tester) async {
    await _pump(tester, groups, locked);

    expect(find.text('Zwiebel'), findsOneWidget);
    expect(find.text('Alle ›'), findsOneWidget);
    expect(find.text(_note), findsNothing);
    expect(find.byKey(PlusLink.openKey), findsNothing);
  });

  for (final (name, plus) in [('open', open), ('switch off', switchOff)]) {
    testWidgets('$name and none: today\'s line, no link', (tester) async {
      await _pump(tester, const [], plus);

      expect(find.text(_today), findsOneWidget);
      expect(find.text(_note), findsNothing);
      expect(find.byKey(PlusLink.openKey), findsNothing);
    });

    testWidgets('$name with groups: the groups', (tester) async {
      await _pump(tester, groups, plus);

      expect(find.text('Zwiebel'), findsOneWidget);
      expect(find.text(_note), findsNothing);
    });
  }
}
