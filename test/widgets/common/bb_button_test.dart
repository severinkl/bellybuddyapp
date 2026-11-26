import 'package:belly_buddy/widgets/common/bb_button.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('leading sits before the label', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: BbButton(
              label: 'Los',
              leading: const SizedBox(key: Key('lead'), width: 24, height: 24),
              onPressed: () => taps++,
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getRect(find.byKey(const Key('lead'))).right,
      lessThanOrEqualTo(tester.getRect(find.text('Los')).left),
    );
    await tester.tap(find.byType(BbButton));
    expect(taps, 1);
  });
}
