// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/drink_tracker_provider.dart';
import 'package:belly_buddy/repositories/drink_repository.dart';
import 'package:belly_buddy/screens/trackers/drink/widgets/drink_glyph.dart';
import 'package:belly_buddy/screens/trackers/drink/widgets/drink_size_selector.dart';
import 'package:belly_buddy/utils/drink_helpers.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/fixtures.dart';

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  bool withDrink = true,
  double textScale = 1,
  Size size = const Size(393, 852),
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer.test(
    overrides: [
      drinkRepositoryProvider.overrideWithValue(
        FakeDrinkRepository() as DrinkRepository,
      ),
      currentUserIdProvider.overrideWithValue('test-user'),
    ],
  );
  addTearDown(container.dispose);
  if (withDrink) {
    container.read(drinkTrackerProvider.notifier).toggleDrink(testDrink());
  }
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.theme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: DrinkSizeSelector(),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return container;
}

Finder _vessel(int ml) => find.byKey(DrinkSizeSelector.vesselKey(ml));
const _hint = 'Wähle zuerst ein Getränk.';

TextStyle _style(WidgetTester t, Finder f) => t.widget<Text>(f).style!;

void main() {
  testWidgets('without a drink the vessels are disabled and say why', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, withDrink: false);

    expect(
      tester.getSemantics(_vessel(250)),
      isSemantics(
        label: 'Glas, 250 ml',
        hint: _hint,
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
        hasSelectedState: true,
        isSelected: false,
        isInMutuallyExclusiveGroup: true,
      ),
    );
    expect(find.text(_hint), findsOneWidget);
    expect(find.byKey(DrinkSizeSelector.customAmountKey), findsNothing);
    expect(
      _style(tester, find.text('Wie viel?')).color,
      AppTheme.mutedForeground,
    );
    expect(_style(tester, find.text('250 ml')).color, AppTheme.mutedForeground);
    final glyph = tester.widget<CustomPaint>(
      find.descendant(
        of: _vessel(250),
        matching: find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is DrinkGlyphPainter,
        ),
      ),
    );
    expect(
      (glyph.painter! as DrinkGlyphPainter).color,
      AppTheme.mutedForeground,
    );
    for (final t in tester.widgetList<Text>(find.byType(Text))) {
      expect(
        find.ancestor(of: find.byWidget(t), matching: find.byType(Opacity)),
        findsNothing,
      );
    }
    // The visible hint is not read a second time.
    expect(
      find.ancestor(
        of: find.text(_hint),
        matching: find.byType(ExcludeSemantics),
      ),
      findsWidgets,
    );
    // A tap does nothing.
    await tester.tap(_vessel(250), warnIfMissed: false);
    expect(tester.takeException(), isNull);
    handle.dispose();
  });

  testWidgets('with a drink the four vessels read Glas, Dose, Flasche, Große '
      'with 250 ml, 330 ml, 500 ml, 1 l', (tester) async {
    await _pump(tester);
    for (final v in DrinkVessel.values) {
      expect(
        find.descendant(of: _vessel(v.ml), matching: find.text(v.label)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _vessel(v.ml),
          matching: find.text(DrinkHelpers.formatAmount(v.ml)),
        ),
        findsOneWidget,
      );
    }
    expect(find.text('1 l'), findsOneWidget);
    expect(find.text(_hint), findsNothing);
    expect(_style(tester, find.text('Wie viel?')).color, AppTheme.foreground);
    expect(find.byKey(DrinkSizeSelector.customAmountKey), findsOneWidget);
  });

  testWidgets('a vessel tap selects it (white, infoText border) and sets '
      'selectedAmount', (tester) async {
    final container = await _pump(tester);
    await tester.tap(_vessel(330));
    await tester.pump(const Duration(milliseconds: 300));

    expect(container.read(drinkTrackerProvider).selectedAmount, 330);
    BoxDecoration deco(int ml) =>
        tester
                .widget<AnimatedContainer>(
                  find.descendant(
                    of: _vessel(ml),
                    matching: find.byType(AnimatedContainer),
                  ),
                )
                .decoration!
            as BoxDecoration;
    expect(deco(330).color, AppTheme.background);
    expect((deco(330).border! as Border).top.color, AppTheme.infoText);
    expect(deco(250).color, AppTheme.card);
    expect(find.text(_hint), findsNothing);
  });

  testWidgets('typing in „Andere Menge" clears the vessel; a vessel tap '
      'clears the field', (tester) async {
    final container = await _pump(tester);
    await tester.tap(_vessel(500));
    await tester.pump();
    final field = find.byKey(DrinkSizeSelector.customAmountKey);

    await tester.enterText(field, '300');
    await tester.pump(const Duration(milliseconds: 300));
    final state = container.read(drinkTrackerProvider);
    expect(state.selectedAmount, 300);
    final deco =
        tester
                .widget<AnimatedContainer>(
                  find.descendant(
                    of: _vessel(500),
                    matching: find.byType(AnimatedContainer),
                  ),
                )
                .decoration!
            as BoxDecoration;
    expect(deco.color, AppTheme.card);

    await tester.tap(_vessel(250));
    await tester.pump();
    expect(tester.widget<TextField>(field).controller!.text, '');
    expect(container.read(drinkTrackerProvider).selectedAmount, 250);
  });

  testWidgets('„Andere Menge" refuses 99999 and accepts 3000', (tester) async {
    final container = await _pump(tester);
    final field = find.byKey(DrinkSizeSelector.customAmountKey);

    await tester.enterText(field, '99999');
    await tester.pump();
    expect(find.text('Bitte gib 1 bis 3000 ml ein.'), findsOneWidget);
    expect(container.read(drinkTrackerProvider).selectedAmount, isNull);

    await tester.enterText(field, '3000');
    await tester.pump();
    expect(find.text('Bitte gib 1 bis 3000 ml ein.'), findsNothing);
    expect(container.read(drinkTrackerProvider).selectedAmount, 3000);
  });

  testWidgets('the field is named „Andere Menge in ml" with „300" entered '
      'and shows „ml" inside', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);
    final field = find.byKey(DrinkSizeSelector.customAmountKey);
    await tester.enterText(field, '300');
    await tester.pump();

    final node = tester.getSemantics(field);
    expect(node.label, contains('Andere Menge in ml'));
    expect(node, isSemantics(isTextField: true, value: '300'));
    expect(
      find.descendant(of: find.byType(TextField), matching: find.text('ml')),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('vessel glyphs grow: heights 28 < 34 < 40 < 46', (tester) async {
    await _pump(tester);
    final heights = [
      for (final v in DrinkVessel.values)
        tester
            .getSize(
              find.descendant(
                of: _vessel(v.ml),
                matching: find.byWidgetPredicate(
                  (w) => w is CustomPaint && w.painter is DrinkGlyphPainter,
                ),
              ),
            )
            .height,
    ];
    expect(heights, [28, 34, 40, 46]);
  });

  testWidgets('at 200 % text the vessels use 2 columns without vertical '
      'overflow', (tester) async {
    await _pump(tester, textScale: 2);
    expect(tester.takeException(), isNull);
    expect(
      tester.getTopLeft(_vessel(250)).dy,
      tester.getTopLeft(_vessel(330)).dy,
    );
    expect(
      tester.getTopLeft(_vessel(500)).dy,
      greaterThan(tester.getTopLeft(_vessel(250)).dy),
    );
  });
}
