import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/models/data_share.dart';

Map<String, dynamic> _json({
  String period = '30d',
  bool photos = false,
  String? lockedAt,
  String? revokedAt,
  String expiresAt = '2026-12-10T12:00:00Z',
}) => {
  'id': 'share-1',
  'display_name': 'Dr. Muster',
  'period': period,
  'share_meals': true,
  'share_drinks': true,
  'share_gut': false,
  'share_toilet': true,
  'share_patterns': false,
  'share_photos': photos,
  'failed_codes': 2,
  'locked_at': lockedAt,
  'revoked_at': revokedAt,
  'last_opened_at': '2026-11-25T08:00:00Z',
  'open_count': 3,
  'expires_at': expiresAt,
  'created_at': '2026-11-20T10:00:00+00:00',
};

void main() {
  final now = DateTime.utc(2026, 11, 26, 12);

  test('parses PostgREST snake_case keys', () {
    final s = DataShare.fromJson(_json());
    expect(s.id, 'share-1');
    expect(s.displayName, 'Dr. Muster');
    expect(s.period, SharePeriod.days30);
    expect(s.shareMeals, isTrue);
    expect(s.shareGut, isFalse);
    expect(s.failedCodes, 2);
    expect(s.openCount, 3);
    expect(s.lockedAt, isNull);
    expect(s.lastOpenedAt, DateTime.utc(2026, 11, 25, 8));
    expect(s.expiresAt, DateTime.utc(2026, 12, 10, 12));
    expect(s.createdAt, DateTime.utc(2026, 11, 20, 10));
  });

  test('round trips through JSON', () {
    final s = DataShare.fromJson(_json(lockedAt: '2026-11-24T00:00:00Z'));
    expect(DataShare.fromJson(s.toJson()), s);
    expect(s.toJson()['period'], '30d');
  });

  test('period json values', () {
    expect(DataShare.fromJson(_json(period: '14d')).period, SharePeriod.days14);
    expect(DataShare.fromJson(_json(period: 'all')).period, SharePeriod.all);
  });

  group('stateAt', () {
    test('active', () {
      expect(DataShare.fromJson(_json()).stateAt(now), ShareState.active);
    });

    test('ended', () {
      final s = DataShare.fromJson(_json(revokedAt: '2026-11-25T00:00:00Z'));
      expect(s.stateAt(now), ShareState.ended);
    });

    test('locked', () {
      final s = DataShare.fromJson(_json(lockedAt: '2026-11-25T00:00:00Z'));
      expect(s.stateAt(now), ShareState.locked);
    });

    test('expired, also exactly at expiry', () {
      final s = DataShare.fromJson(_json(expiresAt: '2026-11-26T12:00:00Z'));
      expect(s.stateAt(now), ShareState.expired);
      expect(
        s.stateAt(now.subtract(const Duration(seconds: 1))),
        ShareState.active,
      );
    });

    test('precedence: ended > locked > expired', () {
      final all = DataShare.fromJson(
        _json(
          revokedAt: '2026-11-25T00:00:00Z',
          lockedAt: '2026-11-24T00:00:00Z',
          expiresAt: '2026-11-01T00:00:00Z',
        ),
      );
      expect(all.stateAt(now), ShareState.ended);
      final lockedExpired = DataShare.fromJson(
        _json(
          lockedAt: '2026-11-24T00:00:00Z',
          expiresAt: '2026-11-01T00:00:00Z',
        ),
      );
      expect(lockedExpired.stateAt(now), ShareState.locked);
    });
  });

  group('description', () {
    test('30 days without photos', () {
      expect(
        DataShare.fromJson(_json()).description,
        'Letzte 30 Tage, ohne Fotos',
      );
    });
    test('14 days with photos', () {
      expect(
        DataShare.fromJson(_json(period: '14d', photos: true)).description,
        'Letzte 14 Tage, mit Fotos',
      );
    });
    test('all entries', () {
      expect(
        DataShare.fromJson(_json(period: 'all')).description,
        'Alle Einträge, ohne Fotos',
      );
    });
  });
}
