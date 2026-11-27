import 'package:freezed_annotation/freezed_annotation.dart';

import 'dietitian_card.dart';

part 'dietitian_tip.freezed.dart';
part 'dietitian_tip.g.dart';

/// A „Tipp von deiner Berater:in": a `dietitian_recommendations` row.
/// [senderName] and [senderProfession] (an unknown key reads „Andere")
/// are copied at sending, so a tip keeps its sender
/// after the connection ends. [body] is the dietitian's text as typed: shown
/// as plain text, never logged.
@freezed
abstract class DietitianTip with _$DietitianTip {
  const DietitianTip._();

  const factory DietitianTip({
    required String id,
    @JsonKey(name: 'sender_name') required String senderName,
    @JsonKey(
      name: 'sender_profession',
      unknownEnumValue: DietitianProfession.andere,
    )
    required DietitianProfession senderProfession,
    required String body,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'seen_at') DateTime? seenAt,
    @JsonKey(name: 'trying_at') DateTime? tryingAt,
  }) = _DietitianTip;

  factory DietitianTip.fromJson(Map<String, dynamic> json) =>
      _$DietitianTipFromJson(json);

  bool get isNew => seenAt == null;
}
