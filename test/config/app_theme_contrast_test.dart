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
}
