// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/src/internals.dart' show Override;
import 'package:belly_buddy/screens/trackers/toilet/toilet_tracker_screen.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/riverpod_helpers.dart';

List<Override> _overrides() => [
  entryRepositoryProvider.overrideWithValue(FakeEntryRepository()),
  currentUserIdProvider.overrideWithValue('test-user'),
];

void main() {
  group('ToiletTrackerScreen', () {
    testWidgets('renders screen title', (tester) async {
      await tester.pumpWithProviders(
        const ToiletTrackerScreen(),
        overrides: _overrides(),
      );
      await tester.pump();

      expect(find.text('Am Klo 💩 gewesen?'), findsOneWidget);
    });

    testWidgets('renders Konsistenz? label', (tester) async {
      await tester.pumpWithProviders(
        const ToiletTrackerScreen(),
        overrides: _overrides(),
      );
      await tester.pump();

      expect(find.text('Konsistenz?'), findsOneWidget);
    });

    testWidgets('renders slider labels', (tester) async {
      await tester.pumpWithProviders(
        const ToiletTrackerScreen(),
        overrides: _overrides(),
      );
      await tester.pump();

      expect(find.text('sehr hart'), findsOneWidget);
      expect(find.text('flüssig'), findsOneWidget);
    });

    testWidgets('renders speichern button', (tester) async {
      await tester.pumpWithProviders(
        const ToiletTrackerScreen(),
        overrides: _overrides(),
      );
      await tester.pump();

      expect(find.text('speichern'), findsOneWidget);
    });
  });
}
