import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/models/data_share.dart';
import 'package:belly_buddy/models/dietitian_card.dart';

Map<String, dynamic> _json({
  String period = '30d',
  bool photos = false,
  String? lockedAt,
  String? revokedAt,
  String? expiresAt = '2026-12-10T12:00:00Z',
  String kind = 'link',
  Map<String, dynamic>? dietitian,
  Map<String, dynamic>? keeper,
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
  'kind': kind,
  'dietitian_id': dietitian == null ? null : 'd-1',
  'kept_by': keeper == null ? null : 'd-2',
  'dietitian': dietitian,
  'keeper': keeper,
};

Map<String, dynamic> _card({String? blockedAt}) => {
  'name': 'Julia Berger',
  'profession': 'dietologin',
  'practice': null,
  'town': 'Innsbruck',
  'blocked_at': blockedAt,
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

  group('dietitian shares', () {
    test('kind defaults to link, no embeds', () {
      final s = DataShare.fromJson(_json());
      expect(s.kind, ShareKind.link);
      expect(s.dietitian, isNull);
      expect(s.keeper, isNull);
      expect(s.isPaused, isFalse);
    });

    test('a connection parses and round trips with its embed', () {
      final s = DataShare.fromJson(
        _json(kind: 'dietitian', expiresAt: null, dietitian: _card()),
      );
      expect(s.kind, ShareKind.dietitian);
      expect(s.dietitianId, 'd-1');
      expect(s.expiresAt, isNull);
      expect(s.dietitian!.name, 'Julia Berger');
      expect(s.dietitian!.profession, DietitianProfession.dietologin);
      expect(DataShare.fromJson(s.toJson()), s);
      expect(s.toJson()['kind'], 'dietitian');
      expect(s.toJson()['dietitian'], isA<Map<String, dynamic>>());
    });

    test('a kept link round trips with its keeper', () {
      final s = DataShare.fromJson(_json(keeper: _card()));
      expect(s.kind, ShareKind.link);
      expect(s.keptBy, 'd-2');
      expect(s.keeper!.town, 'Innsbruck');
      expect(DataShare.fromJson(s.toJson()), s);
    });

    test('dietitian null after the dietitian deleted their account', () {
      final s = DataShare.fromJson(
        _json(kind: 'dietitian', expiresAt: null, dietitian: null),
      );
      expect(s.dietitian, isNull);
      expect(s.dietitianId, isNull);
      expect(s.isPaused, isFalse);
      expect(DataShare.fromJson(s.toJson()), s);
    });

    test('null expiresAt never expires', () {
      final s = DataShare.fromJson(_json(expiresAt: null));
      expect(s.stateAt(DateTime.utc(2100)), ShareState.active);
      expect(s.stoppedAt, isNull);
      final ended = DataShare.fromJson(
        _json(expiresAt: null, revokedAt: '2026-11-25T00:00:00Z'),
      );
      expect(ended.stateAt(now), ShareState.ended);
      expect(ended.stoppedAt, DateTime.utc(2026, 11, 25));
    });

    test('isPaused: a connection to a blocked dietitian', () {
      final blocked = _card(blockedAt: '2026-11-25T00:00:00Z');
      expect(
        DataShare.fromJson(
          _json(kind: 'dietitian', dietitian: blocked),
        ).isPaused,
        isTrue,
      );
      expect(
        DataShare.fromJson(
          _json(kind: 'dietitian', dietitian: _card()),
        ).isPaused,
        isFalse,
      );
      // A kept link of a blocked dietitian is not a paused connection.
      expect(DataShare.fromJson(_json(keeper: blocked)).isPaused, isFalse);
    });
  });
}
