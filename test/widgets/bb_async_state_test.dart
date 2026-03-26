import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:belly_buddy/widgets/common/bb_async_state.dart';

import '../helpers/riverpod_helpers.dart';

void main() {
  group('BbLoadingState', () {
    testWidgets(
      'shows CircularProgressIndicator via MascotImage fallback and message',
      (tester) async {
        await tester.pumpWithProviders(const Scaffold(body: BbLoadingState()));
        // Default message is 'Laden...'
        expect(find.text('Laden...'), findsOneWidget);
      },
    );

    testWidgets('shows custom message', (tester) async {
      await tester.pumpWithProviders(
        const Scaffold(body: BbLoadingState(message: 'Bitte warten...')),
      );
      expect(find.text('Bitte warten...'), findsOneWidget);
    });
  });

  group('BbErrorState', () {
    testWidgets('shows error message text', (tester) async {
      await tester.pumpWithProviders(
        const Scaffold(
          body: BbErrorState(message: 'Etwas ist schiefgelaufen.'),
        ),
      );
      expect(find.text('Etwas ist schiefgelaufen.'), findsOneWidget);
    });

    testWidgets('shows retry button when onRetry is provided', (tester) async {
      var retried = false;
      await tester.pumpWithProviders(
        Scaffold(
          body: BbErrorState(message: 'Fehler', onRetry: () => retried = true),
        ),
      );
      expect(find.text('Erneut versuchen'), findsOneWidget);
      await tester.tap(find.text('Erneut versuchen'));
      await tester.pump();
      expect(retried, isTrue);
    });

    testWidgets('hides retry button when onRetry is null', (tester) async {
      await tester.pumpWithProviders(
        const Scaffold(body: BbErrorState(message: 'Fehler ohne Retry')),
      );
      expect(find.text('Erneut versuchen'), findsNothing);
    });
  });
}
