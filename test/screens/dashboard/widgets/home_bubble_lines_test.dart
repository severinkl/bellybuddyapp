import 'dart:io';

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/providers/buddy_welcome_provider.dart';
import 'package:belly_buddy/services/buddy/buddy_copy.dart';
import 'package:belly_buddy/services/journey/journey_copy.dart';
import 'package:belly_buddy/widgets/buddy/buddy.dart';

import '../../../helpers/ambient_animations.dart';
import '../../../helpers/app_host.dart';
import '../../../helpers/layout_checks.dart';

/// The Flutter SDK's Roboto, which every `flutter test` run has.
File _roboto(String face) => File(
  '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/'
  'material_fonts/Roboto-$face.ttf',
);

/// [font] with every glyph's advance [factor] times as wide.
Uint8List _widened(Uint8List font, double factor) {
  final data = ByteData.sublistView(font);
  int table(String tag) {
    for (var i = 0; i < data.getUint16(4); i++) {
      final record = 12 + 16 * i;
      if (String.fromCharCodes(font, record, record + 4) == tag) {
        return data.getUint32(record + 8);
      }
    }
    throw StateError('no $tag table');
  }

  final hmtx = table('hmtx');
  final advances = data.getUint16(table('hhea') + 34);
  for (var i = 0; i < advances; i++) {
    final at = hmtx + 4 * i;
    data.setUint16(at, (data.getUint16(at) * factor).round());
  }
  return font;
}

/// How much wider SF Pro Text's semibold sets the Home lines than Roboto's
/// bold (by about 6 % at 15 pt, measured with CoreText), plus a margin.
const _sfWidth = 1.07;

/// Every line the dashboard's Buddy says, at its longest: a name of
/// [AppConstants.buddyNameMaxLength] characters and a four-digit streak.
List<String> _homeLines() {
  const name = 'Maximilian Bauchwohl';
  const streak = 1000;
  String fill(String line) => BuddyCopy.fill(line, name: name, streak: streak);
  return {
    // His resting lines: what he needs next, else his mood's.
    for (final pool in BuddyCopy.care.values) ...pool.map(fill),
    for (final pool in BuddyCopy.careAfterLog.values) ...pool.map(fill),
    for (final pool in BuddyCopy.mood.values) ...pool.map(fill),
    ...BuddyCopy.sleepyNight.map(fill),
    // A log's follow-up, the onboarding's welcome and the announcements.
    BuddyCopy.streakThanks(streak),
    BuddyWelcomeNotifier.line,
    BuddyCopy.saverUsed,
    BuddyCopy.streakBroken,
    BuddyCopy.saverEarned,
    BuddyCopy.tipsArrived,
    JourneyCopy.firstTipStarted,
    JourneyCopy.firstTipFailed(weeklyTipsOn: true),
    JourneyCopy.firstTipFailed(weeklyTipsOn: false),
  }.toList();
}

/// Its own file: the fonts it loads stay loaded for the whole file.
void main() {
  final fonts = [_roboto('Regular'), _roboto('Medium'), _roboto('Bold')];
  final available = fonts.every((f) => f.existsSync());

  setUpAll(() async {
    if (!available) return;
    // The theme's family, so lines wrap as words, not as the test font's
    // squares. The bubble's semibold (w600) draws with the bold face, set
    // as wide as SF Pro's: a line wraps here as on an iPhone.
    final loader = FontLoader('.SF Pro Text');
    for (final font in fonts) {
      final wide = _widened(font.readAsBytesSync(), _sfWidth);
      loader.addFont(Future.value(ByteData.sublistView(wide)));
    }
    await loader.load();
  });
  setUp(
    () => SharedPreferences.setMockInitialValues({
      AppConstants.keyNotificationModalShown: true,
    }),
  );
  tearDown(disableAmbientAnimationsForTests);

  for (final phone in [
    (
      name: '375×667 at text scale 1.3',
      size: const Size(375, 667),
      dpr: 2.0,
      top: 20.0,
      bottom: 0.0,
      textScale: 1.3,
    ),
    (
      name: '402×874 at text scale 1.0',
      size: const Size(402, 874),
      dpr: 3.0,
      top: 62.0,
      bottom: 34.0,
      textScale: 1.0,
    ),
  ]) {
    testWidgets('${phone.name}: every Home line shows whole, never drawn '
        'below the base text size', (tester) async {
      AnimatedBuddy.tickerEnabled = true;
      tester.view
        ..physicalSize = phone.size * phone.dpr
        ..devicePixelRatio = phone.dpr
        ..padding = FakeViewPadding(
          top: phone.top * phone.dpr,
          bottom: phone.bottom * phone.dpr,
        );
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = phone.textScale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final container = ProviderContainer.test(overrides: baseOverrides());
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const AppTestHost(),
        ),
      );
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final buddy = tester
          .widget<AnimatedBuddy>(find.byType(AnimatedBuddy))
          .controller;

      final failures = <String>[];
      for (final line in _homeLines()) {
        buddy.say(line, duration: null);
        // It reaches the bubble on the Buddy's next tick, then pops in.
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pump(AppConstants.animNormal);
        await tester.pump(const Duration(milliseconds: 16));
        expect(buddy.bubble, line);

        final text = find.descendant(
          of: find.byType(BuddySpeechBubble),
          matching: find.byType(RichText),
        );
        final paragraph = tester.renderObject<RenderParagraph>(text);
        final lines =
            (paragraph.size.height /
                    phone.textScale /
                    (AppTheme.fontSizeBodyLG * AppTheme.lineHeightSnug))
                .round();
        final shown = drawnScale(tester.element(text)) * phone.textScale;
        if (paragraph.didExceedMaxLines || shown < 1 - 1e-6) {
          failures.add(
            '„$line" (${line.length} chars): $lines lines, '
            '${paragraph.didExceedMaxLines ? 'cut, ' : ''}'
            'drawn at ${shown.toStringAsFixed(3)}× the base size',
          );
        }
      }
      expect(failures, isEmpty, reason: failures.join('\n'));
      expect(tester.takeException(), isNull);
    }, skip: !available);
  }
}
