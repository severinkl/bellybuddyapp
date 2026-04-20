import 'package:belly_buddy/widgets/common/upgrade_available_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpHost(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () => showUpgradeAvailableDialog(ctx),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('renders title, body, and both actions', (tester) async {
    await pumpHost(tester);

    expect(find.text('Update verfügbar'), findsOneWidget);
    expect(
      find.text('Eine neue Version von Belly Buddy ist im Store verfügbar.'),
      findsOneWidget,
    );
    expect(find.text('Später'), findsOneWidget);
    expect(find.text('Jetzt aktualisieren'), findsOneWidget);
  });

  testWidgets('Später closes the dialog without launching the store', (
    tester,
  ) async {
    await pumpHost(tester);
    await tester.tap(find.text('Später'));
    await tester.pumpAndSettle();

    expect(find.text('Update verfügbar'), findsNothing);
  });
}
