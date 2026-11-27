import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/models/pattern_stats.dart';
import 'package:belly_buddy/services/insights/stats_copy.dart';

StatItem _item({
  String kind = 'ingredient',
  String key = 'zwiebel',
  String name = 'Zwiebel',
  StatLevel level = StatLevel.strong,
  int exposed = 10,
  int exposedHard = 7,
  int unexposed = 31,
  int unexposedHard = 2,
}) => StatItem(
  kind: kind,
  key: key,
  name: name,
  level: level,
  exposed: exposed,
  exposedHard: exposedHard,
  unexposed: unexposed,
  unexposedHard: unexposedHard,
);

void main() {
  test('row line: „nach 7 von 10 Tagen mit Zwiebel ein schwerer Tag · ohne: '
      '2 von 31"', () {
    expect(
      StatsCopy.rowLine(_item()),
      'nach 7 von 10 Tagen mit Zwiebel ein schwerer Tag · ohne: 2 von 31',
    );
  });

  test('a group row reads its name in the dative where German needs it', () {
    expect(
      StatsCopy.rowLine(
        _item(
          kind: 'group',
          key: 'fructans',
          name: 'Fruktane',
          level: StatLevel.noticed,
          exposed: 12,
          exposedHard: 8,
          unexposed: 29,
          unexposedHard: 4,
        ),
      ),
      'nach 8 von 12 Tagen mit Fruktanen ein schwerer Tag · ohne: 4 von 29',
    );
    expect(
      StatsCopy.rowLine(_item(kind: 'group', key: 'lactose', name: 'Laktose')),
      startsWith('nach 7 von 10 Tagen mit Laktose ein'),
    );
  });

  test('counts read „von {E} Tagen" for E ≥ 2 and the calm line „an 1 Tag" '
      'never appears (calm needs E ≥ 8)', () {
    for (final e in [2, 4, 8, 40]) {
      expect(
        StatsCopy.rowLine(_item(exposed: e, exposedHard: 1)),
        contains('von $e Tagen mit'),
      );
    }
    for (final e in [8, 18]) {
      final line = StatsCopy.calmLine(
        _item(key: 'reis', name: 'Reis', level: StatLevel.calm, exposed: e),
      );
      expect(line, 'Reis · an $e Tagen gegessen, nicht öfter schwere Tage');
      expect(line, isNot(contains('an 1 Tag ')));
    }
  });

  test('badges', () {
    expect(StatsCopy.badge(StatLevel.strong), 'deutlich auffällig');
    expect(StatsCopy.badge(StatLevel.noticed), 'auffällig');
    expect(StatsCopy.badge(StatLevel.unsure), 'noch unsicher');
  });

  test('not ready counts the rated days', () {
    expect(
      StatsCopy.notReady(9),
      'Für diesen Vergleich brauche ich 14 Tage mit Bauchgefühl – bisher 9.',
    );
  });

  test('the five limits of §4.5, in order', () {
    expect(StatsCopy.limits, hasLength(5));
    expect(StatsCopy.limits.first, startsWith('Was oft zusammen'));
    expect(StatsCopy.limits.last, contains('aus unserem Katalog'));
  });
}
