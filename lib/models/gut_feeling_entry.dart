import 'package:freezed_annotation/freezed_annotation.dart';

part 'gut_feeling_entry.freezed.dart';
part 'gut_feeling_entry.g.dart';

@freezed
abstract class GutFeelingEntry with _$GutFeelingEntry {
  const factory GutFeelingEntry({
    required String id,
    @JsonKey(name: 'user_id') String? userId,
    @JsonKey(name: 'tracked_at') required DateTime trackedAt,
    required int bloating,
    required int gas,
    required int cramps,
    required int fullness,
    int? stress,
    int? happiness,
    int? energy,
    int? focus,
    @JsonKey(name: 'body_feel') int? bodyFeel,
    String? notes,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  }) = _GutFeelingEntry;

  factory GutFeelingEntry.fromJson(Map<String, dynamic> json) =>
      _$GutFeelingEntryFromJson(json);
}
