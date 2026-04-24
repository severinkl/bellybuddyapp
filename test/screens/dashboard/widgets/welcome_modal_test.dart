import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/screens/dashboard/widgets/welcome_modal.dart';

void main() {
  group('showWelcomeModal', () {
    testWidgets(
      'renders the welcome title + body and Los gehts CTA dismisses it',
      (tester) async {
        late Future<void> sheetFuture;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => Center(
                  child: ElevatedButton(
                    onPressed: () {
                      sheetFuture = showWelcomeModal(ctx);
                    },
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        expect(find.text('Willkommen bei Belly Buddy!'), findsOneWidget);
        expect(find.textContaining('Verdauungsprobleme'), findsOneWidget);
        expect(find.text("Los geht's"), findsOneWidget);

        await tester.tap(find.text("Los geht's"));
        await tester.pumpAndSettle();

        expect(find.text('Willkommen bei Belly Buddy!'), findsNothing);
        await sheetFuture;
      },
    );
  });
}
