import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/widgets/common/bb_password_hint.dart';

void main() {
  testWidgets('a met hint draws its text in successText, its icon in success', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BbPasswordHint(text: 'Mindestens 8 Zeichen', isValid: true),
        ),
      ),
    );
    final text = tester.widget<Text>(find.text('Mindestens 8 Zeichen'));
    expect(text.style!.color, AppTheme.successText);
    final icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.color, AppTheme.success);
  });
}
