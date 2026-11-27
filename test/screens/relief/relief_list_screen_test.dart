import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/providers/relief_provider.dart';
import 'package:belly_buddy/router/route_names.dart';
import 'package:belly_buddy/screens/relief/relief_list_screen.dart';
import 'package:belly_buddy/screens/relief/widgets/relief_safety.dart';
import 'package:belly_buddy/services/relief/relief_content.dart';
import 'package:belly_buddy/services/relief/relief_rules.dart';

import '../../helpers/app_host.dart';

class _Feedback extends ReliefFeedbackNotifier {
  _Feedback(this.answers);

  final Map<String, ReliefAnswer> answers;

  @override
  Future<Map<String, ReliefAnswer>> build() async => answers;
}

void main() {
  Future<GoRouter> pump(
    WidgetTester tester, {
    Map<String, ReliefAnswer> answers = const {},
  }) async {
    // Tall enough that the lazy list builds every card.
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const ReliefListScreen(),
          routes: [
            GoRoute(
              path: 'relief/:id',
              builder: (_, state) =>
                  Scaffold(body: Text('player:${state.pathParameters['id']}')),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reliefFeedbackProvider.overrideWith(() => _Feedback(answers)),
          reliefReviewMarkersProvider.overrideWithValue(false),
        ],
        child: germanRouterApp(router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    return router;
  }

  testWidgets('shows the intro and all six exercises', (tester) async {
    await pump(tester);
    expect(find.text(ReliefCopy.listIntro), findsOneWidget);
    for (final e in reliefExercises) {
      expect(find.text(e.title), findsOneWidget);
    }
    expect(reliefExercises, hasLength(6));
    expect(find.text('3 Min.'), findsWidgets);
    expect(find.text('12 Min.'), findsOneWidget);
  });

  testWidgets('puts a liked exercise first and labels it', (tester) async {
    await pump(tester, answers: {'gedanken': ReliefAnswer.yes});
    final first = tester.getTopLeft(find.text('Gedanken beruhigen'));
    for (final e in reliefExercises.where((e) => e.id != 'gedanken')) {
      expect(first.dy, lessThan(tester.getTopLeft(find.text(e.title)).dy));
    }
    expect(find.text(ReliefCopy.helpedLabel), findsOneWidget);
  });

  testWidgets('keeps the safety line outside the scroll view', (tester) async {
    await pump(tester);
    expect(find.byType(ReliefSafetyLine), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(Scrollable),
        matching: find.byType(ReliefSafetyLine),
      ),
      findsNothing,
    );
  });

  testWidgets('tapping a card pushes its player', (tester) async {
    await pump(tester);
    await tester.tap(find.text(reliefExerciseById('bauchatmung')!.title));
    await tester.pumpAndSettle();
    expect(find.text('player:bauchatmung'), findsOneWidget);
    expect(RoutePaths.reliefExerciseFor('bauchatmung'), '/relief/bauchatmung');
  });
}
