// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/models/insight_progress.dart';
import 'package:belly_buddy/models/insights.dart';
import 'package:belly_buddy/router/route_names.dart';
import 'package:belly_buddy/screens/dashboard/widgets/insight_card.dart';

import '../../../helpers/app_host.dart';

/// The card on a Home-like scrolling page, with `/patterns` stubbed.
Future<void> _pump(
  WidgetTester tester,
  AsyncValue<Insights> insights, {
  double textScale = 1,
}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(AppConstants.spacingLg),
            child: InsightCard(insights: insights),
          ),
        ),
      ),
      ...stubRoutes([RoutePaths.patterns]),
    ],
  );
  addTearDown(router.dispose);
  return tester.pumpWidget(germanRouterApp(router, textScale: textScale));
}

Insights _insights(
  InsightProgress progress, [
  InsightPick pick = const NothingYetPick(),
]) => Insights(
  progress: progress,
  calendar: const [],
  goodDays: const DayColumn(days: 0),
  hardDays: const DayColumn(days: 0),
  noticed: const [],
  pick: pick,
);

AsyncValue<Insights> _locked(int days, int gutFeelings) => AsyncData(
  _insights(InsightProgress(activeDays: days, gutFeelingEntries: gutFeelings)),
);

const _unlocked = InsightProgress(activeDays: 12, gutFeelingEntries: 11);

const _zwiebel = Noticed(
  name: 'Zwiebel',
  hard: 4,
  hardDays: 5,
  good: 1,
  goodDays: 6,
);

AsyncValue<Insights> _noticed([Noticed noticed = _zwiebel]) =>
    AsyncData(_insights(_unlocked, NoticedPick(noticed)));

AsyncValue<Insights> _goodDays([
  List<String> names = const ['Haferflocken', 'Reis', 'Karotte'],
]) => AsyncData(
  _insights(
    _unlocked,
    GoodDaysPick(
      DayColumn(
        days: 6,
        often: [for (final n in names) IngredientCount(n, 3, of: 6)],
      ),
    ),
  ),
);

final AsyncValue<Insights> _nothingYet = AsyncData(_insights(_unlocked));

const _nothingYetLine =
    'Noch fällt mir nichts Eindeutiges auf – trag weiter ein, dann sehe ich '
    'mehr.';

final _card = find.byKey(InsightCard.cardKey);

Future<void> _expectOpensPatterns(WidgetTester tester) async {
  await tester.tap(_card);
  await tester.pumpAndSettle();
  expect(find.text('page:${RoutePaths.patterns}'), findsOneWidget);
}

