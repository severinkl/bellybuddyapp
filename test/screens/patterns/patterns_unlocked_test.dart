import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/models/insight_progress.dart';
import 'package:belly_buddy/models/insights.dart';
import 'package:belly_buddy/providers/insights_provider.dart';
import 'package:belly_buddy/screens/patterns/patterns_screen.dart';
import 'package:belly_buddy/services/insights/insight_copy.dart';

import '../../helpers/app_host.dart';

/// Serves a fixed [Insights] value instead of computing one.
class _FixedInsights extends InsightsNotifier {
  _FixedInsights(this.value);

  final Insights value;

  @override
  Future<Insights> build() async => value;
}

/// The Muster page showing [insights], on a view tall enough to build all
/// of it by default.
Future<void> _pump(
  WidgetTester tester,
  Insights insights, {
  Size size = const Size(390, 3200),
  double textScale = 1,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    routes: [GoRoute(path: '/', builder: (_, _) => const PatternsScreen())],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        insightsProvider.overrideWith(() => _FixedInsights(insights)),
      ],
      child: germanRouterApp(router, textScale: textScale),
    ),
  );
  await tester.pumpAndSettle();
}

/// The window from 25.10.2026 (a Sunday) to 23.11.2026, each day's class
/// from [classOf] by its index.
List<InsightDay> _calendar(DayClass Function(int i) classOf) => [
  for (var i = 0; i < InsightProgress.windowDays; i++)
    InsightDay(day: DateTime(2026, 10, 25 + i), dayClass: classOf(i)),
];

/// 21 days with a gut feeling (7 of every 10), cycling hard, good, medium:
/// 25. Okt and 18. Nov are hard, 26. Okt good, 27. Okt medium, 1. Nov
/// without an entry.
DayClass _mixed(int i) => i % 10 >= 7
    ? DayClass.none
    : const [DayClass.hard, DayClass.good, DayClass.medium][i % 3];

const _zwiebel = Noticed(
  name: 'Zwiebel',
  hard: 4,
  hardDays: 5,
  good: 1,
  goodDays: 6,
);

const _lauch = Noticed(
  name: 'Lauch',
  hard: 2,
  hardDays: 5,
  good: 0,
  goodDays: 6,
  uncertain: true,
);

Insights _insights({
  List<InsightDay>? calendar,
  DayColumn goodDays = const DayColumn(
    days: 4,
    often: [IngredientCount('Reis', 3, of: 4)],
  ),
  DayColumn hardDays = const DayColumn(days: 2),
  List<Noticed> noticed = const [],
}) => Insights(
  progress: const InsightProgress(activeDays: 24, gutFeelingEntries: 25),
  calendar: calendar ?? _calendar(_mixed),
  goodDays: goodDays,
  hardDays: hardDays,
  noticed: noticed,
  pick: const NothingYetPick(),
);

/// Every day cell, by its semantics („25. Okt: schwer").
final _dayCells = find.bySemanticsLabel(RegExp(r'^\d{1,2}\. (Okt|Nov): '));

const _footer =
    'ⓘ Beobachtung aus deinen Einträgen, kein medizinischer Befund.';
const _definitions =
    'Schwerer Tag = Bauchgefühl „Schlecht"; guter Tag = „Gut" oder '
    '„Sehr gut".';

/// „Fällt mir auf" as its section label draws it.
final _noticedTitle = find.text(InsightCopy.noticedTitle.toUpperCase());

