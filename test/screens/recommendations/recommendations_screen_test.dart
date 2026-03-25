// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/src/internals.dart' show Override;
import 'package:belly_buddy/screens/recommendations/recommendations_screen.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/repositories/recommendation_repository.dart';
import 'package:belly_buddy/repositories/profile_repository.dart';

import '../../helpers/fakes.dart';
import '../../helpers/riverpod_helpers.dart';

List<Override> _overrides() => [
  recommendationRepositoryProvider.overrideWithValue(
    FakeRecommendationRepository(),
  ),
  profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
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

    testWidgets('renders refresh button', (tester) async {
      await tester.pumpWithProviders(
        const RecommendationsScreen(),
        overrides: _overrides(),
      );
      await tester.pump();

      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });
  });
}
