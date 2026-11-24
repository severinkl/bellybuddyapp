import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/widgets/common/bb_drag_handle.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  BoxDecoration decorationOf(WidgetTester tester) =>
      tester.widget<Container>(find.byType(Container)).decoration!
          as BoxDecoration;

  testWidgets('a centred, rounded bar in the muted colour by default', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [BbDragHandle()],
          ),
        ),
      ),
    );

    final box = find.byType(Container);
    expect(
      tester.getSize(box),
      const Size(AppConstants.dragHandleWidth, AppConstants.dragHandleHeight),
    );
    expect(tester.getCenter(box).dx, tester.getCenter(find.byType(Column)).dx);
    expect(decorationOf(tester).color, AppTheme.muted);
    expect(
      decorationOf(tester).borderRadius,
      BorderRadius.circular(AppConstants.dragHandleRadius),
    );
  });

  testWidgets('takes a colour', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: BbDragHandle(color: AppTheme.border)),
    );
    expect(decorationOf(tester).color, AppTheme.border);
  });
}
