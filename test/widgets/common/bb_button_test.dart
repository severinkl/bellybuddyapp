import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/config/constants.dart';
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

  testWidgets('semanticLabel names the button for assistive tech, the '
      'visible text stays', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: BbButton(
              label: 'Eintragen',
              semanticLabel: 'Wasser, 250 ml eintragen',
              onPressed: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Eintragen'), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(ElevatedButton)),
      isSemantics(
        label: 'Wasser, 250 ml eintragen',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
        isFocusable: true,
      ),
    );
    expect(find.bySemanticsLabel('Eintragen'), findsNothing);
    handle.dispose();
  });

  testWidgets('semanticLabel also names it while loading', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: BbButton(
              label: 'Eintragen',
              semanticLabel: 'Wasser, 250 ml eintragen',
              isLoading: true,
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getSemantics(find.byType(ElevatedButton)).label,
      'Wasser, 250 ml eintragen',
    );
    handle.dispose();
  });

  testWidgets('compact is a pill at least the tap size beside other content, '
      'not the theme\'s full width', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: Scaffold(
          body: Row(
            children: [
              const Expanded(child: Text('Wasser, 250 ml')),
              BbButton(label: 'Eintragen', compact: true, onPressed: () {}),
            ],
          ),
        ),
      ),
    );

    final size = tester.getSize(find.byType(ElevatedButton));
    expect(size.width, greaterThanOrEqualTo(AppConstants.minTapTarget));
    expect(size.height, greaterThanOrEqualTo(AppConstants.minTapTarget));
    expect(size.width, lessThan(tester.getSize(find.byType(Row)).width / 2));
    final style = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(style.style?.shape?.resolve({}), isA<StadiumBorder>());
  });

  testWidgets('compact applies to the outlined button too', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: Scaffold(
          body: Row(
            children: [
              const Expanded(child: Text('Wasser, 250 ml')),
              BbButton(
                label: 'Eintragen',
                compact: true,
                isOutlined: true,
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );

    final size = tester.getSize(find.byType(OutlinedButton));
    expect(size.width, greaterThanOrEqualTo(AppConstants.minTapTarget));
    expect(size.height, greaterThanOrEqualTo(AppConstants.minTapTarget));
    expect(size.width, lessThan(tester.getSize(find.byType(Row)).width / 2));
    final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
    expect(button.style?.shape?.resolve({}), isA<StadiumBorder>());
  });

  testWidgets('compact and destructive outlined keeps the destructive colour', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: Scaffold(
          body: Center(
            child: BbButton(
              label: 'Löschen',
              compact: true,
              isOutlined: true,
              isDestructive: true,
              onPressed: () {},
            ),
          ),
        ),
      ),
    );

    final style = tester
        .widget<OutlinedButton>(find.byType(OutlinedButton))
        .style;
    expect(style?.shape?.resolve({}), isA<StadiumBorder>());
    expect(style?.foregroundColor?.resolve({}), AppTheme.destructive);
  });
}
