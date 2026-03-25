// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/src/internals.dart' show Override;
import 'package:belly_buddy/screens/trackers/gut_feeling/gut_feeling_tracker_screen.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/riverpod_helpers.dart';

List<Override> _overrides() => [
  entryRepositoryProvider.overrideWithValue(FakeEntryRepository()),
  currentUserIdProvider.overrideWithValue('test-user'),
];

void main() {
  group('GutFeelingTrackerScreen', () {
    testWidgets('renders screen appBar title', (tester) async {
      await tester.pumpWithProviders(
        const GutFeelingTrackerScreen(),
        overrides: _overrides(),
      );
      // Use pump with duration to let entry animations start
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Wie geht es dir?'), findsOneWidget);
    });

    testWidgets('renders two tab options', (tester) async {
      await tester.pumpWithProviders(
        const GutFeelingTrackerScreen(),
        overrides: _overrides(),
      );
      await tester.pump(const Duration(milliseconds: 50));

      // MoodTabSelector has "Bauchgefühl" and "Stimmung" tabs
      expect(find.text('Bauchgefühl'), findsOneWidget);
      expect(find.text('Stimmung'), findsOneWidget);
    });

    testWidgets('renders weiter button on first tab', (tester) async {
      await tester.pumpWithProviders(
        const GutFeelingTrackerScreen(),
        overrides: _overrides(),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('weiter'), findsOneWidget);
    });

    testWidgets('renders PageView with two pages', (tester) async {
      await tester.pumpWithProviders(
        const GutFeelingTrackerScreen(),
        overrides: _overrides(),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(PageView), findsOneWidget);
    });
  });
}
