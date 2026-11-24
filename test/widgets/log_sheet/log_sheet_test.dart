import 'package:belly_buddy/services/buddy/daily_care.dart';
import 'package:belly_buddy/widgets/log_sheet/log_sheet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';

final _now = DateTime(2026, 11, 23, 12, 40);

/// Pumps a page with an „open" button; returns the pushed (location, extra).
Future<List<(String, Object?)>> _pump(
  WidgetTester tester, {
  required DateTime day,
  CareNeed? suggested,
}) async {
  final pushed = <(String, Object?)>[];
  Widget stub(String name) => Scaffold(body: Text('stub $name'));
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showLogSheet(
                context,
                day: day,
                now: _now,
                suggested: suggested,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
      for (final path in [
        '/meal-tracker',
        '/drink-tracker',
        '/gut-feeling-tracker',
        '/toilet-tracker',
      ])
        GoRoute(
          path: path,
          builder: (context, state) {
            pushed.add((state.uri.path, state.extra));
            return stub(path);
          },
        ),
    ],
  );
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return pushed;
}

void _expectSelected(WidgetTester tester, CareNeed need, bool selected) {
  expect(
    tester.getSemantics(find.byKey(LogSheet.optionKey(need))),
    isSemantics(isSelected: selected, hasSelectedState: true),
    reason: need.name,
  );
}

void main() {
  setUpAll(() => initializeDateFormatting('de_DE'));

  testWidgets('shows four options headed by the day', (tester) async {
    await _pump(tester, day: _now);
    expect(find.text('Eintragen'), findsOneWidget);
    expect(find.text('Heute · 12:40'), findsOneWidget);
    for (final need in CareNeed.values) {
      expect(find.byKey(LogSheet.optionKey(need)), findsOneWidget);
      expect(find.text(need.label), findsOneWidget);
    }
  });

  testWidgets('a past day reads Für …', (tester) async {
    await _pump(tester, day: DateTime(2026, 11, 18));
    expect(find.text('Für Mi, 18. Nov'), findsOneWidget);
  });

  testWidgets('suggested option is highlighted', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, day: _now, suggested: CareNeed.drink);
    _expectSelected(tester, CareNeed.drink, true);
    _expectSelected(tester, CareNeed.food, false);
    _expectSelected(tester, CareNeed.toilet, false);
    handle.dispose();
  });

  testWidgets('tapping an option pushes its tracker with the day at 12:00', (
    tester,
  ) async {
    final pushed = await _pump(tester, day: DateTime(2026, 11, 18));
    await tester.tap(find.byKey(LogSheet.optionKey(CareNeed.drink)));
    await tester.pumpAndSettle();
    expect(pushed, [('/drink-tracker', DateTime(2026, 11, 18, 12))]);
    expect(find.text('Eintragen'), findsNothing);
  });

  testWidgets('from today pushes extra null', (tester) async {
    final pushed = await _pump(tester, day: _now);
    await tester.tap(find.byKey(LogSheet.optionKey(CareNeed.food)));
    await tester.pumpAndSettle();
    expect(pushed, [('/meal-tracker', null)]);
  });
}
