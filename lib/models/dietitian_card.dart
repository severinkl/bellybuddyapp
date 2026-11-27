import 'package:freezed_annotation/freezed_annotation.dart';

part 'dietitian_card.freezed.dart';
part 'dietitian_card.g.dart';

/// A dietitian's profession as they state it; json keys as core's
/// `PROFESSIONS`. A client always sees it with „(eigene Angabe)".
enum DietitianProfession {
  dietologin('Diätolog:in'),
  aerztin('Ärzt:in'),
  ernaehrungswissenschafterin('Ernährungswissenschafter:in'),
  andere('Andere');

  const DietitianProfession(this.label);

  final String label;
}

/// A dietitian as the client sees them: the `practice-code` card, or the
/// `dietitians` embed of a share (which adds `blocked_at`).
@freezed
abstract class DietitianCard with _$DietitianCard {
  const DietitianCard._();

  const factory DietitianCard({
    required String name,
    @JsonKey(unknownEnumValue: DietitianProfession.andere)
    required DietitianProfession profession,
    String? practice,
    required String town,
    @JsonKey(name: 'blocked_at') DateTime? blockedAt,
  }) = _DietitianCard;

  factory DietitianCard.fromJson(Map<String, dynamic> json) =>
      _$DietitianCardFromJson(json);

  /// Blocked by the Belly Buddy team: the connection is paused.
  bool get isBlocked => blockedAt != null;

  /// „Diätolog:in (eigene Angabe) · Praxis …, Innsbruck".
  String get line =>
      '${profession.label} (eigene Angabe) · '
      '${practice == null ? '' : '$practice, '}$town';
}
