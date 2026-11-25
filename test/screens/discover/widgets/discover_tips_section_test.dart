// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/models/recommendation.dart';
import 'package:belly_buddy/providers/profile_provider.dart';
import 'package:belly_buddy/screens/discover/widgets/discover_tips_card.dart';
import 'package:belly_buddy/screens/discover/widgets/discover_tips_section.dart';
import 'package:belly_buddy/widgets/common/weekly_tips_switch.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/riverpod_helpers.dart';

void main() {
  final withTips = testRecommendation(
    id: 'with-tips',
    createdAt: DateTime.utc(2026, 11, 16, 10),
  );

  test('showsFor: only a loaded value with a set with tips', () {
    final withoutTips = testRecommendation(
      id: 'without-tips',
      recommendations: const [],
      createdAt: DateTime.utc(2026, 11, 23, 10),
    );
    final olderWithTips = testRecommendation(
      id: 'older',
      createdAt: DateTime.utc(2026, 11, 9, 10),
    );

    for (final tips in <AsyncValue<List<Recommendation>>>[
      const AsyncLoading(),
      AsyncError(Exception('offline'), StackTrace.empty),
      const AsyncData([]),
      AsyncData([withoutTips]),
    ]) {
      expect(DiscoverTipsSection.showsFor(tips), isFalse, reason: '$tips');
    }
    for (final tips in <AsyncValue<List<Recommendation>>>[
      AsyncData([withoutTips, olderWithTips]),
      AsyncData([withTips]),
      // Kept while a refresh runs or after it failed.
      const AsyncLoading<List<Recommendation>>().copyWithPrevious(
        AsyncData([withTips]),
      ),
      AsyncError<List<Recommendation>>(
        Exception('offline'),
        StackTrace.empty,
      ).copyWithPrevious(AsyncData([withTips])),
    ]) {
      expect(DiscoverTipsSection.showsFor(tips), isTrue, reason: '$tips');
    }
  });

  for (final weeklyTips in [false, true, null]) {
    testWidgets('a set, weekly tips $weeklyTips: the card'
        '${weeklyTips == false ? ', then the opt-in' : ' only'}', (
      tester,
    ) async {
      await tester.pumpWithProviders(
        Scaffold(
          body: DiscoverTipsSection(
            sets: [withTips],
            weeklyTips: weeklyTips,
            onOpen: () {},
          ),
        ),
        // The switch shows as the profile says.
        overrides: [weeklyTipsEnabledProvider.overrideWithValue(weeklyTips)],
      );

      final card = find.byKey(DiscoverTipsCard.cardKey);
      final optIn = find.byKey(DiscoverTipsSection.optInKey);
      expect(
        find.descendant(of: card, matching: find.text('Woche 47')),
        findsOneWidget,
      );
      if (weeklyTips == false) {
        expect(optIn, findsOneWidget);
        expect(
          find.descendant(of: optIn, matching: find.byType(WeeklyTipsSwitch)),
          findsOneWidget,
        );
        expect(
          tester.getBottomLeft(card).dy,
          lessThan(tester.getTopLeft(optIn).dy),
        );
      } else {
        expect(optIn, findsNothing);
      }
      // No example and no „kommen am Montag" note: „Montag" shows only in
      // the switch's subline.
      expect(
        find.textContaining('Montag'),
        findsNWidgets(
          find
              .descendant(of: optIn, matching: find.textContaining('Montag'))
              .evaluate()
              .length,
        ),
      );
    });
  }
}
