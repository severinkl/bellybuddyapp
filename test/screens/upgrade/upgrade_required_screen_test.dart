import 'package:belly_buddy/screens/upgrade/upgrade_required_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the required elements', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: UpgradeRequiredScreen())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Update erforderlich'), findsOneWidget);
    expect(find.text('Aktualisieren'), findsOneWidget);
  });

  testWidgets('has no back affordance (PopScope blocks pops)', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: UpgradeRequiredScreen())),
    );
    await tester.pumpAndSettle();

    // AppBar leading back button should not be present.
    expect(find.byIcon(Icons.arrow_back), findsNothing);

    // PopScope is in the tree and configured to block.
    final popScope = tester.widget<PopScope>(find.byType(PopScope));
    expect(popScope.canPop, isFalse);
  });
}
