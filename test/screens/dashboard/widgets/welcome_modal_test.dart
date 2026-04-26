import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/screens/dashboard/widgets/welcome_modal.dart';
import 'package:belly_buddy/widgets/common/mascot_image.dart';

Widget _host(void Function(BuildContext) onOpenPressed) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (ctx) => Center(
          child: ElevatedButton(
            onPressed: () => onOpenPressed(ctx),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('showWelcomeModal', () {
    testWidgets(
      'renders mascot + welcome title + body and Los gehts CTA dismisses it',
      (tester) async {
        late Future<void> sheetFuture;
        await tester.pumpWidget(
          _host((ctx) => sheetFuture = showWelcomeModal(ctx)),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        expect(find.byType(MascotImage), findsOneWidget);
        expect(find.text('Willkommen bei Belly Buddy!'), findsOneWidget);
        expect(find.textContaining('Verdauungsprobleme'), findsOneWidget);
        expect(find.text("Los geht's"), findsOneWidget);

        await tester.tap(find.text("Los geht's"));
        await tester.pumpAndSettle();

        expect(find.text('Willkommen bei Belly Buddy!'), findsNothing);
        await sheetFuture;
      },
    );

    testWidgets(
      'tapping the scrim does NOT dismiss (barrierDismissible: false)',
      (tester) async {
        await tester.pumpWidget(_host(showWelcomeModal));
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        // The barrier sits above the scaffold, outside the AlertDialog.
        // Tapping near the top-left hits the barrier, not the dialog.
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        expect(find.text('Willkommen bei Belly Buddy!'), findsOneWidget);
      },
    );
  });
}
