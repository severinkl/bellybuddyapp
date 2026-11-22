import 'dart:math';

import 'package:belly_buddy/config/buddy_reactions.dart';
import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/screens/registration/steps/symptoms_step.dart';
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
    for (final s in kRegistrationSymptoms) 'symptom:$s',
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

  test('{name} only appears in name:confirmed', () {
    for (final e in kWizardReactions.entries) {
      final has = e.value.lines.any((l) => l.contains('{name}'));
      expect(has, e.key == 'name:confirmed', reason: e.key);
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
}
