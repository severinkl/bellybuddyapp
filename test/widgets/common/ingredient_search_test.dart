import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/models/ingredient_search_result.dart';
import 'package:belly_buddy/widgets/common/ingredient_search.dart';

import '../../helpers/riverpod_helpers.dart';
import '../../helpers/semantics_checks.dart';

IngredientSearchResult _result(
  String name, {
  String? matchedName,
  bool isOwn = false,
}) => IngredientSearchResult(
  id: 'id-$name',
  name: name,
  matchedName: matchedName ?? name,
  isOwn: isOwn,
);

/// Hosts an [IngredientSearch] whose suggestions answer each search with
/// the [catalog] names containing the query (in catalog order), like the
/// autocomplete provider does after its debounce.
class _Host extends StatefulWidget {
  const _Host({
    required this.catalog,
    required this.added,
    this.topSpace = 0,
    this.own = const {},
    this.synonyms = const {},
  });

  final List<String> catalog;

  /// The [catalog] names that are the user's own ingredients.
  final Set<String> own;
  final List<String> added;

  /// Other names of [catalog] names (matched name -> name).
  final Map<String, String> synonyms;

  /// Room above the search, so it sits low on the screen.
  final double topSpace;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  List<IngredientSearchResult> _suggestions = const [];

  void _search(String query) {
    final q = query.toLowerCase();
    setState(() {
      _suggestions = q.length < 3
          ? const []
          : [
              for (final name in widget.catalog)
                if (name.toLowerCase().contains(q))
                  _result(name, isOwn: widget.own.contains(name)),
              for (final e in widget.synonyms.entries)
                if (e.key.toLowerCase().contains(q))
                  _result(e.value, matchedName: e.key),
            ];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: widget.topSpace),
            IngredientSearch(
              ingredients: widget.added,
              suggestions: _suggestions,
              onSearch: _search,
              onAdd: (name) => setState(() => widget.added.add(name)),
              onRemove: (_) {},
              onDeleteIngredient: (_) {},
            ),
            // Like the meal tracker's buttons below the card.
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }
}

void main() {
  const catalog = ['Haferkleie', 'Haferflocken', 'glutenfreie Haferflocken'];
  late List<String> added;

  setUp(() => added = []);

  Finder field() => find.descendant(
    of: find.byType(IngredientSearch),
    matching: find.byType(TextField),
  );

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(field(), text);
    // The widget's search debounce.
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
  }

  Future<void> pump(
    WidgetTester tester, {
    double topSpace = 0,
    Map<String, String> synonyms = const {},
  }) async {
    await tester.pumpWithProviders(
      _Host(
        catalog: catalog,
        added: added,
        topSpace: topSpace,
        synonyms: synonyms,
      ),
    );
    await tester.tap(find.text('+ Hinzufügen'));
    await tester.pumpAndSettle();
  }

  testWidgets('offers „X" hinzufügen for a name not in the catalog', (
    tester,
  ) async {
    await pump(tester);
    await type(tester, 'Hafer');

    expect(find.widgetWithText(ListTile, 'Haferflocken'), findsOneWidget);
    final addTyped = find.byKey(IngredientSearch.addTypedKey);
    expect(addTyped, findsOneWidget);
    expect(
      find.descendant(of: addTyped, matching: find.text('„Hafer“ hinzufügen')),
      findsOneWidget,
    );

    await tester.tap(addTyped);
    await tester.pumpAndSettle();

    expect(added, ['Hafer']);
  });

  testWidgets('ranks by matchedName and keeps the picked word', (tester) async {
    await pump(tester, synonyms: const {'Paradeiser': 'Tomate'});
    await type(tester, 'parad');

    final row = find.widgetWithText(ListTile, 'Paradeiser');
    expect(row, findsOneWidget);
    expect(
      find.descendant(of: row, matching: find.text('= Tomate')),
      findsOneWidget,
    );

    await tester.tap(row);
    await tester.pumpAndSettle();

    // The chip keeps the word the user picked.
    expect(added, ['Paradeiser']);
    expect(find.widgetWithText(Chip, 'Paradeiser'), findsOneWidget);
  });

  testWidgets('no second line when the matched name is the name', (
    tester,
  ) async {
    await pump(tester, synonyms: const {'haferkleie ': 'Haferkleie'});
    await type(tester, 'haferk');

    expect(find.textContaining('='), findsNothing);
  });

  testWidgets('the row reads „Paradeiser, auch Tomate"', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, synonyms: const {'Paradeiser': 'Tomate'});
    await type(tester, 'parad');

    expect(find.bySemanticsLabel('Paradeiser, auch Tomate'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    handle.dispose();
  });

  testWidgets('a short name like „Ei" can be added too', (tester) async {
    await pump(tester);
    await type(tester, 'Ei');

    await tester.tap(find.byKey(IngredientSearch.addTypedKey));
    await tester.pumpAndSettle();

    expect(added, ['Ei']);
  });

