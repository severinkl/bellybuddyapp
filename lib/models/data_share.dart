import 'package:freezed_annotation/freezed_annotation.dart';

import 'dietitian_card.dart';

part 'data_share.freezed.dart';
part 'data_share.g.dart';

/// How far back a share reaches; json `14d` | `30d` | `all`.
@JsonEnum(valueField: 'jsonValue')
enum SharePeriod {
  days14('14d', 'Letzte 14 Tage'),
  days30('30d', 'Letzte 30 Tage'),
  all('all', 'Alle Einträge');

  const SharePeriod(this.jsonValue, this.label);

  final String jsonValue;

  /// The period phrase of [DataShare.description].
  final String label;
}

enum ShareState { active, ended, expired, locked }

/// A share by link (stage 1) or a connection to a dietitian.
enum ShareKind { link, dietitian }

/// How long a connection to a dietitian lasts; json `90d` | `open`.
@JsonEnum(valueField: 'jsonValue')
enum ShareDuration {
  days90('90d'),
  open('open');

  const ShareDuration(this.jsonValue);

  final String jsonValue;
}

/// A share of the user's diary, as PostgREST's `data_shares` returns it
/// (explicit column list: the hash columns are not readable). The timestamps
/// are real instants, unlike diary `tracked_at` values.
///
/// A `dietitian` share embeds its dietitian as [dietitian] (null once the
/// dietitian deleted their account); a link a dietitian kept embeds them as
/// [keeper]. [expiresAt] is null for an open-ended connection.
@freezed
abstract class DataShare with _$DataShare {
  const DataShare._();

  @JsonSerializable(explicitToJson: true)
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
    @JsonKey(name: 'expires_at') DateTime? expiresAt,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @Default(ShareKind.link) ShareKind kind,
    @JsonKey(name: 'dietitian_id') String? dietitianId,
    @JsonKey(name: 'kept_by') String? keptBy,
    DietitianCard? dietitian,
    DietitianCard? keeper,
  }) = _DataShare;

  factory DataShare.fromJson(Map<String, dynamic> json) =>
      _$DataShareFromJson(json);

  /// A connection whose dietitian deleted their account: core removed the
  /// dietitian, so it is over whatever its dates say.
  bool get isDietitianGone =>
      kind == ShareKind.dietitian && dietitianId == null && dietitian == null;

  /// As core's `state_of`: ended, then locked, then expired, else active.
  /// A null [expiresAt] never expires. A connection to a deleted dietitian
  /// is ended.
  ShareState stateAt(DateTime now) {
    if (revokedAt != null || isDietitianGone) return ShareState.ended;
    if (lockedAt != null) return ShareState.locked;
    final end = expiresAt;
    if (end != null && !end.isAfter(now)) return ShareState.expired;
    return ShareState.active;
  }

  /// When the share stopped, in [stateAt]'s order; for an active share its
  /// coming end, null when it has none. Never null for a share that is not
  /// active. A deleted dietitian's connection without any stop date counts
  /// from [createdAt], so it still ages out of the list.
  DateTime? get stoppedAt =>
      revokedAt ??
      lockedAt ??
      expiresAt ??
      (isDietitianGone ? createdAt : null);

  /// A connection whose dietitian the Belly Buddy team blocked: core shows
  /// them nothing until it is lifted.
  bool get isPaused =>
      kind == ShareKind.dietitian && dietitian?.isBlocked == true;

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

/// What the user chose for a connection to a dietitian; the body of
/// `shares/dietitian` (with the code) and `shares/{id}/update`.
class DietitianShareTerms {
  const DietitianShareTerms({
    required this.displayName,
    required this.period,
    required this.duration,
    required this.meals,
    required this.drinks,
    required this.gut,
    required this.toilet,
    required this.patterns,
    required this.photos,
  });

  final String displayName;
  final SharePeriod period;
  final ShareDuration duration;
  final bool meals;
  final bool drinks;
  final bool gut;
  final bool toilet;
  final bool patterns;
  final bool photos;

  Map<String, Object> toBody() => {
    'display_name': displayName,
    'period': period.jsonValue,
    'duration': duration.jsonValue,
    'meals': meals,
    'drinks': drinks,
    'gut': gut,
    'toilet': toilet,
    'patterns': patterns,
    'photos': photos,
  };
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
