// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/src/internals.dart' show Override;
import 'package:belly_buddy/screens/recommendations/recommendations_screen.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/repositories/recommendation_repository.dart';

import '../../helpers/fakes.dart';
import '../../helpers/fixtures.dart';
import '../../helpers/mocks.dart';
import '../../helpers/riverpod_helpers.dart';

List<Override> _overrides() => [
  recommendationRepositoryProvider.overrideWithValue(
    FakeRecommendationRepository(),
  ),
  currentUserIdProvider.overrideWithValue('test-user'),
];

void main() {
  group('RecommendationsScreen', () {
    testWidgets('renders Empfehlungen app bar title', (tester) async {
      await tester.pumpWithProviders(
        const RecommendationsScreen(),
        overrides: _overrides(),
      );
      await tester.pump();

      expect(find.text('Empfehlungen'), findsAtLeast(1));
    });

    testWidgets('renders recommendation content after loading', (tester) async {
      await tester.pumpWithProviders(
        const RecommendationsScreen(),
        overrides: _overrides(),
      );
      // Let microtask + async loading complete
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // FakeRecommendationRepository returns testRecommendation with this summary
      expect(find.textContaining('Tipp'), findsAtLeast(1));
    });

    testWidgets(
      'error-state retry calls fetchByUserId — not a regenerate path',
      (tester) async {
        final mock = MockRecommendationRepository();
        var callCount = 0;
        when(() => mock.fetchByUserId(any())).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) throw Exception('boom');
          return [testRecommendation()];
        });
        when(() => mock.markAllAsSeen(any())).thenAnswer((_) async {});

        await tester.pumpWithProviders(
          const RecommendationsScreen(),
          overrides: [
            recommendationRepositoryProvider.overrideWithValue(mock),
            currentUserIdProvider.overrideWithValue('test-user'),
          ],
        );
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));

        await tester.tap(find.text('Erneut versuchen'));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));

        // Pins the retry wiring: fetch on initial mount + fetch on retry.
        expect(callCount, equals(2));
        expect(find.textContaining('Tipp'), findsAtLeast(1));
      },
    );

    testWidgets('empty-state "Aktualisieren" button calls fetchByUserId', (
      tester,
    ) async {
      final mock = MockRecommendationRepository();
      when(() => mock.fetchByUserId(any())).thenAnswer((_) async => []);
      when(() => mock.markAllAsSeen(any())).thenAnswer((_) async {});

      await tester.pumpWithProviders(
        const RecommendationsScreen(),
        overrides: [
          recommendationRepositoryProvider.overrideWithValue(mock),
          currentUserIdProvider.overrideWithValue('test-user'),
        ],
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(RecommendationsScreen.emptyStateRefreshKey));
      await tester.pump(const Duration(milliseconds: 100));

      // Initial mount fires one fetch; tap fires a second.
      verify(() => mock.fetchByUserId('test-user')).called(2);
    });
  });
}
