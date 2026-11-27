import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/widgets/scanner/scanner_scrim_label.dart';

void main() {
  double? sizeOf(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text)).style?.fontSize;

  testWidgets('body size by default, the given size otherwise', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Column(
          children: [
            ScannerScrimLabel('Standard'),
            ScannerScrimLabel('Groß', fontSize: AppTheme.fontSizeBodyLG),
          ],
        ),
      ),
    );
    expect(sizeOf(tester, 'Standard'), AppTheme.fontSizeBody);
    expect(sizeOf(tester, 'Groß'), AppTheme.fontSizeBodyLG);
  });
}
