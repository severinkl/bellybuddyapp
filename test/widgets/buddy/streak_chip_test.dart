import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/widgets/buddy/streak_chip.dart';
import 'package:belly_buddy/widgets/buddy/streak_flame.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Widget _wrap(Widget c) => MaterialApp(
  theme: AppTheme.theme,
  home: Scaffold(body: Center(child: c)),
);

void main() {
  testWidgets('shows plural days', (t) async {
    await t.pumpWidget(_wrap(const StreakChip(streak: 5, todayCounted: true)));
    expect(find.textContaining('5 Tage'), findsOneWidget);
    expect(find.textContaining('🛡'), findsNothing);
  });

  testWidgets('singular and zero', (t) async {
    await t.pumpWidget(_wrap(const StreakChip(streak: 1, todayCounted: true)));
    expect(find.textContaining('1 Tag'), findsOneWidget);
    expect(find.textContaining('1 Tage'), findsNothing);
    await t.pumpWidget(_wrap(const StreakChip(streak: 0, todayCounted: false)));
    expect(find.textContaining('0 Tage'), findsOneWidget);
  });

  testWidgets('shows only the streak, never the savers', (t) async {
    final h = t.ensureSemantics();
    await t.pumpWidget(_wrap(const StreakChip(streak: 1, todayCounted: true)));
    expect(find.text('1 Tag'), findsOneWidget);
    expect(find.textContaining('🛡'), findsNothing);
    expect(find.bySemanticsLabel(RegExp('Schutz')), findsNothing);
    h.dispose();
  });

  testWidgets('shows the count only: no flame', (t) async {
    await t.pumpWidget(_wrap(const StreakChip(streak: 5, todayCounted: true)));

    expect(find.byType(StreakFlame), findsNothing);
    expect(find.textContaining('🔥'), findsNothing);
    expect(find.text('5 Tage'), findsOneWidget);
  });

  testWidgets('its tap area is at least 48 dp tall', (t) async {
    var taps = 0;
    await t.pumpWidget(
      _wrap(StreakChip(streak: 5, todayCounted: true, onTap: () => taps++)),
    );

    final chip = t.getRect(find.byType(StreakChip));
    final pill = t.getRect(
      find.descendant(
        of: find.byType(StreakChip),
        matching: find.byType(Container),
      ),
    );
    expect(chip.height, greaterThanOrEqualTo(AppConstants.homeTapTarget));
    // Just that tall (the pill is shorter), as wide as the pill, which is
    // centred in it.
    expect(pill.height, lessThan(AppConstants.homeTapTarget));
    expect(chip.height, AppConstants.homeTapTarget);
    expect(chip.width, pill.width);
    expect(pill.center, chip.center);

    await t.tapAt(chip.topLeft + const Offset(2, 2));
    expect(taps, 1);
  });

  testWidgets('semantics unchanged', (t) async {
    final h = t.ensureSemantics();
    await t.pumpWidget(_wrap(const StreakChip(streak: 4, todayCounted: false)));
    expect(
      find.semantics.byLabel(RegExp('^Streak: 4 Tage')).evaluate().single.label,
      'Streak: 4 Tage, Heute noch offen',
    );
    h.dispose();
  });

  testWidgets('muted exposes Heute noch offen', (t) async {
    final h = t.ensureSemantics();
    await t.pumpWidget(_wrap(const StreakChip(streak: 5, todayCounted: false)));
    expect(find.bySemanticsLabel(RegExp('Heute noch offen')), findsWidgets);
    h.dispose();
  });

  testWidgets('counted chip has no open hint', (t) async {
    final h = t.ensureSemantics();
    await t.pumpWidget(_wrap(const StreakChip(streak: 5, todayCounted: true)));
    expect(find.bySemanticsLabel(RegExp('Heute noch offen')), findsNothing);
    h.dispose();
  });

  testWidgets('pops on increase, not under reduced motion', (t) async {
    double scale() => t
        .widget<ScaleTransition>(find.byType(ScaleTransition).first)
        .scale
        .value;
    await t.pumpWidget(_wrap(const StreakChip(streak: 5, todayCounted: true)));
    await t.pumpWidget(_wrap(const StreakChip(streak: 6, todayCounted: true)));
    await t.pump(const Duration(milliseconds: 150));
    expect(scale(), greaterThan(1.1));
    await t.pumpAndSettle();
    expect(scale(), 1.0);

    await t.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: _wrap(const StreakChip(streak: 6, todayCounted: true)),
      ),
    );
    await t.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: _wrap(const StreakChip(streak: 7, todayCounted: true)),
      ),
    );
    await t.pump(const Duration(milliseconds: 150));
    expect(scale(), 1.0);
  });

  testWidgets('without onTap: no button', (t) async {
    final h = t.ensureSemantics();
    await t.pumpWidget(_wrap(const StreakChip(streak: 5, todayCounted: true)));
    final node = find.semantics.byLabel(RegExp('^Streak: 5 Tage')).evaluate();
    expect(node.single.label, 'Streak: 5 Tage');
    expect(node.single, isNot(matchesSemantics(isButton: true)));
    h.dispose();
  });

  testWidgets('with onTap: a button that sets the streak goal', (t) async {
    final h = t.ensureSemantics();
    var taps = 0;
    await t.pumpWidget(
      _wrap(StreakChip(streak: 5, todayCounted: false, onTap: () => taps++)),
    );

    await t.tap(find.byType(StreakChip));
    expect(taps, 1);

    expect(
      find.semantics.byLabel(RegExp('^Streak: 5 Tage')).evaluate().single,
      matchesSemantics(
        isButton: true,
        hasTapAction: true,
        label: 'Streak: 5 Tage, Heute noch offen',
        hint: 'Streak-Ziel festlegen',
        tooltip: 'Heute noch offen',
      ),
    );
    t.semantics.tap(find.semantics.byLabel(RegExp('^Streak: 5 Tage')));
    expect(taps, 2);
    h.dispose();
  });
}
