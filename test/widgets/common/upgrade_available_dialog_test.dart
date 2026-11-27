import 'package:belly_buddy/widgets/common/upgrade_available_dialog.dart';
import 'package:belly_buddy/config/app_theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpHost(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (ctx, ref, _) => Center(
                child: ElevatedButton(
                  onPressed: () => showUpgradeAvailableDialog(ctx, ref),
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

  testWidgets('„Jetzt aktualisieren" is drawn in the readable primaryText', (
    tester,
  ) async {
    await pumpHost(tester);
    final style = DefaultTextStyle.of(
      tester.element(find.text('Jetzt aktualisieren')),
    ).style;
    expect(style.color, AppTheme.primaryText);
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
