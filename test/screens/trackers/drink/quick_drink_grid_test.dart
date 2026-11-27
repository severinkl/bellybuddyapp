// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/drink_tracker_provider.dart';
import 'package:belly_buddy/repositories/drink_repository.dart';
import 'package:belly_buddy/screens/trackers/drink/widgets/drink_glyph.dart';
import 'package:belly_buddy/screens/trackers/drink/widgets/drink_search.dart';
import 'package:belly_buddy/screens/trackers/drink/widgets/quick_drink_grid.dart';
import 'package:belly_buddy/utils/drink_helpers.dart';
import 'package:belly_buddy/widgets/common/dashed_border_painter.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/fixtures.dart';

final _six = [
  testDrink(),
  testDrink(id: 'tea', name: 'Pfefferminztee'),
  testDrink(id: 'coffee', name: 'Kaffee'),
  testDrink(id: 'juice', name: 'Apfelsaft gespritzt'),
  testDrink(id: 'oat', name: 'Hafermilch'),
  testDrink(id: 'mate', name: 'Mate'),
];

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  List<dynamic>? drinks,
  FakeDrinkRepository? repo,
  bool noLast = false,
  bool disableAnimations = false,
}) async {
  final fake = repo ?? FakeDrinkRepository()
    ..seedDrinks([...?drinks?.cast(), if (drinks == null) ..._six]);
  if (noLast) fake.lastEntry = null;
  final container = ProviderContainer.test(
    overrides: [
      drinkRepositoryProvider.overrideWithValue(fake as DrinkRepository),
      currentUserIdProvider.overrideWithValue('test-user'),
    ],
  );
  addTearDown(container.dispose);
  await container.read(drinkTrackerProvider.notifier).loadDrinks();
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.theme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: disableAnimations),
          child: child!,
        ),
        home: const Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: QuickDrinkGrid(),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return container;
}

BoxDecoration _decoration(WidgetTester tester, String id) =>
    tester
            .widget<AnimatedContainer>(
              find.descendant(
                of: find.byKey(QuickDrinkGrid.tileKey(id)),
                matching: find.byType(AnimatedContainer),
              ),
            )
            .decoration!
        as BoxDecoration;