  testWidgets('no „X" hinzufügen row when the catalog has the name', (
    tester,
  ) async {
    await pump(tester);
    await type(tester, 'haferflocken');

    expect(find.byKey(IngredientSearch.addTypedKey), findsNothing);
    expect(find.widgetWithText(ListTile, 'Haferflocken'), findsOneWidget);
  });

  testWidgets('Return does not add the typed text silently', (tester) async {
    await pump(tester);
    await type(tester, 'Hafer');

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(added, isEmpty);
    // Still there to pick from, keyboard included.
    expect(field(), findsOneWidget);
    expect(find.byKey(IngredientSearch.addTypedKey), findsOneWidget);
  });

  testWidgets('Return without an exact match says how to add the name; '
      'typing on clears the hint', (tester) async {
    await pump(tester);
    await type(tester, 'Hafer');

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    const hint = 'Tippe auf „‚Hafer‘ hinzufügen“.';
    expect(find.text(hint), findsOneWidget);
    expect(added, isEmpty);

    await type(tester, 'Haferk');
    expect(find.textContaining('Tippe auf'), findsNothing);
  });

  testWidgets('Return on an exact catalog match adds the catalog name', (
    tester,
  ) async {
    await pump(tester);
    await type(tester, 'haferflocken');

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(added, ['Haferflocken']);
  });

  testWidgets('Return before the search answered adds the exact match once '
      'it arrives', (tester) async {
    await pump(tester);
    await tester.enterText(field(), 'Haferflocken');
    // Return right away, inside the search debounce.
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(added, ['Haferflocken']);
  });

  testWidgets('Return before the search answered adds nothing without an '
      'exact match', (tester) async {
    await pump(tester);
    await tester.enterText(field(), 'Hafer');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(added, isEmpty);
    expect(find.byKey(IngredientSearch.addTypedKey), findsOneWidget);
  });

  testWidgets('leaving the field does not add the typed text', (tester) async {
    await pump(tester);
    await type(tester, 'Hafer');

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    expect(added, isEmpty);
  });

  testWidgets('the suggestions scroll into view above the keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pump(tester, topSpace: 600);

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    await type(tester, 'Hafer');

    final addTyped = find.byKey(IngredientSearch.addTypedKey);
    expect(addTyped.hitTestable(), findsOneWidget);
    expect(tester.getRect(addTyped).bottom, lessThanOrEqualTo(800 - 300));
  });

  testWidgets('the ingredient search ✕ is „Suche schließen", 48 × 48; an own '
      'ingredient\'s delete is „Zutat löschen"', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWithProviders(
      _Host(catalog: catalog, added: added, own: const {'Haferkleie'}),
    );
    await tester.tap(find.text('+ Hinzufügen'));
    await tester.pumpAndSettle();
    await type(tester, 'Hafer');

    final close = find.bySemanticsLabel('Suche schließen');
    expect(close, findsOneWidget);
    expect(tester.getSize(close), const Size(48, 48));
    expect(
      find.semantics
          .byLabel('Suche schließen')
          .evaluate()
          .single
          .isMergedIntoParent,
      isFalse,
    );
    expect(find.byTooltip('Zutat löschen'), findsOneWidget);

    // The field keeps its name with text in it, beside its own ✕.
    expect(
      tester.getSemantics(find.byType(EditableText)).getSemanticsData().label,
      contains('Zutat suchen'),
    );

    tester.semantics.tap(find.semantics.byLabel('Suche schließen'));
    await tester.pumpAndSettle();
    expect(field(), findsNothing);
    handle.dispose();
  });

  testWidgets('while empty, „Zutat suchen" is read once, with an example', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWithProviders(_Host(catalog: catalog, added: added));
    await tester.tap(find.text('+ Hinzufügen'));
    await tester.pumpAndSettle();

    expectSearchFieldReadOnce(
      tester,
      name: 'Zutat suchen',
      example: 'z. B. Haferflocken',
    );
    // The scroll to the field waits for the keyboard.
    await tester.pump(const Duration(seconds: 1));
    handle.dispose();
  });

  testWidgets('„+ Hinzufügen" is at least 48 high', (tester) async {
    await tester.pumpWithProviders(_Host(catalog: catalog, added: added));

    final add = find.ancestor(
      of: find.text('+ Hinzufügen'),
      matching: find.byType(GestureDetector),
    );
    expect(tester.getSize(add.first).height, greaterThanOrEqualTo(48));
  });

  testWidgets('„+ Hinzufügen" is one button „Zutat hinzufügen" that opens '
      'the search', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWithProviders(_Host(catalog: catalog, added: added));

    final add = find.semantics.byLabel('Zutat hinzufügen');
    expect(add, findsOne);
    expect(find.semantics.byLabel('+ Hinzufügen'), findsNothing);
    expect(
      tester.getSemantics(find.text('+ Hinzufügen')),
      isSemantics(
        label: 'Zutat hinzufügen',
        isButton: true,
        hasTapAction: true,
      ),
    );
    tester.semantics.tap(add);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    // The scroll to the field waits for the keyboard.
    await tester.pump(const Duration(seconds: 1));
    handle.dispose();
  });
}
