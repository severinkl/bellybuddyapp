import 'package:flutter/rendering.dart' show SemanticsNode;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/widgets/common/bb_scroll_picker.dart';

/// The picker under test, at the height it gets in the registration.
Widget _picker({
  required List<int> items,
  int? selected,
  required ValueChanged<int> onChanged,
  String Function(int)? labelBuilder,
  bool disableAnimations = false,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: Scaffold(
      body: BbScrollPicker(
        items: items,
        selectedValue: selected,
        onChanged: onChanged,
        labelBuilder: labelBuilder,
        semanticLabel: 'Geburtsjahr',
      ),
    ),
  ),
);

/// The picker's own node.
SemanticsNode _node() =>
    find.semantics.byLabel('Geburtsjahr').evaluate().single;

void main() {
  testWidgets('the picker reads „Geburtsjahr, 1990"; increase sets 1991 and '
      'calls onChanged; at the last item there is no increase', (tester) async {
    final handle = tester.ensureSemantics();
    final changes = <int>[];
    await tester.pumpWidget(
      _picker(
        items: [1989, 1990, 1991],
        selected: 1990,
        onChanged: changes.add,
      ),
    );

    final picker = find.semantics.byLabel('Geburtsjahr');
    expect(
      _node(),
      isSemantics(
        label: 'Geburtsjahr',
        value: '1990',
        increasedValue: '1991',
        decreasedValue: '1989',
        hasIncreaseAction: true,
        hasDecreaseAction: true,
      ),
    );

    tester.semantics.increase(picker);
    await tester.pumpAndSettle();
    expect(changes, [1991]);
    expect(
      _node(),
      isSemantics(
        label: 'Geburtsjahr',
        value: '1991',
        decreasedValue: '1990',
        hasIncreaseAction: false,
        hasDecreaseAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('the wheel itself is hidden: its items are not read one by one', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _picker(items: [160, 170, 180], selected: 170, onChanged: (_) {}),
    );

    expect(find.semantics.byLabel('160'), findsNothing);
    expect(find.semantics.byLabel('180'), findsNothing);
    handle.dispose();
  });

  testWidgets('the value reads as the wheel shows it, with its unit', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _picker(
        items: [171, 172, 173],
        selected: 172,
        onChanged: (_) {},
        labelBuilder: (v) => '$v cm',
      ),
    );

    expect(
      _node(),
      isSemantics(
        label: 'Geburtsjahr',
        value: '172 cm',
        increasedValue: '173 cm',
        decreasedValue: '171 cm',
      ),
    );
    handle.dispose();
  });

  testWidgets('without a selected value it reads the item the wheel starts '
      'on', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_picker(items: [1, 2, 3, 4, 5], onChanged: (_) {}));

    expect(_node(), isSemantics(label: 'Geburtsjahr', value: '3'));
    handle.dispose();
  });

  testWidgets('under reduced motion a step lands at once, once', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final changes = <int>[];
    await tester.pumpWidget(
      _picker(
        items: [1, 2, 3],
        selected: 2,
        onChanged: changes.add,
        disableAnimations: true,
      ),
    );

    tester.semantics.decrease(find.semantics.byLabel('Geburtsjahr'));
    await tester.pump();
    expect(changes, [1]);
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(
      _node(),
      isSemantics(
        label: 'Geburtsjahr',
        value: '1',
        hasDecreaseAction: false,
        hasIncreaseAction: true,
      ),
    );
    handle.dispose();
  });
}
