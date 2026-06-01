import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/screens/recommendations/widgets/recommendations_notice_dialog.dart';
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
  group('showRecommendationsNoticeDialog', () {
    testWidgets('renders mascot, title, body and both actions', (tester) async {
      late Future<void> dialogFuture;
      await tester.pumpWidget(
        _host((ctx) => dialogFuture = showRecommendationsNoticeDialog(ctx)),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(MascotImage), findsOneWidget);
      expect(find.text('Danke, dass du dabei bist! 💛'), findsOneWidget);
      expect(find.textContaining('vorerst keine'), findsOneWidget);
      expect(find.text('Feedback geben'), findsOneWidget);
      expect(find.text('Schließen'), findsOneWidget);

      // Clean up the open dialog so the test future completes.
      await tester.tap(find.text('Schließen'));
      await tester.pumpAndSettle();
      await dialogFuture;
    });

    testWidgets('tapping Schließen dismisses the dialog', (tester) async {
      await tester.pumpWidget(_host(showRecommendationsNoticeDialog));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Danke, dass du dabei bist! 💛'), findsOneWidget);

      await tester.tap(find.text('Schließen'));
      await tester.pumpAndSettle();

      expect(find.text('Danke, dass du dabei bist! 💛'), findsNothing);
    });
  });
}
