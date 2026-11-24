import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/utils/wall_clock.dart';

/// CI runs these tests under `TZ=Europe/Vienna`; run them locally with
/// `TZ=Europe/Vienna flutter test` too. Under UTC a wall clock and an
/// instant look alike, which is how the entry-time bugs hid.
void main() {
  test(
    'TZ=Europe/Vienna reaches the Dart clock',
    () {
      expect(DateTime(2026, 1, 15).timeZoneOffset, const Duration(hours: 1));
      expect(DateTime(2026, 7, 15).timeZoneOffset, const Duration(hours: 2));
    },
    skip: Platform.environment['TZ'] == 'Europe/Vienna'
        ? false
        : 'only under TZ=Europe/Vienna',
  );

  group('wallClockFromWire', () {
    test('a PostgREST value: its UTC fields are the local wall clock', () {
      final t = wallClockFromWire('2026-11-24T04:38:00+00:00');

      expect(t, DateTime(2026, 11, 24, 4, 38));
      expect(t.isUtc, isFalse);
    });

    test('a late-evening entry stays on its day', () {
      expect(
        wallClockFromWire('2026-11-24T23:30:00+00:00'),
        DateTime(2026, 11, 24, 23, 30),
      );
    });

    test('a summer (CEST) evening stays on its day', () {
      expect(
        wallClockFromWire('2026-07-14T22:15:00+00:00'),
        DateTime(2026, 7, 14, 22, 15),
      );
    });

    test('a Z value reads the same', () {
      expect(
        wallClockFromWire('2026-11-24T04:38:00.000Z'),
        DateTime(2026, 11, 24, 4, 38),
      );
    });

    test('an offset-less value reads as written', () {
      expect(
        wallClockFromWire('2026-11-24T04:38:00.000'),
        DateTime(2026, 11, 24, 4, 38),
      );
    });

    test('keeps seconds, milliseconds and microseconds', () {
      expect(
        wallClockFromWire('2026-11-24T04:38:12.345678+00:00'),
        DateTime(2026, 11, 24, 4, 38, 12, 345, 678),
      );
    });
  });

  group('wallClockToWire', () {
    test('sends the local wall clock in the UTC slot, marked Z', () {
      expect(
        wallClockToWire(DateTime(2026, 11, 24, 4, 38)),
        '2026-11-24T04:38:00.000Z',
      );
    });

    test('local midnight is midnight on the wire (day bounds)', () {
      expect(
        wallClockToWire(DateTime(2026, 11, 24)),
        '2026-11-24T00:00:00.000Z',
      );
      expect(
        wallClockToWire(DateTime(2026, 7, 14)),
        '2026-07-14T00:00:00.000Z',
      );
    });

    test('a UTC instant is sent as its local wall clock', () {
      final local = DateTime(2026, 11, 24, 4, 38);

      expect(wallClockToWire(local.toUtc()), wallClockToWire(local));
    });

    test('round-trips through wallClockFromWire', () {
      final t = DateTime(2026, 11, 24, 23, 30, 5, 120);

      expect(wallClockFromWire(wallClockToWire(t)), t);
    });
  });

  group('WallClockConverter', () {
    const converter = WallClockConverter();

    test('fromJson reads the wire value as wall clock', () {
      expect(
        converter.fromJson('2026-11-24T23:30:00+00:00'),
        DateTime(2026, 11, 24, 23, 30),
      );
    });

    test('toJson writes the wall clock as Z', () {
      expect(
        converter.toJson(DateTime(2026, 11, 24, 23, 30)),
        '2026-11-24T23:30:00.000Z',
      );
    });
  });
}
