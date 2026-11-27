import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/models/dietitian_card.dart';

void main() {
  test('profession json keys and labels', () {
    expect(
      {for (final p in DietitianProfession.values) p.name: p.label},
      {
        'dietologin': 'Diätolog:in',
        'aerztin': 'Ärzt:in',
        'ernaehrungswissenschafterin': 'Ernährungswissenschafter:in',
        'andere': 'Andere',
      },
    );
    for (final p in DietitianProfession.values) {
      final card = DietitianCard.fromJson({
        'name': 'X',
        'profession': p.name,
        'town': 'Wien',
      });
      expect(card.profession, p);
      expect(card.toJson()['profession'], p.name);
    }
  });

  test('parses a card without practice and blocked_at (practice-code)', () {
    final card = DietitianCard.fromJson({
      'name': 'Julia Berger',
      'profession': 'dietologin',
      'practice': null,
      'town': 'Innsbruck',
    });
    expect(card.name, 'Julia Berger');
    expect(card.practice, isNull);
    expect(card.blockedAt, isNull);
    expect(card.isBlocked, isFalse);
    expect(card.line, 'Diätolog:in (eigene Angabe) · Innsbruck');
  });

  test('line with practice', () {
    final card = DietitianCard.fromJson({
      'name': 'Julia Berger',
      'profession': 'dietologin',
      'practice': 'Praxis für Ernährungstherapie',
      'town': 'Innsbruck',
    });
    expect(
      card.line,
      'Diätolog:in (eigene Angabe) · Praxis für Ernährungstherapie, Innsbruck',
    );
  });

  test('blocked and round trip', () {
    final card = DietitianCard.fromJson({
      'name': 'Max Muster',
      'profession': 'aerztin',
      'practice': 'Praxis Muster',
      'town': 'Graz',
      'blocked_at': '2026-11-25T08:00:00Z',
    });
    expect(card.isBlocked, isTrue);
    expect(card.blockedAt, DateTime.utc(2026, 11, 25, 8));
    expect(DietitianCard.fromJson(card.toJson()), card);
  });
}
