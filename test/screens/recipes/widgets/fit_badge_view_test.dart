import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/screens/recipes/widgets/fit_badge_view.dart';
import 'package:belly_buddy/services/recipes/recipe_fit.dart';

void main() {
  Future<void> pump(WidgetTester tester, FitBadge badge) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: Center(child: FitBadgeView(badge))),
    ),
  );

  testWidgets('fits: check icon on the good tint', (tester) async {
    await pump(tester, const FitsBadge());
    expect(find.text('Passt zu dir'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    final box = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(FitBadgeView),
        matching: find.byType(DecoratedBox),
      ),
    );
    expect(
      (box.decoration as BoxDecoration).color,
      AppTheme.gutFeelingGoodSoft,
    );
  });

  testWidgets('kritisch: 1 and 2', (tester) async {
    await pump(tester, const KritischBadge(1));
    expect(find.text('1 Zutat ist für dich kritisch'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    await pump(tester, const KritischBadge(2));
    expect(find.text('2 Zutaten sind für dich kritisch'), findsOneWidget);
  });

  testWidgets('self check: Histamin', (tester) async {
    await pump(tester, const SelfCheckBadge(['Histamin']));
    expect(find.text('Histamin bitte selbst prüfen'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });

  testWidgets('small uses the small font', (tester) async {
    await pump(tester, const FitsBadge());
    double size() =>
        tester.widget<Text>(find.text('Passt zu dir')).style!.fontSize!;
    expect(size(), AppTheme.fontSizeCaption);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: FitBadgeView(FitsBadge(), small: true)),
      ),
    );
    expect(size(), AppTheme.fontSizeSM);
  });
}
