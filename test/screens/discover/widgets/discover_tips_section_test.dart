import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/models/recommendation.dart';
import 'package:belly_buddy/screens/discover/widgets/discover_tips_card.dart';
import 'package:belly_buddy/screens/discover/widgets/discover_tips_section.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/riverpod_helpers.dart';

void main() {
  final tipStates = <String, AsyncValue<List<Recommendation>>>{
    'loading': const AsyncLoading(),
    'failed': AsyncError(Exception('offline'), StackTrace.empty),
    'empty': const AsyncData([]),
    'a set': AsyncData([
      testRecommendation(createdAt: DateTime.utc(2026, 11, 16, 10)),
    ]),
  };

  /// What the section shows: the text in the tips card's place (null: no
  /// card) and whether the opt-in follows.
  (String?, bool) expected(String tips, bool? weeklyTips) => (
    switch ((tips, weeklyTips)) {
      ('loading', _) => 'Laden…',
      ('failed', _) => 'Tipps konnten nicht geladen werden.',
      ('empty', null) => 'Noch keine Tipps.',
      ('empty', true) => DiscoverTipsSection.emptyWhileOn,
      ('empty', false) => null,
      _ => 'Woche 47',
    },
    weeklyTips == false,
  );

  for (final MapEntry(key: name, value: tips) in tipStates.entries) {
    for (final weeklyTips in [null, false, true]) {
      testWidgets('tips $name, weekly tips $weeklyTips', (tester) async {
        await tester.pumpWithProviders(
          Scaffold(
            body: DiscoverTipsSection(
              tips: tips,
              weeklyTips: weeklyTips,
              onOpen: () {},
            ),
          ),
        );

        final (text, optIn) = expected(name, weeklyTips);
        final card = find.byKey(DiscoverTipsCard.cardKey);
        if (text == null) {
          expect(card, findsNothing);
        } else {
          expect(
            find.descendant(of: card, matching: find.text(text)),
            findsOneWidget,
          );
        }
        expect(
          find.byKey(DiscoverTipsSection.optInKey),
          optIn ? findsOneWidget : findsNothing,
        );
      });
    }
  }
}