void main() {
  group('calendar', () {
    testWidgets('has 30 day cells aligned to weekdays', (tester) async {
      await _pump(tester, _insights());

      expect(_dayCells, findsNWidgets(InsightProgress.windowDays));
      for (final name in ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So']) {
        expect(find.text(name), findsOneWidget);
      }
      // 25.10.2026 is a Sunday: 6 blanks before it, then Monday's row.
      final first = find.bySemanticsLabel('25. Okt: schwer');
      expect(first, findsOneWidget);
      expect(
        tester.getCenter(first).dx,
        moreOrLessEquals(tester.getCenter(find.text('So')).dx),
      );
      final monday = find.bySemanticsLabel('26. Okt: gut');
      expect(
        tester.getCenter(monday).dx,
        moreOrLessEquals(tester.getCenter(find.text('Mo')).dx),
      );
      expect(
        tester.getCenter(monday).dy,
        greaterThan(tester.getCenter(first).dy),
      );
      // Today, the last day, is a Monday again.
      expect(
        tester.getCenter(find.bySemanticsLabel('23. Nov: kein Eintrag')).dx,
        moreOrLessEquals(tester.getCenter(find.text('Mo')).dx),
      );
    });

    testWidgets('classes are not colour-only', (tester) async {
      await _pump(tester, _insights());

      Finder iconIn(String label, IconData icon) => find.descendant(
        of: find.bySemanticsLabel(label),
        matching: find.byIcon(icon),
      );
      // Each in its class's icon colour, which keeps 3:1 (see
      // app_theme_contrast_test).
      for (final (label, icon, color) in [
        (
          '18. Nov: schwer',
          Icons.sentiment_dissatisfied,
          AppTheme.gutFeelingBadIcon,
        ),
        (
          '26. Okt: gut',
          Icons.sentiment_satisfied_alt,
          AppTheme.gutFeelingGoodIcon,
        ),
        (
          '27. Okt: mittel',
          Icons.sentiment_neutral,
          AppTheme.gutFeelingNeutralIcon,
        ),
      ]) {
        expect(iconIn(label, icon), findsOneWidget);
        expect(tester.widget<Icon>(iconIn(label, icon)).color, color);
      }
      final none = find.bySemanticsLabel('1. Nov: kein Eintrag');
      expect(none, findsOneWidget);
      expect(
        find.descendant(of: none, matching: find.byType(Icon)),
        findsNothing,
      );
      expect(
        find.descendant(of: none, matching: find.text('1')),
        findsOneWidget,
      );
    });

    testWidgets('the legend names every class with its icon', (tester) async {
      await _pump(tester, _insights());

      for (final (label, icon) in [
        ('gut', Icons.sentiment_satisfied_alt),
        ('mittel', Icons.sentiment_neutral),
        ('schwer', Icons.sentiment_dissatisfied),
      ]) {
        expect(find.text(label), findsOneWidget);
        // The legend entry's own row: its icon, then its label.
        final entry = find
            .ancestor(of: find.text(label), matching: find.byType(Row))
            .first;
        expect(
          find.descendant(of: entry, matching: find.byIcon(icon)),
          findsOneWidget,
        );
      }
      expect(find.text('kein Eintrag'), findsOneWidget);
    });

    testWidgets('header counts gut-feeling days', (tester) async {
      await _pump(tester, _insights());
      expect(
        find.text('Letzte 30 Tage · 21 Tage mit Bauchgefühl'),
        findsOneWidget,
      );
    });

    testWidgets('header, singular', (tester) async {
      await _pump(
        tester,
        _insights(
          calendar: _calendar((i) => i == 3 ? DayClass.good : DayClass.none),
        ),
      );
      expect(
        find.text('Letzte 30 Tage · 1 Tag mit Bauchgefühl'),
        findsOneWidget,
      );
    });
  });

  group('good and hard days', () {
    testWidgets('a shown column lists „oft dabei", a hidden one too few', (
      tester,
    ) async {
      await _pump(tester, _insights());

      expect(
        find.text('Deine guten und schweren Tage'.toUpperCase()),
        findsOneWidget,
      );
      expect(find.text('4 gute Tage'), findsOneWidget);
      expect(find.text('oft dabei:'), findsOneWidget);
      expect(find.text('Reis · an 3 von 4 guten Tagen'), findsOneWidget);
      expect(find.text('Noch zu wenige gute Tage'), findsNothing);

      expect(find.text('2 schwere Tage'), findsOneWidget);
      expect(find.text('Noch zu wenige schwere Tage'), findsOneWidget);
    });

    testWidgets('hard items read „an n von m schweren Tagen"', (tester) async {
      await _pump(
        tester,
        _insights(
          goodDays: const DayColumn(days: 2),
          hardDays: const DayColumn(
            days: 5,
            often: [IngredientCount('Zwiebel', 4, of: 5)],
          ),
        ),
      );

      expect(find.text('Noch zu wenige gute Tage'), findsOneWidget);
      expect(find.text('5 schwere Tage'), findsOneWidget);
      expect(find.text('Zwiebel · an 4 von 5 schweren Tagen'), findsOneWidget);
    });

    testWidgets('singular titles', (tester) async {
      await _pump(
        tester,
        _insights(
          goodDays: const DayColumn(days: 1),
          hardDays: const DayColumn(days: 1),
        ),
      );

      expect(find.text('1 guter Tag'), findsOneWidget);
      expect(find.text('1 schwerer Tag'), findsOneWidget);
    });

    testWidgets('a shown column with nothing often there says so', (
      tester,
    ) async {
      await _pump(
        tester,
        _insights(
          goodDays: const DayColumn(days: DayColumn.minDays),
          hardDays: const DayColumn(days: DayColumn.minDays),
        ),
      );

      expect(find.text('Noch nichts, das oft dabei war.'), findsNWidgets(2));
      expect(find.text('oft dabei:'), findsNothing);
    });
  });

  group('Fällt mir auf', () {
    testWidgets('rows and the uncertain badge', (tester) async {
      await _pump(
        tester,
        _insights(
          hardDays: const DayColumn(days: 5),
          noticed: const [_zwiebel, _lauch],
        ),
      );

      expect(_noticedTitle, findsOneWidget);
      expect(
        find.text(
          'Zwiebel · an 4 von 5 schweren Tagen dabei · an guten Tagen: '
          '1 von 6',
        ),
        findsOneWidget,
      );
      expect(find.text(InsightCopy.noticedRow(_zwiebel)), findsOneWidget);
      expect(find.text(InsightCopy.noticedRow(_lauch)), findsOneWidget);
      expect(find.text('noch unsicher'), findsOneWidget);
      // The badge belongs to Lauch's row and is read with it.
      expect(
        tester.getSemantics(find.text(InsightCopy.noticedRow(_lauch))).label,
        contains('noch unsicher'),
      );
      expect(
        tester.getSemantics(find.text(InsightCopy.noticedRow(_zwiebel))).label,
        isNot(contains('noch unsicher')),
      );
      expect(find.text(InsightCopy.nothingYet), findsNothing);
    });

    testWidgets('nothing yet at 3 hard days without items', (tester) async {
      await _pump(
        tester,
        _insights(hardDays: const DayColumn(days: Noticed.minHardDays)),
      );

      expect(_noticedTitle, findsOneWidget);
      expect(find.text(InsightCopy.nothingYet), findsOneWidget);
    });

    testWidgets('no section below 3 hard days', (tester) async {
      await _pump(
        tester,
        _insights(hardDays: const DayColumn(days: Noticed.minHardDays - 1)),
      );

      expect(_noticedTitle, findsNothing);
      expect(find.text(InsightCopy.noticedTitle), findsNothing);
      expect(find.text(InsightCopy.nothingYet), findsNothing);
    });
  });

  testWidgets('footer lines present', (tester) async {
    await _pump(tester, _insights());

    expect(find.text(_footer), findsOneWidget);
    expect(find.text(_definitions), findsOneWidget);
  });

  testWidgets('fits 375×667 at text scale 1.3', (tester) async {
    const names = [
      'Vollkornweizenbrot',
      'Knoblauchbaguette',
      'Frühlingszwiebeln',
      'Haferflockenmüsli',
      'Kichererbsencurry',
      'Sauerkrautsaft',
      'Blumenkohlpüree',
      'Rindfleischbrühe',
    ];
    DayColumn column(int days) => DayColumn(
      days: days,
      often: [
        for (final n in names.take(5)) IngredientCount(n, days - 1, of: days),
      ],
    );
    await _pump(
      tester,
      _insights(
        goodDays: column(14),
        hardDays: column(13),
        noticed: [
          for (final n in names.take(5))
            Noticed(name: n, hard: 12, hardDays: 13, good: 10, goodDays: 14),
          for (final n in names.skip(5))
            Noticed(
              name: n,
              hard: 2,
              hardDays: 13,
              good: 0,
              goodDays: 14,
              uncertain: true,
            ),
        ],
      ),
      size: const Size(375, 667),
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('noch unsicher'), findsNWidgets(3));

    // Scrolls to the footer.
    await tester.scrollUntilVisible(find.text(_definitions), 200);
    expect(tester.takeException(), isNull);
  });
}
