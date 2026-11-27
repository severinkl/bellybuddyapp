import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/config/app_theme.dart';

/// WCAG 2.x relative luminance of [c] (its alpha ignored).
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

/// WCAG 2.x contrast ratio between [a] and [b], from 1 to 21.
double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// [fg] at [alpha] blended over opaque [bg].
Color _over(Color fg, double alpha, Color bg) =>
    Color.alphaBlend(fg.withValues(alpha: alpha), bg);

void main() {
  test('the contrast helper matches the WCAG extremes', () {
    expect(_contrast(Colors.black, Colors.white), closeTo(21, 0.01));
    expect(_contrast(Colors.white, Colors.white), closeTo(1, 0.001));
  });

  // WCAG 1.4.11: the Muster calendar's class icons are its non-colour cue,
  // so each needs 3:1 against its day cell's fill, the page (legend) and
  // the day cards.
  for (final (name, icon, fill) in [
    ('gut', AppTheme.gutFeelingGoodIcon, AppTheme.gutFeelingGoodSoft),
    ('mittel', AppTheme.gutFeelingNeutralIcon, AppTheme.gutFeelingNeutralSoft),
    ('schwer', AppTheme.gutFeelingBadIcon, AppTheme.gutFeelingBadSoft),
  ]) {
    test('the $name icon has at least 3:1 on its fill, page and card', () {
      for (final background in [fill, AppTheme.background, AppTheme.card]) {
        expect(
          _contrast(icon, background),
          greaterThanOrEqualTo(3.0),
          reason: '$name icon on $background',
        );
      }
    });
  }

  test('each care colour has at least 3:1 on the page', () {
    for (final (name, color) in [
      ('careFood', AppTheme.careFood),
      ('careWater', AppTheme.careWater),
      ('careGut', AppTheme.careGut),
      ('careLoo', AppTheme.careLoo),
    ]) {
      expect(
        _contrast(color, AppTheme.background),
        greaterThanOrEqualTo(3.0),
        reason: name,
      );
    }
  });

  test('the ember on the primary colour (the success page) has at least '
      '3:1 on it; the pale one would not show there', () {
    expect(
      _contrast(AppTheme.streakEmberOnPrimary, AppTheme.primary),
      greaterThanOrEqualTo(3.0),
    );
    expect(
      _contrast(AppTheme.streakEmberCoreOnPrimary, AppTheme.primary),
      greaterThan(_contrast(AppTheme.streakEmberCore, AppTheme.primary)),
    );
    expect(_contrast(AppTheme.streakEmber, AppTheme.primary), lessThan(1.5));
  });

  test('placeholderGlyph is the foreground at 45 %', () {
    expect(
      AppTheme.placeholderGlyph,
      AppTheme.foreground.withValues(alpha: 0.45),
    );
  });

  test('every text pair has at least 4.5:1', () {
    final pages = [
      AppTheme.background,
      AppTheme.card,
      AppTheme.screenBackground,
    ];
    final pairs = <(String, Color, Color)>[
      for (final bg in [
        ...pages,
        AppTheme.muted,
        AppTheme.secondary,
        AppTheme.beige,
        AppTheme.primarySoft,
        AppTheme.gutFeelingGoodSoft,
      ])
        ('mutedForeground on $bg', AppTheme.mutedForeground, bg),
      for (final bg in [...pages, _over(AppTheme.primary, 0.15, Colors.white)])
        ('primaryText on $bg', AppTheme.primaryText, bg),
      for (final bg in [
        AppTheme.background,
        AppTheme.card,
        _over(AppTheme.destructive, 0.1, Colors.white),
      ])
        ('destructive on $bg', AppTheme.destructive, bg),
      ('white on destructive', Colors.white, AppTheme.destructive),
      for (final bg in [
        AppTheme.background,
        AppTheme.card,
        _over(AppTheme.successText, 0.1, Colors.white),
        AppTheme.gutFeelingGoodSoft,
      ])
        ('successText on $bg', AppTheme.successText, bg),
      (
        'gutFeelingNeutralText on soft',
        AppTheme.gutFeelingNeutralText,
        AppTheme.gutFeelingNeutralSoft,
      ),
      for (final bg in [
        AppTheme.background,
        _over(AppTheme.infoText, 0.1, Colors.white),
        AppTheme.screenBackground,
      ])
        ('infoText on $bg', AppTheme.infoText, bg),
      ('white on infoText', Colors.white, AppTheme.infoText),
      for (final bg in [
        AppTheme.navGradientStart,
        AppTheme.navGradientEnd,
        _over(Colors.white, 0.6, AppTheme.screenBackground),
      ])
        (
          'foregroundInactive on $bg',
          _over(AppTheme.foregroundInactive, AppTheme.foregroundInactive.a, bg),
          bg,
        ),
      ('white on badgeFill', Colors.white, AppTheme.badgeFill),
      // „Genauer hingeschaut"'s level badges.
      (
        'statBadgeStrongText on its fill',
        AppTheme.statBadgeStrongText,
        AppTheme.statBadgeStrongFill,
      ),
      ('foreground on muted', AppTheme.foreground, AppTheme.muted),
    ];
    for (final (name, fg, bg) in pairs) {
      expect(_contrast(fg, bg), greaterThanOrEqualTo(4.5), reason: name);
    }
  });

  test('the theme\'s TextButton draws its text in primaryText', () {
    expect(
      AppTheme.theme.textButtonTheme.style!.foregroundColor!.resolve({}),
      AppTheme.primaryText,
    );
  });

  test('shareActive and gutFeelingGoodText are successText', () {
    expect(AppTheme.shareActive, AppTheme.successText);
    expect(AppTheme.gutFeelingGoodText, AppTheme.successText);
  });
}
