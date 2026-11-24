import 'dart:math';

import 'package:belly_buddy/config/buddy_reactions.dart';
import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/config/symptom_options.dart';
import 'package:belly_buddy/widgets/buddy/buddy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final keys = <String>[
    'name:intro',
    'name:confirmed',
    'consent:intro',
    'birthYear:any',
    'heightWeight:any',
    'auth:intro',
    'emailCapture:intro',
    for (final g in ['weiblich', 'männlich', 'andere']) 'gender:$g',
    for (final d in ['alles', 'vegetarisch', 'vegan']) 'diet:$d',
    for (final s in kRegistrationSymptomOptions) 'symptom:${s.value}',
    'symptom:none',
    for (final i in AppConstants.intoleranceOptions) 'intolerance:$i',
    'intolerance:none',
    for (final s in [
      'birthYear',
      'gender',
      'heightWeight',
      'diet',
      'symptoms',
      'intolerances',
    ])
      'step:$s',
  ];

  test('every key exists', () {
    for (final k in keys) {
      expect(wizardReaction(k), isNotNull, reason: k);
    }
  });

  test('lines are valid', () {
    for (final e in kWizardReactions.entries) {
      expect(e.value.lines, isNotEmpty, reason: e.key);
      expect(e.value.lines.length, lessThanOrEqualTo(3), reason: e.key);
      for (final l in e.value.lines) {
        expect(l.trim(), isNotEmpty);
        expect(l.length, lessThanOrEqualTo(70), reason: '${e.key}: $l');
        expect(l.contains('TODO'), isFalse);
      }
    }
  });

  test('„merk ich mir" stays rare across the whole catalog', () {
    final merk = [
      for (final e in kWizardReactions.values)
        ...e.lines.where((l) => l.toLowerCase().contains('merk')),
    ];
    expect(merk.length, lessThanOrEqualTo(2), reason: merk.join('\n'));
  });

  test('multi-select answers never share a line', () {
    // Symptoms and intolerances react per tap, several in a row: a line
    // shared between two answers would make the Buddy repeat himself.
    for (final group in ['symptom:', 'intolerance:']) {
      final seen = <String, String>{};
      for (final e in kWizardReactions.entries) {
        if (!e.key.startsWith(group)) continue;
        for (final l in e.value.lines) {
          expect(seen[l], isNull, reason: '"$l" in ${seen[l]} and ${e.key}');
          seen[l] = e.key;
        }
      }
    }
  });

  test('every answer reaction has at least two variants', () {
    for (final e in kWizardReactions.entries) {
      final isAnswer =
          e.key.startsWith('symptom:') || e.key.startsWith('intolerance:');
      if (!isAnswer || e.key.endsWith(':none')) continue;
      expect(e.value.lines.length, greaterThanOrEqualTo(2), reason: e.key);
    }
  });

  test('{name} only appears in name:confirmed', () {
    for (final e in kWizardReactions.entries) {
      final has = e.value.lines.any((l) => l.contains('{name}'));
      expect(has, e.key == 'name:confirmed', reason: e.key);
    }
  });

  test('the gender reactions acknowledge the answer, they don\'t greet', () {
    // The Buddy asked „Welches biologische Geschlecht hast du?": a greeting
    // („Hallo du!", „Schön, dass du da bist!") doesn't answer that.
    final greeting = RegExp(r'Hallo|kennenzulernen|da bist|freu mich auf uns');
    for (final g in ['weiblich', 'männlich', 'andere']) {
      for (final l in wizardReaction('gender:$g')!.lines) {
        expect(greeting.hasMatch(l), isFalse, reason: 'gender:$g: $l');
      }
    }
  });

  test('wizardKey builds keys', () {
    expect(wizardKey('gender', 'weiblich'), 'gender:weiblich');
    expect(wizardKey('birthYear'), 'birthYear:any');
  });

  test('pick is deterministic for seeded Random', () {
    final line = wizardReaction('symptom:none')!;
    expect(line.pick(Random(3)), line.pick(Random(3)));
    expect(line.lines, contains(line.pick(Random(7))));
  });

  test('react plays the mood and action and says a line with the name', () {
    final line = wizardReaction('name:confirmed')!;
    final c = BuddyController()
      ..react(
        line,
        name: 'Bauchi',
        rnd: Random(1),
        duration: const Duration(seconds: 1),
      );
    expect(c.mood, line.mood);
    expect(c.currentAction, line.action);
    expect(
      line.lines.map((l) => l.replaceAll('{name}', 'Bauchi')),
      contains(c.bubble),
    );
    expect(c.bubble, isNot(contains('{name}')));
    c.dispose();
  });

  testWidgets('react with a hold returns to the resting line', (tester) async {
    final line = wizardReaction('name:confirmed')!;
    final c = BuddyController()..rest('Wie viele Tage schaffen wir?');
    addTearDown(c.dispose);
    c.react(
      line,
      name: 'Bauchi',
      rnd: Random(1),
      hold: const Duration(seconds: 4),
    );
    expect(c.mood, line.mood);
    expect(c.currentAction, line.action);
    expect(
      line.lines.map((l) => l.replaceAll('{name}', 'Bauchi')),
      contains(c.bubble),
    );

    await tester.pump(const Duration(seconds: 4));
    expect(c.bubble, 'Wie viele Tage schaffen wir?');
  });

  test('isValidBuddyName: 1 to 20 characters after trimming', () {
    expect(AppConstants.isValidBuddyName('Bauchi'), isTrue);
    expect(AppConstants.isValidBuddyName('  Bauchi  '), isTrue);
    expect(AppConstants.isValidBuddyName('   '), isFalse);
    expect(AppConstants.isValidBuddyName(''), isFalse);
    expect(AppConstants.isValidBuddyName('a' * 20), isTrue);
    expect(AppConstants.isValidBuddyName('a' * 21), isFalse);
    expect(AppConstants.isValidBuddyName('🍎' * 20), isTrue);
  });
}
