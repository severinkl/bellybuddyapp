// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:riverpod/src/internals.dart' show Override;

import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/models/alternative_choice.dart';
import 'package:belly_buddy/models/ingredient_suggestion_group.dart';
import 'package:belly_buddy/models/ranked_replacement.dart';
import 'package:belly_buddy/models/replacement_ingredient.dart';
import 'package:belly_buddy/providers/alternative_choices_provider.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/ingredient_suggestion_provider.dart';
import 'package:belly_buddy/repositories/ingredient_repository.dart';
import 'package:belly_buddy/screens/ingredient_suggestions/widgets/alternative_feedback_sheet.dart';
import 'package:belly_buddy/screens/ingredient_suggestions/widgets/suggestion_detail_modal.dart';
import 'package:belly_buddy/services/alternative_choice_service.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/purchases_fakes.dart';

const _names = {
  'r-lauch': 'Lauch',
  'r-schnitt': 'Schnittlauch',
  'r-ing': 'Ingwer',
};

Map<String, dynamic> _row(String id, String replacementId, String choice) => {
  'id': id,
  'ingredient_id': 'ing-zwiebel',
  'replacement_ingredient_id': replacementId,
  'choice': choice,
  'created_at': '2026-11-26T10:00:00Z',
  'ingredient': {'name': 'Zwiebel'},
  'replacement': {'name': _names[replacementId]},
};

class _Service implements AlternativeChoiceService {
  _Service([List<Map<String, dynamic>>? rows]) : rows = rows ?? [];
  final List<Map<String, dynamic>> rows;
  bool fail = false;
  int _ids = 0;
  final writes = <String>[];

  @override
  Future<List<Map<String, dynamic>>> fetch(String userId) async => rows;

  @override
  Future<Map<String, dynamic>> upsert({
    required String userId,
    required String ingredientId,
    required String replacementId,
    required AlternativeChoiceKind kind,
  }) async {
    writes.add('${kind.db} $replacementId');
    if (fail) throw Exception('offline');
    return _row('c-${_ids++}', replacementId, kind.db);
  }

  @override
  Future<void> delete(String id) async {
    writes.add('delete $id');
    if (fail) throw Exception('offline');
  }
}

final _zwiebel = IngredientSuggestionGroup(
  ingredientId: 'ing-zwiebel',
  ingredientName: 'Zwiebel',
  mealCount: 1,
  isNew: false,
  suggestionIds: const ['s1'],
  replacements: RankedReplacement.inOrder(const [
    ReplacementIngredient(id: 'r-lauch', name: 'Lauch'),
    ReplacementIngredient(id: 'r-schnitt', name: 'Schnittlauch'),
    ReplacementIngredient(id: 'r-ing', name: 'Ingwer'),
  ]),
);

