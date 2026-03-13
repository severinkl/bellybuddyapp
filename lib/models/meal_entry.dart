import 'package:freezed_annotation/freezed_annotation.dart';

part 'meal_entry.freezed.dart';
part 'meal_entry.g.dart';

@freezed
abstract class MealEntry with _$MealEntry {
  const factory MealEntry({
    required String id,
    @JsonKey(name: 'user_id') String? userId,
    @JsonKey(name: 'tracked_at') required DateTime trackedAt,
    required String title,
    @Default([]) List<String> ingredients,
    @JsonKey(name: 'image_url') String? imageUrl,
    String? notes,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  }) = _MealEntry;

  factory MealEntry.fromJson(Map<String, dynamic> json) =>
      _$MealEntryFromJson(json);
}
