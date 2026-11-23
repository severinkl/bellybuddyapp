import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/providers/buddy_provider.dart';
import 'package:belly_buddy/providers/diary_provider.dart';
import 'package:belly_buddy/providers/entries_provider.dart';
import 'package:belly_buddy/router/route_names.dart';
import 'package:belly_buddy/screens/dashboard/widgets/today_list.dart';
import 'package:belly_buddy/services/buddy/daily_care.dart';

import '../../../helpers/fixtures.dart';

class _SeededEntries extends EntriesNotifier {
  _SeededEntries(this._s);

  final EntriesState _s;

  @override
  EntriesState build() => _s;
}

void main() {
  final now = DateTime(2026, 11, 23, 13);

  setUpAll(() => initializeDateFormatting('de_DE'));

  group('todayLogItems', () {
    test("today's entries, oldest first; other days left out", () {
      final items = todayLogItems(
        EntriesState(
          meals: [
            testMealEntry(
              trackedAt: DateTime(2026, 11, 23, 8, 10),
              title: 'Haferbrei mit Banane',
            ),
            testMealEntry(trackedAt: DateTime(2026, 11, 22, 19)),
          ],
          drinks: [
            testDrinkEntry(
              trackedAt: DateTime(2026, 11, 23, 11, 40),
              amountMl: 500,
            ),
          ],
          gutFeelings: [
            testGutFeelingEntry(trackedAt: DateTime(2026, 11, 23, 11, 5)),
          ],
          toiletEntries: [
            testToiletEntry(trackedAt: DateTime(2026, 11, 23, 12, 10)),
          ],
        ),
        now,
      );

      expect(items.map((i) => i.need), [
        CareNeed.food,
        CareNeed.gutFeeling,
        CareNeed.drink,
        CareNeed.toilet,
      ]);
      expect(items.first.label, 'Haferbrei mit Banane');
      expect(items[2].label, endsWith('· 500 ml'));
      expect(items[1].label, startsWith('Bauchgefühl: '));
      expect(items.last.label, 'Klo-Eintrag');
    });

    test('a litre and more reads in litres', () {
      final items = todayLogItems(
        EntriesState(
          drinks: [
            testDrinkEntry(
              trackedAt: DateTime(2026, 11, 23, 9),
              amountMl: 1500,
            ),
          ],
        ),
        now,
      );
      expect(items.single.label, endsWith('· 1.5 L'));
    });
  });

  group('TodayList', () {
    Future<GoRouter> pump(WidgetTester tester, EntriesState entries) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) =>
                const Scaffold(body: SingleChildScrollView(child: TodayList())),
          ),
          GoRoute(
            path: RoutePaths.diary,
            builder: (_, _) => const Scaffold(body: Text('diary-page')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            buddyClockProvider.overrideWithValue(() => now),
            entriesProvider.overrideWith(() => _SeededEntries(entries)),
          ],
          child: MaterialApp.router(
            theme: AppTheme.theme,
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();
      return router;
    }

    testWidgets('no entries today → an empty hint', (tester) async {
      await pump(tester, const EntriesState());
      expect(find.text('Heute'), findsOneWidget);
      expect(find.text(TodayList.emptyText), findsOneWidget);
    });

    testWidgets('shows at most the 5 latest entries', (tester) async {
      await pump(
        tester,
        EntriesState(
          meals: [
            for (var h = 6; h < 13; h++)
              testMealEntry(
                trackedAt: DateTime(2026, 11, 23, h),
                title: 'Mahlzeit $h',
              ),
          ],
        ),
      );
      expect(find.text('Mahlzeit 6'), findsNothing);
      expect(find.text('Mahlzeit 7'), findsNothing);
      expect(find.text('Mahlzeit 8'), findsOneWidget);
      expect(find.text('Mahlzeit 12'), findsOneWidget);
    });

    testWidgets('text scale 1.3: the time stays on one line', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pump(
        tester,
        EntriesState(
          meals: [testMealEntry(trackedAt: DateTime(2026, 11, 23, 8, 10))],
        ),
      );

      final time = find.text('08:10');
      expect(time, findsOneWidget);
      final line = tester.getSize(time).height;
      final style = tester.widget<Text>(time).style!;
      // One line: no taller than the scaled font's line box allows.
      expect(line, lessThan(style.fontSize! * 1.3 * 2));
    });

    testWidgets('the diary link opens today in the diary', (tester) async {
      await pump(tester, const EntriesState());

      await tester.tap(find.byKey(TodayList.diaryLinkKey));
      await tester.pumpAndSettle();

      expect(find.text('diary-page'), findsOneWidget);
      final scope = tester.element(find.text('diary-page'));
      expect(
        ProviderScope.containerOf(scope).read(diaryDateProvider),
        DateTime(2026, 11, 23),
      );
    });
  });
}