void main() {
  Future<_Service> pump(
    WidgetTester tester, {
    _Service? service,
    List<Override> plus = const [],
  }) async {
    final s = service ?? _Service();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ingredientRepositoryProvider.overrideWithValue(
            FakeIngredientRepository(groups: [_zwiebel]),
          ),
          alternativeChoiceServiceProvider.overrideWithValue(s),
          currentUserIdProvider.overrideWithValue('test-user'),
          ...(plus.isEmpty ? plusOpenOverrides : plus),
        ],
        child: MaterialApp(
          theme: AppTheme.theme,
          home: Scaffold(body: SuggestionDetailModal(group: _zwiebel)),
        ),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SuggestionDetailModal)),
    );
    await container.read(alternativeChoicesProvider.future);
    await container
        .read(ingredientSuggestionProvider.notifier)
        .fetchSuggestions();
    await tester.pump();
    return s;
  }

  Finder tile(String id) => find.byKey(SuggestionDetailModal.tileKey(id));

  /// The tile names from left to right in the main row.
  List<String> mainRow(WidgetTester tester) {
    final ids =
        ['r-lauch', 'r-schnitt', 'r-ing']
            .where(
              (id) =>
                  tile(id).evaluate().isNotEmpty &&
                  find
                      .descendant(
                        of: find.byKey(SuggestionDetailModal.mainRowKey),
                        matching: tile(id),
                      )
                      .evaluate()
                      .isNotEmpty,
            )
            .toList()
          ..sort(
            (a, b) => tester
                .getTopLeft(tile(a))
                .dx
                .compareTo(tester.getTopLeft(tile(b)).dx),
          );
    return [for (final id in ids) _names[id]!];
  }

  Future<void> openSheet(WidgetTester tester, String id) async {
    await tester.tap(tile(id));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> act(WidgetTester tester, Key key) async {
    await tester.tap(find.byKey(key));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('tapping a tile opens the sheet; „Passt nicht für mich" moves '
      'it under „Passt nicht für mich"', (tester) async {
    final service = await pump(tester);
    expect(mainRow(tester), ['Lauch', 'Schnittlauch', 'Ingwer']);
    expect(find.byKey(SuggestionDetailModal.skippedRowKey), findsNothing);

    await openSheet(tester, 'r-lauch');
    expect(find.byType(AlternativeFeedbackSheet), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlternativeFeedbackSheet),
        matching: find.text('Lauch'),
      ),
      findsOneWidget,
    );
    expect(find.text('Passt für mich'), findsOneWidget);
    expect(find.text('Probiere ich'), findsOneWidget);
    expect(find.text('Passt nicht für mich'), findsOneWidget);

    await act(tester, AlternativeFeedbackSheet.skipKey);

    expect(find.byType(AlternativeFeedbackSheet), findsNothing);
    expect(service.writes, ['skip r-lauch']);
    expect(mainRow(tester), ['Schnittlauch', 'Ingwer']);
    expect(find.text('Passt nicht für mich'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(SuggestionDetailModal.skippedRowKey),
        matching: tile('r-lauch'),
      ),
      findsOneWidget,
    );
    // Dimmed.
    expect(
      find.descendant(
        of: tile('r-lauch'),
        matching: find.byWidgetPredicate((w) => w is Opacity && w.opacity < 1),
      ),
      findsOneWidget,
    );
  });

  testWidgets('„Passt für mich" moves it first and shows the check', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byIcon(Icons.check_circle), findsNothing);

    await openSheet(tester, 'r-ing');
    await act(tester, AlternativeFeedbackSheet.fitsKey);

    expect(mainRow(tester), ['Ingwer', 'Lauch', 'Schnittlauch']);
    final check = find.descendant(
      of: tile('r-ing'),
      matching: find.byIcon(Icons.check_circle),
    );
    expect(check, findsOneWidget);
    expect(tester.widget<Icon>(check).color, AppTheme.primary);
  });

  testWidgets('„Zurücksetzen" appears only with a verdict and restores the '
      'order', (tester) async {
    final service = await pump(tester);

    await openSheet(tester, 'r-ing');
    expect(find.byKey(AlternativeFeedbackSheet.resetKey), findsNothing);
    await act(tester, AlternativeFeedbackSheet.fitsKey);
    expect(mainRow(tester), ['Ingwer', 'Lauch', 'Schnittlauch']);

    await openSheet(tester, 'r-ing');
    expect(find.text('Zurücksetzen'), findsOneWidget);
    await act(tester, AlternativeFeedbackSheet.resetKey);

    expect(service.writes, ['fits r-ing', 'delete c-0']);
    expect(mainRow(tester), ['Lauch', 'Schnittlauch', 'Ingwer']);
    expect(find.byIcon(Icons.check_circle), findsNothing);
  });

  testWidgets('a stored „Probiere ich" reads as such and can become '
      '„Passt für mich", which leaves „Probiere ich"', (tester) async {
    final handle = tester.ensureSemantics();
    final service = _Service([_row('c-try', 'r-schnitt', 'try')]);
    await pump(tester, service: service);

    expect(
      tester.getSemantics(tile('r-schnitt')),
      matchesSemantics(
        label: 'Schnittlauch',
        value: 'Probiere ich',
        isButton: true,
        hasTapAction: true,
      ),
    );
    await openSheet(tester, 'r-schnitt');
    await act(tester, AlternativeFeedbackSheet.fitsKey);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(SuggestionDetailModal)),
    );
    expect(container.read(triedAlternativesProvider), isEmpty);
    expect(
      tester.getSemantics(tile('r-schnitt')),
      matchesSemantics(
        label: 'Schnittlauch',
        value: 'Passt für mich',
        isButton: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('a failed write shows „Konnte nicht gespeichert werden." and '
      'keeps the old order', (tester) async {
    final service = _Service()..fail = true;
    await pump(tester, service: service);

    await openSheet(tester, 'r-lauch');
    await act(tester, AlternativeFeedbackSheet.skipKey);

    expect(find.text('Konnte nicht gespeichert werden.'), findsOneWidget);
    expect(mainRow(tester), ['Lauch', 'Schnittlauch', 'Ingwer']);
    expect(find.byKey(SuggestionDetailModal.skippedRowKey), findsNothing);
  });

  testWidgets('a failed reset shows it too and keeps the verdict', (
    tester,
  ) async {
    final service = _Service([_row('c-skip', 'r-lauch', 'skip')]);
    await pump(tester, service: service);
    expect(mainRow(tester), ['Schnittlauch', 'Ingwer']);

    service.fail = true;
    await openSheet(tester, 'r-lauch');
    await act(tester, AlternativeFeedbackSheet.resetKey);

    expect(find.text('Konnte nicht gespeichert werden.'), findsOneWidget);
    expect(mainRow(tester), ['Schnittlauch', 'Ingwer']);
  });

  testWidgets('the tile state is in semantics, not only in colour', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final service = _Service([
      _row('c-skip', 'r-lauch', 'skip'),
      _row('c-fits', 'r-ing', 'fits'),
    ]);
    await pump(tester, service: service);

    expect(
      tester.getSemantics(tile('r-lauch')),
      matchesSemantics(
        label: 'Lauch',
        value: 'Passt nicht für mich',
        isButton: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(tile('r-ing')),
      matchesSemantics(
        label: 'Ingwer',
        value: 'Passt für mich',
        isButton: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(tile('r-schnitt')),
      matchesSemantics(
        label: 'Schnittlauch',
        isButton: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('while Plus is locked, a tile opens no sheet', (tester) async {
    await pump(tester, plus: plusLockedOverrides);

    await openSheet(tester, 'r-lauch');

    expect(find.byType(AlternativeFeedbackSheet), findsNothing);
  });

  testWidgets('the detail and the sheet: 48 px tap targets, labelled, '
      'readable contrast', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, service: _Service([_row('c-skip', 'r-lauch', 'skip')]));

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));

    await openSheet(tester, 'r-lauch');
    expect(find.text('Zurücksetzen'), findsOneWidget);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });
}
