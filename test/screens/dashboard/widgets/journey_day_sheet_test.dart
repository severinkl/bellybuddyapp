import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/models/insights.dart';
import 'package:belly_buddy/models/journey_rewards.dart';
import 'package:belly_buddy/providers/auth_provider.dart';
import 'package:belly_buddy/providers/insights_provider.dart';
import 'package:belly_buddy/repositories/recipe_repository.dart';
import 'package:belly_buddy/screens/dashboard/widgets/journey_day_sheet.dart';
import 'package:belly_buddy/screens/patterns/widgets/patterns_preview.dart';
import 'package:belly_buddy/screens/recipes/widgets/recipe_list_tile.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/fixtures.dart';
import '../../../helpers/layout_checks.dart';
import '../../../helpers/riverpod_helpers.dart';

const _userId = 'u1';

const _bowl = RecipePick(id: 'r-1', title: 'Hirse-Bowl');
const _soup = RecipePick(id: 'r-3', title: 'Kürbissuppe');
const _rice = RecipePick(
  id: 'r-5',
  title: 'Karotten-Reis',
  matched: ['Karotte', 'Reis'],
);

/// Every recipe day picked, day 3 a recipe.
const _allPicked = JourneyRewards(
  earnedDay: 6,
  picks: {1: _bowl, 3: _soup, 5: _rice},
  tipOffer: TipOffer.declined,
);

/// Insights loaded once ([_first], none: never); any later load never
/// ends.
class _ReloadingInsights extends InsightsNotifier {
  _ReloadingInsights(this._first);
  final Insights? _first;
  var _loads = 0;

  @override
  Future<Insights> build() {
    final first = _first;
    return _loads++ == 0 && first != null
        ? Future.value(first)
        : Completer<Insights>().future;
  }
}

