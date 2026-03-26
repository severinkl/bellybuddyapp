// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/src/internals.dart' show Override;
import 'package:belly_buddy/screens/diary/diary_screen.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';

import '../../helpers/fakes.dart';
import '../../helpers/fixtures.dart';
import '../../helpers/riverpod_helpers.dart';

List<Override> _overrides() => [
  entryRepositoryProvider.overrideWithValue(FakeEntryRepository()),
  currentUserIdProvider.overrideWithValue('test-user'),
];

List<Override> _emptyOverrides() => [
  entryRepositoryProvider.overrideWithValue(
    FakeEntryRepository()..seedResult(
      testEntryQueryResult(
        meals: [],
        toiletEntries: [],
        gutFeelings: [],
        drinks: [],
      ),
    ),
  ),
  currentUserIdProvider.overrideWithValue('test-user'),
];

void main() {
  group('DiaryScreen', () {
    testWidgets('renders calendar icon', (tester) async {
      await tester.pumpWithProviders(
        const DiaryScreen(),
        overrides: _overrides(),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.calendar_today), findsOneWidget);
    });

    testWidgets('renders diary entries for today', (tester) async {
      await tester.pumpWithProviders(
        const DiaryScreen(),
        overrides: _overrides(),
      );
      await tester.pumpAndSettle();

      // FakeEntryRepository returns testMealEntry (title: Testmahlzeit)
      expect(find.text('Testmahlzeit'), findsOneWidget);
    });

    testWidgets('shows empty state message when no entries', (tester) async {
      await tester.pumpWithProviders(
        const DiaryScreen(),
        overrides: _emptyOverrides(),
      );
      await tester.pumpAndSettle();

      expect(find.text('Noch keine Daten für heute.'), findsOneWidget);
    });

    testWidgets('renders navigation arrows', (tester) async {
      await tester.pumpWithProviders(
        const DiaryScreen(),
        overrides: _overrides(),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    });
  });
}
