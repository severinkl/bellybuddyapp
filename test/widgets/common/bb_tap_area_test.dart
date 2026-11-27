import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/widgets/common/bb_tap_area.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  const tapKey = Key('tap');

  testWidgets('one named, selected button with a 48×48 hit area', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(
      _host(
        BbTapArea(
          tapKey: tapKey,
          label: 'Wasser',
          value: 'neu',
          selected: true,
          exclusive: true,
          excludeChild: true,
          onTap: () => taps++,
          child: const SizedBox(width: 16, height: 16, child: Text('x')),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(tapKey)),
      const Size.square(AppConstants.minTapTarget),
    );
    expect(
      tester.getSemantics(find.byType(BbTapArea)),
      isSemantics(
        label: 'Wasser',
        value: 'neu',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasSelectedState: true,
        isSelected: true,
        isInMutuallyExclusiveGroup: true,
        hasTapAction: true,
      ),
    );
    // The hit area's edge counts too, not just the child.
    await tester.tapAt(
      tester.getTopLeft(find.byKey(tapKey)) + const Offset(1, 1),
    );
    expect(taps, 1);
    handle.dispose();
  });

  testWidgets('is named by its text unless excluded; disabled without onTap', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        const BbTapArea(
          tapTarget: false,
          expanded: false,
          onTap: null,
          child: Text('Passwort ändern'),
        ),
      ),
    );

    expect(
      tester.getSemantics(find.byType(BbTapArea)),
      isSemantics(
        label: 'Passwort ändern',
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
        hasExpandedState: true,
        isExpanded: false,
        isInMutuallyExclusiveGroup: false,
      ),
    );
    // Without the tap target the hit area is just the text.
    expect(
      tester.getSize(find.byType(GestureDetector)).height,
      lessThan(AppConstants.minTapTarget),
    );
    handle.dispose();
  });
}
