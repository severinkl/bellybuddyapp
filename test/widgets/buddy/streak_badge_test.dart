import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/widgets/buddy/streak_badge.dart';
import 'package:belly_buddy/widgets/buddy/streak_flame.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Widget _wrap(Widget c, {bool reducedMotion = false, double textScale = 1}) =>
    MediaQuery(
      data: MediaQueryData(
        disableAnimations: reducedMotion,
        textScaler: TextScaler.linear(textScale),
      ),
      child: MaterialApp(
        theme: AppTheme.theme,
        home: Scaffold(body: Center(child: c)),
      ),
    );

Widget _badge(int streak, {bool lit = true, VoidCallback? onTap}) =>
    StreakBadge(streak: streak, lit: lit, onTap: onTap ?? () {});

void main() {
  /// The pill inside its tap area.
  Rect pill(WidgetTester t) => t.getRect(
    find.descendant(
      of: find.byType(StreakBadge),
      matching: find.byType(DecoratedBox),
    ),
  );

  testWidgets('the drawn flame and the count, also at 0', (t) async {
    for (final streak in [12, 1, 0]) {
      await t.pumpWidget(_wrap(_badge(streak)));
      expect(
        find.descendant(
          of: find.byType(StreakBadge),
          matching: find.byType(StreakFlame),
        ),
        findsOneWidget,
      );
      expect(find.text('$streak'), findsOneWidget);
      expect(find.textContaining('Tag'), findsNothing);
      expect(find.textContaining('🔥'), findsNothing);
    }
  });

  testWidgets('a button: „Streak: n Tage, Dein Streak öffnen"', (t) async {
    final h = t.ensureSemantics();
    for (final (streak, lit, label) in [
      (12, true, 'Streak: 12 Tage, Dein Streak öffnen'),
      (1, true, 'Streak: 1 Tag, Dein Streak öffnen'),
      (0, false, 'Streak: 0 Tage, Dein Streak öffnen'),
      // While today is open, it says so.
      (5, false, 'Streak: 5 Tage, heute noch offen, Dein Streak öffnen'),
      (1, false, 'Streak: 1 Tag, heute noch offen, Dein Streak öffnen'),
    ]) {
      await t.pumpWidget(_wrap(_badge(streak, lit: lit)));
      expect(
        find.semantics.byLabel(RegExp('^Streak:')).evaluate().single,
        matchesSemantics(isButton: true, hasTapAction: true, label: label),
      );
    }
    h.dispose();
  });

  testWidgets('its tap area is at least 48 × 48 dp, the pill centred in it', (
    t,
  ) async {
    var taps = 0;
    await t.pumpWidget(_wrap(_badge(5, onTap: () => taps++)));

    final badge = t.getRect(find.byType(StreakBadge));
    expect(badge.height, greaterThanOrEqualTo(AppConstants.homeTapTarget));
    expect(badge.width, greaterThanOrEqualTo(AppConstants.homeTapTarget));
    expect(pill(t).height, lessThan(AppConstants.homeTapTarget));
    expect(pill(t).center, badge.center);

    await t.tapAt(badge.topLeft + const Offset(1, 1));
    expect(taps, 1);
  });

  testWidgets('three digits at text scale 2 fit, at the user\'s size', (
    t,
  ) async {
    await t.pumpWidget(_wrap(_badge(128), textScale: 2));

    expect(t.takeException(), isNull);
    final count = t.widget<Text>(find.text('128'));
    expect(count.textScaler, isNull);
    expect(pill(t).width, greaterThan(t.getSize(find.text('128')).width));
    expect(find.byType(FittedBox), findsNothing);
  });

  testWidgets('its flame an ember while today is open, lit once it counts', (
    t,
  ) async {
    FlameLook look() => t
        .widget<StreakFlame>(
          find.descendant(
            of: find.byType(StreakBadge),
            matching: find.byType(StreakFlame),
          ),
        )
        .look;
    await t.pumpWidget(_wrap(_badge(5, lit: false)));
    expect(look(), FlameLook.ember);
    await t.pumpWidget(_wrap(_badge(0, lit: false)));
    expect(look(), FlameLook.ember);
    await t.pumpWidget(_wrap(_badge(5)));
    expect(look(), FlameLook.lit);
  });

  testWidgets('muted while today is open', (t) async {
    Color? colour() => t.widget<Text>(find.text('5')).style?.color;
    await t.pumpWidget(_wrap(_badge(5, lit: false)));
    expect(colour(), AppTheme.mutedForeground);
    await t.pumpWidget(_wrap(_badge(5)));
    expect(colour(), AppTheme.foreground);
    // Nothing to keep at 0: never muted.
    await t.pumpWidget(_wrap(_badge(0, lit: false)));
    expect(t.widget<Text>(find.text('0')).style?.color, AppTheme.foreground);
  });

  testWidgets('pops on increase, not under reduced motion', (t) async {
    double scale() => t
        .widget<ScaleTransition>(
          find.descendant(
            of: find.byType(StreakBadge),
            matching: find.byType(ScaleTransition),
          ),
        )
        .scale
        .value;
    await t.pumpWidget(_wrap(_badge(5)));
    await t.pumpWidget(_wrap(_badge(6)));
    await t.pump(const Duration(milliseconds: 150));
    expect(scale(), greaterThan(1.1));
    await t.pumpAndSettle();
    expect(scale(), 1.0);

    await t.pumpWidget(_wrap(_badge(6), reducedMotion: true));
    await t.pumpWidget(_wrap(_badge(7), reducedMotion: true));
    await t.pump(const Duration(milliseconds: 150));
    expect(scale(), 1.0);
  });
}
