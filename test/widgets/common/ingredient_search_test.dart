import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/models/ingredient_search_result.dart';
import 'package:belly_buddy/widgets/common/ingredient_search.dart';

import '../../helpers/riverpod_helpers.dart';

IngredientSearchResult _result(String name) =>
    IngredientSearchResult(id: 'id-$name', name: name, isOwn: false);

/// Hosts an [IngredientSearch] whose suggestions answer each search with
/// the [catalog] names containing the query (in catalog order), like the
/// autocomplete provider does after its debounce.
class _Host extends StatefulWidget {
  const _Host({required this.catalog, required this.added, this.topSpace = 0});

  final List<String> catalog;
  final List<String> added;

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
                if (name.toLowerCase().contains(q)) _result(name),
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

  Future<void> pump(WidgetTester tester, {double topSpace = 0}) async {
    await tester.pumpWithProviders(
      _Host(catalog: catalog, added: added, topSpace: topSpace),
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

  testWidgets('Return on an exact catalog match adds the catalog name', (
    tester,
  ) async {
    await pump(tester);
    await type(tester, 'haferflocken');

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(added, ['Haferflocken']);
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
}
