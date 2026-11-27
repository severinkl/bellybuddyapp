import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/models/alternative_choice.dart';

void main() {
  test('fromRow reads names from the two embeds and the kind from choice', () {
    final c = AlternativeChoice.fromRow({
      'id': 'c1',
      'ingredient_id': 'i1',
      'replacement_ingredient_id': 'r1',
      'choice': 'skip',
      'created_at': '2026-11-27T10:00:00+00:00',
      'ingredient': {'name': 'Zwiebel'},
      'replacement': {'name': 'Lauch'},
    });
    expect(c.id, 'c1');
    expect(c.ingredientId, 'i1');
    expect(c.ingredientName, 'Zwiebel');
    expect(c.replacementId, 'r1');
    expect(c.replacementName, 'Lauch');
    expect(c.kind, AlternativeChoiceKind.skip);
    expect(c.createdAt, DateTime.utc(2026, 11, 27, 10));
  });

  test('fromRow reads try', () {
    final c = AlternativeChoice.fromRow({
      'id': 'c1',
      'ingredient_id': 'i1',
      'replacement_ingredient_id': 'r1',
      'choice': 'try',
      'created_at': '2026-11-27T10:00:00+00:00',
      'ingredient': {'name': 'Zwiebel'},
      'replacement': {'name': 'Lauch'},
    });
    expect(c.kind, AlternativeChoiceKind.tryIt);
  });
}
