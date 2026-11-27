// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:riverpod/src/internals.dart' show Override;

import 'package:belly_buddy/models/alternative_choice.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/screens/ingredient_suggestions/ingredient_suggestions_screen.dart';
import 'package:belly_buddy/screens/ingredient_suggestions/widgets/tried_alternatives_section.dart';
import 'package:belly_buddy/services/alternative_choice_service.dart';
import 'package:belly_buddy/services/daily_review/daily_review_copy.dart';
import 'package:belly_buddy/repositories/ingredient_repository.dart';

import '../../helpers/fakes.dart';
import '../../helpers/purchases_fakes.dart';
import '../../helpers/riverpod_helpers.dart';

Map<String, dynamic> _row(
  String id,
  String rep,
  String ing, {
  String choice = 'try',
  required String at,
}) => {
  'id': id,
  'ingredient_id': 'i-$ing',
  'replacement_ingredient_id': 'r-$rep',
  'choice': choice,
  'created_at': at,
  'ingredient': {'name': ing},
  'replacement': {'name': rep},
};

class _Service implements AlternativeChoiceService {
  _Service(this.rows);
  final List<Map<String, dynamic>> rows;
  bool failDelete = false;

  @override
  Future<List<Map<String, dynamic>>> fetch(String userId) async => rows;

  @override
  Future<Map<String, dynamic>> upsert({
    required String userId,
    required String ingredientId,
    required String replacementId,
    required AlternativeChoiceKind kind,
  }) => throw UnimplementedError();

  @override
  Future<void> delete(String id) async {
    if (failDelete) throw Exception('offline');
  }
}

final _rows = [
  _row('c2', 'Frühlingszwiebel (grün)', 'Zwiebel', at: '2026-11-27T10:00:00Z'),
  _row('c1', 'Lauch', 'Knoblauch', at: '2026-11-26T10:00:00Z'),
  _row('c3', 'Salz', 'Pfeffer', choice: 'skip', at: '2026-11-25T10:00:00Z'),
];

List<Override> _overrides(_Service service) => [
  alternativeChoiceServiceProvider.overrideWithValue(service),
  currentUserIdProvider.overrideWithValue('test-user'),
];

Future<void> _pumpSection(WidgetTester tester, _Service service) async {
  await tester.pumpWithProviders(
    const Scaffold(body: TriedAlternativesSection()),
    overrides: _overrides(service),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  group('TriedAlternativesSection', () {
    testWidgets('two tried items: newest first', (tester) async {
      await _pumpSection(tester, _Service(_rows));

      expect(find.text('Probiere ich'), findsOneWidget);
      final first = tester.getTopLeft(
        find.text('Frühlingszwiebel (grün) statt Zwiebel'),
      );
      final second = tester.getTopLeft(find.text('Lauch statt Knoblauch'));
      expect(first.dy, lessThan(second.dy));
    });

    testWidgets('skip choices are not listed; none tried: no section', (
      tester,
    ) async {
      await _pumpSection(tester, _Service([_rows[2]]));

      expect(find.text('Probiere ich'), findsNothing);
      expect(find.text('Salz statt Pfeffer'), findsNothing);
    });

    testWidgets('„Nicht mehr merken" removes the row', (tester) async {
      await _pumpSection(tester, _Service(_rows));

      await tester.tap(find.byTooltip('Nicht mehr merken').first);
      await tester.pump();
      await tester.pump();

      expect(find.text('Frühlingszwiebel (grün) statt Zwiebel'), findsNothing);
      expect(find.text('Lauch statt Knoblauch'), findsOneWidget);
    });

    testWidgets('failure: SnackBar, row stays', (tester) async {
      await _pumpSection(tester, _Service(_rows)..failDelete = true);

      await tester.tap(find.byTooltip('Nicht mehr merken').first);
      await tester.pump();
      await tester.pump();

      expect(find.text(DailyReviewCopy.failed), findsOneWidget);
      expect(
        find.text('Frühlingszwiebel (grün) statt Zwiebel'),
        findsOneWidget,
      );
    });

    testWidgets('on the screen, Plus locked: the section is above the search', (
      tester,
    ) async {
      await tester.pumpWithProviders(
        const IngredientSuggestionsScreen(),
        overrides: [
          ..._overrides(_Service(_rows)),
          ingredientRepositoryProvider.overrideWithValue(
            FakeIngredientRepository(),
          ),
          ...plusLockedOverrides,
        ],
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Probiere ich'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Probiere ich')).dy,
        lessThan(tester.getTopLeft(find.byType(TextField)).dy),
      );
    });
  });
}
