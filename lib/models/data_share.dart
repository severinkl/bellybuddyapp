import 'package:freezed_annotation/freezed_annotation.dart';

part 'data_share.freezed.dart';
part 'data_share.g.dart';

/// How far back a share reaches; json `14d` | `30d` | `all`.
enum SharePeriod {
  @JsonValue('14d')
  days14('14d', 'Letzte 14 Tage'),
  @JsonValue('30d')
  days30('30d', 'Letzte 30 Tage'),
  @JsonValue('all')
  all('all', 'Alle Einträge');

  const SharePeriod(this.jsonValue, this.label);

  final String jsonValue;

  /// The period phrase of [DataShare.description].
  final String label;
}

enum ShareState { active, ended, expired, locked }

/// A share of the user's diary, as PostgREST's `data_shares` returns it
/// (explicit column list: the hash columns are not readable). The timestamps
/// are real instants, unlike diary `tracked_at` values.
@freezed
abstract class DataShare with _$DataShare {
  const DataShare._();

  const factory DataShare({
    required String id,
    @JsonKey(name: 'display_name') required String displayName,
    required SharePeriod period,
    @JsonKey(name: 'share_meals') required bool shareMeals,
    @JsonKey(name: 'share_drinks') required bool shareDrinks,
    @JsonKey(name: 'share_gut') required bool shareGut,
    @JsonKey(name: 'share_toilet') required bool shareToilet,
    @JsonKey(name: 'share_patterns') required bool sharePatterns,
    @JsonKey(name: 'share_photos') required bool sharePhotos,
    @JsonKey(name: 'failed_codes') @Default(0) int failedCodes,
    @JsonKey(name: 'locked_at') DateTime? lockedAt,
    @JsonKey(name: 'revoked_at') DateTime? revokedAt,
    @JsonKey(name: 'last_opened_at') DateTime? lastOpenedAt,
    @JsonKey(name: 'open_count') @Default(0) int openCount,
    @JsonKey(name: 'expires_at') required DateTime expiresAt,
    @JsonKey(name: 'created_at') required DateTime createdAt,
  }) = _DataShare;

  factory DataShare.fromJson(Map<String, dynamic> json) =>
      _$DataShareFromJson(json);

  /// As core's `state_of`: ended, then locked, then expired, else active.
  ShareState stateAt(DateTime now) {
    if (revokedAt != null) return ShareState.ended;
    if (lockedAt != null) return ShareState.locked;
    if (!expiresAt.isAfter(now)) return ShareState.expired;
    return ShareState.active;
  }

  String get description =>
      '${period.label}, ${sharePhotos ? 'mit' : 'ohne'} Fotos';
}

/// What the user chose for a new share.
class NewShare {
  const NewShare({
    required this.displayName,
    required this.period,
    required this.validDays,
    required this.meals,
    required this.drinks,
    required this.gut,
    required this.toilet,
    required this.patterns,
    required this.photos,
  });

  final String displayName;
  final SharePeriod period;

  /// 7, 30 or 90.
  final int validDays;
  final bool meals;
  final bool drinks;
  final bool gut;
  final bool toilet;
  final bool patterns;
  final bool photos;
}

/// Core's answer to a created share. [link] and [code] are secrets: never
/// logged.
class CreatedShare {
  const CreatedShare({
    required this.id,
    required this.link,
    required this.code,
    required this.expiresAt,
  });

  final String id;
  final String link;
  final String code;
  final DateTime expiresAt;
}

/// The link and code of a share, kept on this device. Never logged.
class ShareSecret {
  const ShareSecret({required this.link, required this.code});

  final String link;
  final String code;
}
