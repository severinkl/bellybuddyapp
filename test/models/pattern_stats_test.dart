import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/models/pattern_stats.dart';

Map<String, dynamic> _item(
  String key, {
  String level = 'noticed',
  String? nestedIn,
  String kind = 'ingredient',
}) => {
  'kind': kind,
  'key': key,
  'name': key,
  'level': level,
  'exposed': 12,
  'exposed_hard': 8,
  'unexposed': 29,
  'unexposed_hard': 4,
  'groups': <String>[],
  'nested_in': nestedIn,
};

void main() {
  test('parses the §4.6 sample exactly', () {
    final stats = PatternStats.fromJson({
      'window_days': 90,
      'rated_days': 41,
      'hard_days': 9,
      'ready': true,
      'groups': [
        {
          'kind': 'group',
          'key': 'fructans',
          'name': 'Fruktane',
          'level': 'noticed',
          'exposed': 12,
          'exposed_hard': 8,
          'unexposed': 29,
          'unexposed_hard': 4,
        },
      ],
      'ingredients': [
        {
          'kind': 'ingredient',
          'key': 'zwiebel',
          'name': 'Zwiebel',
          'level': 'strong',
          'exposed': 10,
          'exposed_hard': 7,
          'unexposed': 31,
          'unexposed_hard': 2,
          'groups': ['fructans'],
          'nested_in': 'fructans',
        },
      ],
      'calm': [
        {
          'kind': 'ingredient',
          'key': 'reis',
          'name': 'Reis',
          'level': 'calm',
          'exposed': 18,
          'exposed_hard': 2,
          'unexposed': 23,
          'unexposed_hard': 7,
          'groups': [],
          'nested_in': null,
          'future_field': 1,
        },
      ],
      'test': null,
    });

    expect(stats.windowDays, 90);
    expect(stats.ratedDays, 41);
    expect(stats.hardDays, 9);
    expect(stats.ready, isTrue);
    final g = stats.groups.single;
    expect(
      (g.kind, g.key, g.name, g.level, g.exposed, g.exposedHard),
      ('group', 'fructans', 'Fruktane', StatLevel.noticed, 12, 8),
    );
    expect((g.unexposed, g.unexposedHard), (29, 4));
    expect(g.groups, isEmpty);
    expect(g.nestedIn, isNull);
    final z = stats.ingredients.single;
    expect(
      (z.key, z.name, z.level, z.exposed, z.exposedHard),
      ('zwiebel', 'Zwiebel', StatLevel.strong, 10, 7),
    );
    expect((z.unexposed, z.unexposedHard), (31, 2));
    expect(z.groups, ['fructans']);
    expect(z.nestedIn, 'fructans');
    final r = stats.calm.single;
    expect(
      (r.key, r.level, r.exposed, r.nestedIn),
      ('reis', StatLevel.calm, 18, null),
    );
  });

  test('not ready: empty lists', () {
    final stats = PatternStats.fromJson({
      'window_days': 90,
      'rated_days': 3,
      'hard_days': 0,
      'ready': false,
      'groups': [],
      'ingredients': [],
      'calm': [],
    });
    expect(stats.ready, isFalse);
    expect(stats.ratedDays, 3);
    expect(stats.groups, isEmpty);
  });

  test('an unknown level drops that item, keeps the others', () {
    final stats = PatternStats.fromJson({
      'window_days': 90,
      'rated_days': 41,
      'hard_days': 9,
      'ready': true,
      'groups': [
        _item('a', level: 'severe', kind: 'group'),
        _item('b', kind: 'group'),
      ],
      'ingredients': [_item('c'), _item('d', level: 'mystery'), _item('e')],
      'calm': [],
    });
    expect([for (final g in stats.groups) g.key], ['b']);
    expect([for (final i in stats.ingredients) i.key], ['c', 'e']);
    expect(StatLevel.fromWire('strong'), StatLevel.strong);
    expect(StatLevel.fromWire('nope'), isNull);
  });

  test('a malformed item (missing count, wrong type) is dropped, the rest '
      'stays', () {
    final stats = PatternStats.fromJson({
      'window_days': 90,
      'rated_days': 41,
      'hard_days': 9,
      'ready': true,
      'groups': [_item('a', kind: 'group')..remove('exposed')],
      'ingredients': [
        _item('c'),
        _item('d')..['unexposed_hard'] = 'vier',
        'not a map',
        _item('e'),
      ],
      'calm': [],
    });
    expect(stats.groups, isEmpty);
    expect([for (final i in stats.ingredients) i.key], ['c', 'e']);
  });

  test('membersOf and loose split ingredients by nestedIn', () {
    final stats = PatternStats.fromJson({
      'window_days': 90,
      'rated_days': 41,
      'hard_days': 9,
      'ready': true,
      'groups': [
        _item('fructans', kind: 'group'),
        _item('lactose', kind: 'group'),
      ],
      'ingredients': [
        _item('zwiebel', nestedIn: 'fructans'),
        _item('kaese'),
        _item('knoblauch', nestedIn: 'fructans'),
        _item('milch', nestedIn: 'lactose'),
      ],
      'calm': [],
    });
    expect(
      [for (final i in stats.membersOf(stats.groups[0])) i.key],
      ['zwiebel', 'knoblauch'],
    );
    expect(
      [for (final i in stats.membersOf(stats.groups[1])) i.key],
      ['milch'],
    );
    expect([for (final i in stats.loose) i.key], ['kaese']);
  });
}