void main() {
  /// A page whose „open" button opens [day]'s sheet over [rewards]; each
  /// result goes to [results]. The collection holds the three picks; the
  /// weekly tips are [weeklyTips]; [insights] are loaded unless
  /// [insightsNotifier] serves them.
  Future<void> pumpOpener(
    WidgetTester tester, {
    required int day,
    required JourneyRewards rewards,
    bool afterNo = false,
    List<bool>? results,
    Insights? insights,
    InsightsNotifier Function()? insightsNotifier,
    bool weeklyTips = false,
    Size size = const Size(390, 844),
    double textScale = 1,
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final recipes = FakeRecipeRepository()
      ..collection = [
        testRecipe(id: _bowl.id, title: _bowl.title),
        testRecipe(id: _soup.id, title: _soup.title),
        testRecipe(
          id: _rice.id,
          title: _rice.title,
          ingredients: [testLine('Karotte'), testLine('Reis')],
        ),
      ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue(_userId),
          profileProviderSeededWith(
            testUserProfile(userId: _userId, weeklyTipsEnabled: weeklyTips),
          ),
          recipeRepositoryProvider.overrideWithValue(recipes),
          journeyRewardsSeededWith(rewards),
          if (insightsNotifier != null)
            insightsProvider.overrideWith(insightsNotifier)
          else
            insightsProviderSeededWith(
              insights ?? lockedInsights(activeDays: day, gutFeelings: 3),
            ),
        ],
        child: MaterialApp(
          theme: AppTheme.theme,
          home: Scaffold(
            body: Builder(
              builder: (c) => TextButton(
                onPressed: () async {
                  final opened = await showJourneyDaySheet(
                    c,
                    day: day,
                    afterNo: afterNo,
                  );
                  results?.add(opened);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Finder primary(String label) => find.descendant(
    of: find.byKey(JourneyDaySheet.primaryKey),
    matching: find.text(label),
  );
  final later = find.descendant(
    of: find.byKey(JourneyDaySheet.laterKey),
    matching: find.text('Später'),
  );

  /// The recipe tile showing [title].
  Finder tileOf(String title) => find.descendant(
    of: find.byType(RecipeListTile),
    matching: find.text(title),
  );

  Future<void> tapAndClose(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('day 1 with a pick: line, the recipe tile, „Rezept ansehen" '
      '→ true', (tester) async {
    final results = <bool>[];
    await pumpOpener(
      tester,
      day: 1,
      rewards: const JourneyRewards(earnedDay: 1, picks: {1: _bowl}),
      results: results,
    );

    expect(
      find.text('Willkommen an Tag 1! Hier ist dein erstes Rezept für dich.'),
      findsOneWidget,
    );
    expect(tileOf('Hirse-Bowl'), findsOneWidget);
    expect(primary('Rezept ansehen'), findsOneWidget);
    expect(later, findsOneWidget);

    await tapAndClose(tester, find.byKey(JourneyDaySheet.primaryKey));
    expect(results, [true]);
    expect(find.byType(JourneyDaySheet), findsNothing);
  });

  testWidgets('day 1: the tile opens it too; „Später" and a dismissal → '
      'false', (tester) async {
    final results = <bool>[];
    await pumpOpener(
      tester,
      day: 1,
      rewards: const JourneyRewards(earnedDay: 1, picks: {1: _bowl}),
      results: results,
    );
    await tapAndClose(tester, tileOf('Hirse-Bowl'));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tapAndClose(tester, find.byKey(JourneyDaySheet.laterKey));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10)); // the modal barrier
    await tester.pumpAndSettle();

    expect(results, [true, false, false]);
  });

  testWidgets('day 1 without a pick: noRecipe and „Zu den Rezepten"', (
    tester,
  ) async {
    await pumpOpener(
      tester,
      day: 1,
      rewards: const JourneyRewards(earnedDay: 1),
    );

    expect(
      find.text('Rezepte, die zu dir passen, findest du unter Entdecken.'),
      findsOneWidget,
    );
    expect(find.byType(RecipeListTile), findsNothing);
    expect(primary('Zu den Rezepten'), findsOneWidget);
    expect(later, findsOneWidget);
  });

  testWidgets('a pick no longer in the collection: its title, „Rezept '
      'ansehen"', (tester) async {
    final results = <bool>[];
    await pumpOpener(
      tester,
      day: 1,
      rewards: const JourneyRewards(
        earnedDay: 1,
        picks: {1: RecipePick(id: 'gone', title: 'Altes Rezept')},
      ),
      results: results,
    );

    expect(find.byType(RecipeListTile), findsNothing);
    expect(find.text('Altes Rezept'), findsOneWidget);
    expect(primary('Rezept ansehen'), findsOneWidget);

    await tapAndClose(tester, find.text('Altes Rezept'));
    expect(results, [true]);
  });

  testWidgets('day 2: the article title and source', (tester) async {
    final results = <bool>[];
    await pumpOpener(
      tester,
      day: 2,
      rewards: const JourneyRewards(earnedDay: 2),
      results: results,
    );

    expect(
      find.text('Tag 2! Hier ist ein Wissen-Häppchen für dich.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'FODMAPs sind bestimmte Kohlenhydrate in Lebensmitteln. Was '
        'dahintersteckt, erklärt dieser Artikel kurz und knackig.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Low FODMAP kurz und knackig · myfodmap.at'),
      findsOneWidget,
    );
    expect(primary('Artikel lesen'), findsOneWidget);
    expect(later, findsOneWidget);

    await tapAndClose(tester, find.byKey(JourneyDaySheet.primaryKey));
    expect(results, [true]);
  });

  testWidgets('day 3: day3Line and its recipe', (tester) async {
    await pumpOpener(tester, day: 3, rewards: _allPicked);

    expect(find.text('Tag 3! Hier ist ein Rezept für dich.'), findsOneWidget);
    expect(tileOf('Kürbissuppe'), findsOneWidget);
    expect(primary('Rezept ansehen'), findsOneWidget);
  });

  testWidgets('day 3 after no: day3AfterNoLine', (tester) async {
    await pumpOpener(tester, day: 3, afterNo: true, rewards: _allPicked);

    expect(
      find.text('Alles klar! Dann hier ein Rezept für dich.'),
      findsOneWidget,
    );
    expect(tileOf('Kürbissuppe'), findsOneWidget);
    expect(primary('Rezept ansehen'), findsOneWidget);
    expect(later, findsOneWidget);
  });

  testWidgets('day 3 accepted: never the stored recipe; „Zu deinen Tipps"', (
    tester,
  ) async {
    final results = <bool>[];
    await pumpOpener(
      tester,
      day: 3,
      rewards: _allPicked.copyWith(tipOffer: TipOffer.accepted),
      results: results,
    );

    expect(find.text("Tag 3! Hier geht's zu deinen Tipps."), findsOneWidget);
    expect(find.text('Kürbissuppe'), findsNothing);
    expect(find.byType(RecipeListTile), findsNothing);
    expect(primary('Zu deinen Tipps'), findsOneWidget);

    await tapAndClose(tester, find.byKey(JourneyDaySheet.primaryKey));
    expect(results, [true]);
  });

  testWidgets('day 3 while the offer waits: the tip, never the stored '
      'recipe', (tester) async {
    for (final offer in [TipOffer.offered, null]) {
      await tester.pumpWidget(const SizedBox());
      await pumpOpener(
        tester,
        day: 3,
        // Built anew: copyWith can't clear the offer.
        rewards: JourneyRewards(
          earnedDay: 6,
          picks: _allPicked.picks,
          tipOffer: offer,
        ),
      );

      expect(
        find.text("Tag 3! Hier geht's zu deinen Tipps."),
        findsOneWidget,
        reason: '$offer',
      );
      expect(find.text('Kürbissuppe'), findsNothing, reason: '$offer');
      expect(primary('Zu deinen Tipps'), findsOneWidget, reason: '$offer');
    }
  });

  testWidgets('day 3 while the offer waits, with the weekly tips on: the '
      'recipe', (tester) async {
    await pumpOpener(
      tester,
      day: 3,
      rewards: _allPicked.copyWith(tipOffer: TipOffer.offered),
      weeklyTips: true,
    );

    expect(find.text('Tag 3! Hier ist ein Rezept für dich.'), findsOneWidget);
    expect(tileOf('Kürbissuppe'), findsOneWidget);
  });

  testWidgets('day 4: the user\'s saying, „Danke!" → false', (tester) async {
    final results = <bool>[];
    await pumpOpener(
      tester,
      day: 4,
      rewards: const JourneyRewards(earnedDay: 4),
      results: results,
    );

    // 'u1': (117 + 49) % 6 = 4.
    expect(
      find.text('Du machst das super. Ich bin gern dabei.'),
      findsOneWidget,
    );
    expect(primary('Danke!'), findsOneWidget);
    expect(find.byKey(JourneyDaySheet.laterKey), findsNothing);

    await tapAndClose(tester, find.byKey(JourneyDaySheet.primaryKey));
    expect(results, [false]);
  });

  testWidgets('day 5 matched: „Mit Karotte und Reis: Die hast du an Tagen '
      'ohne schlechtes Bauchgefühl gegessen."', (tester) async {
    await pumpOpener(tester, day: 5, rewards: _allPicked);

    expect(
      find.text(
        'Tag 5! Hier ist ein Rezept mit Zutaten, die du schon gegessen hast.',
      ),
      findsOneWidget,
    );
    expect(tileOf('Karotten-Reis'), findsOneWidget);
    expect(
      find.text(
        'Mit Karotte und Reis: Die hast du an Tagen ohne schlechtes '
        'Bauchgefühl gegessen.',
      ),
      findsOneWidget,
    );
    // Below the recipe.
    expect(
      tester.getTopLeft(find.textContaining('Mit Karotte und Reis')).dy,
      greaterThan(tester.getBottomLeft(find.byType(RecipeListTile)).dy),
    );
    expect(primary('Rezept ansehen'), findsOneWidget);
    expect(later, findsOneWidget);
  });

  testWidgets('day 5 generic: day5GenericLine, no caption', (tester) async {
    await pumpOpener(
      tester,
      day: 5,
      rewards: _allPicked.copyWith(
        picks: const {
          1: _bowl,
          3: _soup,
          5: RecipePick(id: 'r-5', title: 'Karotten-Reis'),
        },
      ),
    );

    expect(
      find.text('Tag 5! Hier ist noch ein Rezept, das zu dir passt.'),
      findsOneWidget,
    );
    expect(tileOf('Karotten-Reis'), findsOneWidget);
    expect(find.textContaining('Die hast du an Tagen'), findsNothing);
  });

  testWidgets('day 5 without a pick: noRecipe', (tester) async {
    await pumpOpener(
      tester,
      day: 5,
      rewards: const JourneyRewards(earnedDay: 5, picks: {1: _bowl}),
    );

    expect(
      find.text('Rezepte, die zu dir passen, findest du unter Entdecken.'),
      findsOneWidget,
    );
    expect(find.byType(RecipeListTile), findsNothing);
    expect(primary('Zu den Rezepten'), findsOneWidget);
  });

  testWidgets('day 6 with one Bauchgefühl missing: „Noch ein Tag und 1× '
      'Bauchgefühl, …", „Beispiel", the preview', (tester) async {
    final results = <bool>[];
    await pumpOpener(
      tester,
      day: 6,
      rewards: _allPicked,
      insights: lockedInsights(activeDays: 6, gutFeelings: 2),
      results: results,
    );

    expect(
      find.text(
        'Noch ein Tag und 1× Bauchgefühl, dann schau ich nach deinen ersten '
        'Mustern.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'So sieht die Muster-Seite dann aus, hier mit ausgedachten Werten:',
      ),
      findsOneWidget,
    );
    expect(find.text('BEISPIEL'), findsOneWidget);
    expect(find.byType(PatternsPreview), findsOneWidget);
    expect(primary('Okay'), findsOneWidget);
    expect(find.byKey(JourneyDaySheet.laterKey), findsNothing);

    await tapAndClose(tester, find.byKey(JourneyDaySheet.primaryKey));
    expect(results, [false]);
  });

  testWidgets('day 6 with every Bauchgefühl there: no count', (tester) async {
    await pumpOpener(
      tester,
      day: 6,
      rewards: _allPicked,
      insights: lockedInsights(activeDays: 6, gutFeelings: 3),
    );

    expect(
      find.text('Noch ein Tag, dann schau ich nach deinen ersten Mustern.'),
      findsOneWidget,
    );
  });

  testWidgets('day 6 while the insights reload: the last known count', (
    tester,
  ) async {
    await pumpOpener(
      tester,
      day: 6,
      rewards: _allPicked,
      insightsNotifier: () =>
          _ReloadingInsights(lockedInsights(activeDays: 6, gutFeelings: 2)),
    );
    const counted =
        'Noch ein Tag und 1× Bauchgefühl, dann schau ich nach deinen ersten '
        'Mustern.';
    expect(find.text(counted), findsOneWidget);

    ProviderScope.containerOf(
      tester.element(find.byType(JourneyDaySheet)),
    ).invalidate(insightsProvider);
    await tester.pumpAndSettle();

    expect(find.text(counted), findsOneWidget);
    expect(find.textContaining('Noch ein Tag, dann'), findsNothing);
  });

  testWidgets('day 6 with no insights at all: no count', (tester) async {
    await pumpOpener(
      tester,
      day: 6,
      rewards: _allPicked,
      insightsNotifier: () => _ReloadingInsights(null),
    );

    expect(
      find.text('Noch ein Tag, dann schau ich nach deinen ersten Mustern.'),
      findsOneWidget,
    );
  });

  testWidgets("each day's buttons on screen at 375×667 @1.3", (tester) async {
    for (var day = 1; day <= 6; day++) {
      // A fresh app per day.
      await tester.pumpWidget(const SizedBox());
      final errors = await collectFlutterErrors(
        () => pumpOpener(
          tester,
          day: day,
          rewards: _allPicked,
          insights: lockedInsights(activeDays: 6, gutFeelings: 2),
          size: const Size(375, 667),
          textScale: 1.3,
        ),
      );

      expect(verticalOverflows(errors), isEmpty, reason: 'day $day');
      expect(
        errors.where((e) => !e.contains('overflowed')),
        isEmpty,
        reason: 'day $day',
      );
      // Without scrolling: as the sheet opened.
      for (final key in [
        JourneyDaySheet.primaryKey,
        JourneyDaySheet.laterKey,
      ]) {
        final button = find.byKey(key);
        if (key == JourneyDaySheet.laterKey && (day == 4 || day == 6)) {
          expect(button, findsNothing, reason: 'day $day');
          continue;
        }
        final rect = tester.getRect(button);
        expect(rect.top, greaterThanOrEqualTo(0), reason: 'day $day');
        expect(rect.bottom, lessThanOrEqualTo(667), reason: 'day $day');
      }
    }
  });
}
