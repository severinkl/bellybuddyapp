import 'package:freezed_annotation/freezed_annotation.dart';

part 'toilet_entry.freezed.dart';
part 'toilet_entry.g.dart';

@freezed
abstract class ToiletEntry with _$ToiletEntry {
  const factory ToiletEntry({
    required String id,
    @JsonKey(name: 'user_id') String? userId,
    @JsonKey(name: 'tracked_at') required DateTime trackedAt,
    @JsonKey(name: 'stool_type') required int stoolType,
    String? notes,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  }) = _ToiletEntry;

  factory ToiletEntry.fromJson(Map<String, dynamic> json) =>
      _$ToiletEntryFromJson(json);
}