void main() {
  group('InsightCard', () {
    testWidgets('locked shows progress and opens Muster', (tester) async {
      await _pump(tester, _locked(2, 1));

      expect(_card, findsOneWidget);
      // Drawn in the uppercase label style.
      expect(
        find.text('Was ich über deinen Bauch lerne'.toUpperCase()),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(
        find.text('Noch 5 Tage, dann zeig ich dir erste Muster.'),
        findsOneWidget,
      );
      expect(find.text('Tage mit Einträgen'), findsOneWidget);
      expect(find.text('2 von 7'), findsOneWidget);
      expect(find.text('Bauchgefühl-Einträge'), findsOneWidget);
      expect(find.text('1 von 3'), findsOneWidget);
      expect(find.text('MUSTER ›'), findsOneWidget);
      // Nothing observed yet, so no finding to disclaim.
      expect(find.text('kein Befund'), findsNothing);

      await _expectOpensPatterns(tester);
    });

    testWidgets('locked: singular', (tester) async {
      await _pump(tester, _locked(6, 3));

      expect(
        find.text('Noch 1 Tag, dann zeig ich dir erste Muster.'),
        findsOneWidget,
      );
    });

    testWidgets('locked: days done, gut feelings missing', (tester) async {
      await _pump(tester, _locked(9, 1));
      expect(
        find.text(
          'Noch 2 Bauchgefühl-Einträge, dann zeig ich dir erste Muster.',
        ),
        findsOneWidget,
      );
      // The days bar is full and says so, not „9 von 7".
      expect(find.text('7 von 7'), findsOneWidget);

      await _pump(tester, _locked(9, 2));
      expect(
        find.text(
          'Noch 1 Bauchgefühl-Eintrag, dann zeig ich dir erste Muster.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('noticed pick', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _noticed());

      expect(find.text('FÄLLT MIR AUF'), findsOneWidget);
      expect(
        tester.getSemantics(_card).label,
        contains('Fällt mir auf'),
        reason: 'the header is read as written, not spelled in capitals',
      );
      expect(
        find.text('Zwiebel war an 4 von 5 schweren Tagen dabei.'),
        findsOneWidget,
      );
      expect(find.text('an guten Tagen: 1 von 6'), findsOneWidget);
      expect(find.text('kein Befund'), findsOneWidget);
      expect(find.text('MUSTER ›'), findsOneWidget);
      // Unlocked: no lock, no bars.
      expect(find.byIcon(Icons.lock_outline), findsNothing);
      expect(find.text('Tage mit Einträgen'), findsNothing);
      handle.dispose();

      await _expectOpensPatterns(tester);
    });

    testWidgets('noticed pick without good days', (tester) async {
      await _pump(
        tester,
        _noticed(
          const Noticed(
            name: 'Zwiebel',
            hard: 3,
            hardDays: 3,
            good: 0,
            goodDays: 0,
          ),
        ),
      );

      expect(find.text('an guten Tagen: noch keine'), findsOneWidget);
    });

    testWidgets('good-days pick', (tester) async {
      await _pump(tester, _goodDays());

      expect(find.text('DEINE GUTEN TAGE'), findsOneWidget);
      expect(
        find.text("An guten Tagen gab's oft Haferflocken, Reis und Karotte."),
        findsOneWidget,
      );
      expect(find.text('6 gute Tage in den letzten 30'), findsOneWidget);
      expect(find.text('kein Befund'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsNothing);

      await _expectOpensPatterns(tester);
    });

    testWidgets('nothing yet', (tester) async {
      await _pump(tester, _nothingYet);

      expect(
        find.text('Was ich über deinen Bauch lerne'.toUpperCase()),
        findsOneWidget,
      );
      expect(find.text(_nothingYetLine), findsOneWidget);
      expect(find.text('kein Befund'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsNothing);
      expect(find.text('Tage mit Einträgen'), findsNothing);

      await _expectOpensPatterns(tester);
    });

    testWidgets('hidden while loading, after an error without a value, and '
        'while reloading for another user', (tester) async {
      await _pump(tester, const AsyncLoading<Insights>());
      expect(_card, findsNothing);

      await _pump(
        tester,
        AsyncError<Insights>(Exception('offline'), StackTrace.empty),
      );
      expect(_card, findsNothing);

      // After a user change the state keeps the previous user's value while
      // the next user's insights load, and when that load fails.
      final previous = _noticed();
      await _pump(
        tester,
        const AsyncLoading<Insights>().copyWithPrevious(
          previous,
          isRefresh: false,
        ),
      );
      expect(_card, findsNothing);
      expect(find.textContaining('Zwiebel'), findsNothing);

      await _pump(
        tester,
        AsyncError<Insights>(
          Exception('offline'),
          StackTrace.empty,
        ).copyWithPrevious(previous),
      );
      expect(_card, findsNothing);
      expect(find.textContaining('Zwiebel'), findsNothing);
    });

    group('fits 375×667 at text scale 1.3', () {
      final states = <String, AsyncValue<Insights>>{
        'locked': _locked(2, 1),
        'locked, gut feelings missing': _locked(9, 1),
        'noticed': _noticed(
          const Noticed(
            name: 'Vollkornweizenbrot',
            hard: 12,
            hardDays: 14,
            good: 10,
            goodDays: 15,
          ),
        ),
        'good days': _goodDays([
          'Vollkornweizenbrot',
          'Haferflocken',
          'Süßkartoffel',
          'Kokosjoghurt',
          'Karotte',
        ]),
        'nothing yet': _nothingYet,
      };
      for (final MapEntry(key: name, value: insights) in states.entries) {
        testWidgets(name, (tester) async {
          tester.view.physicalSize = const Size(375, 667);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await _pump(tester, insights, textScale: 1.3);

          expect(_card, findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    });

    group('semantics', () {
      testWidgets('the card is a button „Muster ansehen" that reads its '
          'text', (tester) async {
        final handle = tester.ensureSemantics();
        await _pump(tester, _noticed());

        expect(
          tester.getSemantics(_card),
          isSemantics(
            label:
                'Muster ansehen\n'
                'Fällt mir auf\n'
                'Zwiebel war an 4 von 5 schweren Tagen dabei.\n'
                'an guten Tagen: 1 von 6\n'
                'kein Befund',
            isButton: true,
            hasTapAction: true,
          ),
        );
        handle.dispose();
      });

      testWidgets('locked: the bars read as one label each', (tester) async {
        final handle = tester.ensureSemantics();
        await _pump(tester, _locked(2, 1));

        expect(
          tester.getSemantics(_card),
          isSemantics(
            label:
                'Muster ansehen\n'
                'Was ich über deinen Bauch lerne\n'
                'Noch 5 Tage, dann zeig ich dir erste Muster.\n'
                'Tage mit Einträgen: 2 von 7\n'
                'Bauchgefühl-Einträge: 1 von 3',
            isButton: true,
            hasTapAction: true,
          ),
        );
        handle.dispose();
      });

      testWidgets('the semantic tap opens Muster', (tester) async {
        final handle = tester.ensureSemantics();
        await _pump(tester, _goodDays());

        tester.semantics.tap(find.semantics.byLabel(RegExp('^Muster ansehen')));
        await tester.pumpAndSettle();

        expect(find.text('page:${RoutePaths.patterns}'), findsOneWidget);
        handle.dispose();
      });
    });
  });
}