void main() {
  group('QuickDrinkGrid', () {
    testWidgets('five drink tiles, Wasser first, then „Anderes suchen"', (
      tester,
    ) async {
      await _pump(tester);
      final tiles = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('drink_tile_'),
      );
      final keys = [
        for (final e in tiles.evaluate()) (e.widget.key! as ValueKey).value,
      ];
      expect(keys.length, 6);
      expect(keys.first, 'drink_tile_water-id');
      expect(keys.last, 'drink_tile_search');
      expect(find.text('Anderes suchen'), findsOneWidget);
      expect(find.byKey(QuickDrinkGrid.tileKey('mate')), findsNothing);
    });

    testWidgets('heading reads „Oder wähle aus" with a last entry, „Was?" '
        'without, and „Was?" once a drink is selected', (tester) async {
      final container = await _pump(tester);
      expect(find.text('Oder wähle aus'), findsOneWidget);
      await tester.tap(find.byKey(QuickDrinkGrid.tileKey('tea')));
      await tester.pump();
      expect(find.text('Was?'), findsOneWidget);
      expect(find.text('Oder wähle aus'), findsNothing);
      expect(container.read(drinkTrackerProvider).selectedDrink?.id, 'tea');
    });

    testWidgets('heading is „Was?" without a last entry', (tester) async {
      await _pump(tester, noLast: true);
      expect(find.text('Was?'), findsOneWidget);
      expect(find.text('Oder wähle aus'), findsNothing);
    });

    testWidgets('a tile shows the glyph for its name', (tester) async {
      await _pump(tester);
      final glyph = tester.widget<DrinkGlyph>(
        find.descendant(
          of: find.byKey(QuickDrinkGrid.tileKey('oat')),
          matching: find.byType(DrinkGlyph),
        ),
      );
      expect(glyph.icon, DrinkIcon.carton);
    });

    testWidgets('the selected tile: white fill, 2 px infoText border, '
        'infoText glyph, w600 name; tapping it again deselects', (
      tester,
    ) async {
      final container = await _pump(tester);
      await tester.tap(find.byKey(QuickDrinkGrid.tileKey('tea')));
      await tester.pump(AppConstants.animFast);

      final d = _decoration(tester, 'tea');
      expect(d.color, AppTheme.background);
      final border = d.border! as Border;
      expect(border.top.color, AppTheme.infoText);
      expect(border.top.width, 2);
      final tile = find.byKey(QuickDrinkGrid.tileKey('tea'));
      expect(
        tester
            .widget<DrinkGlyph>(
              find.descendant(of: tile, matching: find.byType(DrinkGlyph)),
            )
            .color,
        AppTheme.infoText,
      );
      expect(
        tester
            .widget<Text>(
              find.descendant(of: tile, matching: find.text('Pfefferminztee')),
            )
            .style
            ?.fontWeight,
        FontWeight.w600,
      );
      // Unselected: card fill, transparent border.
      final other = _decoration(tester, 'coffee');
      expect(other.color, AppTheme.card);
      expect((other.border! as Border).top.color, Colors.transparent);

      await tester.tap(tile);
      await tester.pump();
      expect(container.read(drinkTrackerProvider).selectedDrink, isNull);
    });

    testWidgets('tiles are a one-of group named by the full drink name', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      const longName = 'Hafer-Mandel-Kokos-Getränk ohne Zuckerzusatz';
      expect(longName.length, greaterThanOrEqualTo(40));
      await _pump(
        tester,
        drinks: [testDrink(id: 'long', name: longName)],
      );
      final text = tester.widget<Text>(
        find.descendant(
          of: find.byKey(QuickDrinkGrid.tileKey('long')),
          matching: find.text(longName),
          skipOffstage: false,
        ),
      );
      expect(text.maxLines, 2);
      expect(text.overflow, TextOverflow.ellipsis);
      expect(
        tester.getSemantics(find.byKey(QuickDrinkGrid.tileKey('long'))),
        isSemantics(
          label: longName,
          isButton: true,
          hasSelectedState: true,
          isSelected: false,
          isInMutuallyExclusiveGroup: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('„Anderes suchen" opens the focused search in place of the '
        'heading and reads as expanded', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester);
      expect(
        tester.getSemantics(find.byKey(QuickDrinkGrid.searchTileKey)),
        isSemantics(
          label: 'Anderes suchen',
          isButton: true,
          hasExpandedState: true,
          isExpanded: false,
          hasTapAction: true,
        ),
      );
      await tester.tap(find.byKey(QuickDrinkGrid.searchTileKey));
      await tester.pump();

      expect(find.byKey(DrinkSearch.searchFieldKey), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(DrinkSearch.searchFieldKey))
            .focusNode
            ?.hasFocus,
        isTrue,
      );
      expect(find.text('Oder wähle aus'), findsNothing);
      expect(find.text('Was?'), findsNothing);
      expect(
        tester.getSemantics(find.byKey(QuickDrinkGrid.searchTileKey)),
        isSemantics(
          label: 'Anderes suchen',
          isButton: true,
          hasExpandedState: true,
          isExpanded: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('tapping „Anderes suchen" again closes the search', (
      tester,
    ) async {
      final container = await _pump(tester);
      await tester.tap(find.byKey(QuickDrinkGrid.searchTileKey));
      await tester.pump();
      await tester.tap(find.byKey(QuickDrinkGrid.searchTileKey));
      await tester.pump();
      expect(container.read(drinkTrackerProvider).isSearchOpen, isFalse);
      expect(find.byKey(DrinkSearch.searchFieldKey), findsNothing);
      expect(find.text('Oder wähle aus'), findsOneWidget);
    });

    testWidgets('a drink picked in search closes it and becomes the selected '
        'fifth tile', (tester) async {
      await _pump(tester);
      await tester.tap(find.byKey(QuickDrinkGrid.searchTileKey));
      await tester.pump();
      await tester.enterText(find.byKey(DrinkSearch.searchFieldKey), 'Mate');
      await tester.pump();
      await tester.tap(
        find.descendant(
          of: find.byKey(DrinkSearch.suggestionsKey),
          matching: find.text('Mate'),
        ),
      );
      await tester.pump(AppConstants.animFast);

      expect(find.byKey(DrinkSearch.searchFieldKey), findsNothing);
      expect(
        (_decoration(tester, 'mate').border! as Border).top.color,
        AppTheme.infoText,
      );
      expect(find.byKey(QuickDrinkGrid.tileKey('oat')), findsNothing);
    });

    testWidgets('picking the already selected drink in search keeps it and '
        'its amount selected and closes the search', (tester) async {
      final container = await _pump(tester);
      await tester.tap(find.byKey(QuickDrinkGrid.tileKey('tea')));
      await tester.pump();
      container.read(drinkTrackerProvider.notifier).selectAmount(250);
      await tester.tap(find.byKey(QuickDrinkGrid.searchTileKey));
      await tester.pump();
      await tester.enterText(
        find.byKey(DrinkSearch.searchFieldKey),
        'Pfefferminz',
      );
      await tester.pump();
      await tester.tap(
        find.descendant(
          of: find.byKey(DrinkSearch.suggestionsKey),
          matching: find.text('Pfefferminztee'),
        ),
      );
      await tester.pump(AppConstants.animFast);

      final state = container.read(drinkTrackerProvider);
      expect(state.selectedDrink?.id, 'tea');
      expect(state.selectedAmount, 250);
      expect(state.isSearchOpen, isFalse);
      expect(find.byKey(DrinkSearch.searchFieldKey), findsNothing);
      expect(
        (_decoration(tester, 'tea').border! as Border).top.color,
        AppTheme.infoText,
      );
    });

    testWidgets('„„Zitronenwasser" hinzufügen" creates, selects and shows the '
        'new drink as a tile', (tester) async {
      await _pump(tester);
      await tester.tap(find.byKey(QuickDrinkGrid.searchTileKey));
      await tester.pump();
      await tester.enterText(
        find.byKey(DrinkSearch.searchFieldKey),
        'Zitronenwasser',
      );
      await tester.pump();
      await tester.tap(find.text('„Zitronenwasser" hinzufügen'));
      await tester.pump(AppConstants.animFast);

      expect(find.byKey(DrinkSearch.searchFieldKey), findsNothing);
      expect(
        (_decoration(tester, 'new-drink').border! as Border).top.color,
        AppTheme.infoText,
      );
      expect(find.text('Zitronenwasser'), findsOneWidget);
    });

    testWidgets('the dashed outline of „Anderes suchen" uses mutedForeground', (
      tester,
    ) async {
      await _pump(tester);
      final painter = tester
          .widgetList<CustomPaint>(
            find.descendant(
              of: find.byKey(QuickDrinkGrid.searchTileKey),
              matching: find.byType(CustomPaint),
            ),
          )
          .map((p) => p.foregroundPainter)
          .whereType<DashedBorderPainter>()
          .single;
      expect(painter.color, AppTheme.mutedForeground);
    });

    testWidgets('every tile is at least 84 px and at 200 % text the grid has '
        '2 columns without vertical overflow', (tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _pump(tester);
      final ids = ['water-id', 'tea', 'coffee', 'juice', 'oat'];
      for (final id in [...ids]) {
        final size = tester.getSize(find.byKey(QuickDrinkGrid.tileKey(id)));
        expect(size.height, greaterThanOrEqualTo(84));
      }
      expect(
        tester.getTopLeft(find.byKey(QuickDrinkGrid.tileKey('juice'))).dy,
        greaterThan(
          tester.getTopLeft(find.byKey(QuickDrinkGrid.tileKey('water-id'))).dy,
        ),
        reason: '3 columns: the fourth tile starts the second row',
      );

      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _pump(tester);
      final tops = {
        for (final id in ids)
          tester.getTopLeft(find.byKey(QuickDrinkGrid.tileKey(id))).dy,
      };
      expect(tops.length, 3, reason: '2 columns: 5 tiles + search = 3 rows');
      expect(
        tester.getTopLeft(find.byKey(QuickDrinkGrid.tileKey('tea'))).dy,
        tester.getTopLeft(find.byKey(QuickDrinkGrid.tileKey('water-id'))).dy,
      );
      expect(
        tester.getTopLeft(find.byKey(QuickDrinkGrid.tileKey('coffee'))).dy,
        greaterThan(
          tester.getTopLeft(find.byKey(QuickDrinkGrid.tileKey('tea'))).dy,
        ),
      );
      // Tiles in a row share the tallest one's height.
      expect(
        tester.getSize(find.byKey(QuickDrinkGrid.tileKey('water-id'))).height,
        tester.getSize(find.byKey(QuickDrinkGrid.tileKey('tea'))).height,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('with reduced motion the selection shows after one pump', (
      tester,
    ) async {
      await _pump(tester, disableAnimations: true);
      await tester.tap(find.byKey(QuickDrinkGrid.tileKey('tea')));
      await tester.pump();
      expect(
        (_decoration(tester, 'tea').border! as Border).top.color,
        AppTheme.infoText,
      );
    });
  });
}
