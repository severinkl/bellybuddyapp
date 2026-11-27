import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/services/rating/rating_rules.dart';

import '../../helpers/fixtures.dart';

void main() {
  group('ratingAskAllowed', () {
    bool allowed({
      String current = '1.3.0',
      String? asked,
      DateTime? last,
      required DateTime today,
    }) => ratingAskAllowed(
      currentVersion: current,
      askedVersion: asked,
      lastAsk: last,
      today: today,
    );

    test('never asked: allowed', () {
      expect(allowed(today: DateTime(2026, 11, 26)), isTrue);
    });

    test('same version: not allowed, even after 400 days', () {
      expect(
        allowed(
          asked: '1.3.0',
          last: DateTime(2025, 10, 22),
          today: DateTime(2026, 11, 26),
        ),
        isFalse,
      );
    });

    test('new version after 89 days: not allowed; after 90 days: allowed', () {
      final last = DateTime(2026, 9, 1);
      expect(
        allowed(asked: '1.2.0', last: last, today: DateTime(2026, 11, 29)),
        isFalse,
      );
      expect(
        allowed(asked: '1.2.0', last: last, today: DateTime(2026, 11, 30)),
        isTrue,
      );
    });

    test('90 days are calendar days: asked 1 Sep 23:59, today 30 Nov '
        '00:01 allowed, 29 Nov not', () {
      final last = DateTime(2026, 9, 1, 23, 59);
      expect(
        allowed(
          asked: '1.2.0',
          last: last,
          today: DateTime(2026, 11, 30, 0, 1),
        ),
        isTrue,
      );
      expect(
        allowed(asked: '1.2.0', last: last, today: DateTime(2026, 11, 29, 23)),
        isFalse,
      );
    });
  });

  group('hasHardEntryToday', () {
    final today = DateTime(2026, 11, 26);
    // Gut score 4-5 is „Schlecht".
    final hard = [5, 5, 5, 5];
    final medium = [3, 3, 3, 3];

    test('a Schlecht entry today counts; a Mittel one does not; a Schlecht '
        'entry yesterday at 23:59 wall clock does not', () {
      var gut = testGutFeelingEntry(
        trackedAt: DateTime(2026, 11, 26, 8),
        bloating: hard[0],
        gas: hard[1],
        cramps: hard[2],
        fullness: hard[3],
      );
      expect(hasHardEntryToday([gut], today), isTrue);
      gut = testGutFeelingEntry(
        trackedAt: DateTime(2026, 11, 26, 8),
        bloating: medium[0],
        gas: medium[1],
        cramps: medium[2],
        fullness: medium[3],
      );
      expect(hasHardEntryToday([gut], today), isFalse);
      gut = testGutFeelingEntry(
        trackedAt: DateTime(2026, 11, 25, 23, 59),
        bloating: 5,
        gas: 5,
        cramps: 5,
        fullness: 5,
      );
      expect(hasHardEntryToday([gut], today), isFalse);
    });

    test('an entry stored as 2026-11-26T23:30:00Z is on 26 Nov whatever '
        'the device zone', () {
      final gut = testGutFeelingEntry(
        trackedAt: DateTime.utc(2026, 11, 26, 23, 30),
        bloating: 5,
        gas: 5,
        cramps: 5,
        fullness: 5,
      );
      expect(hasHardEntryToday([gut], today), isTrue);
    });
  });
}
