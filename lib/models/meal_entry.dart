import 'package:freezed_annotation/freezed_annotation.dart';

import '../utils/wall_clock.dart';

part 'meal_entry.freezed.dart';
part 'meal_entry.g.dart';

@freezed
abstract class MealEntry with _$MealEntry {
  const factory MealEntry({
    required String id,
    @JsonKey(name: 'user_id') String? userId,

    /// When the user logged it: local wall-clock time, not an instant (see
    /// `utils/wall_clock.dart`).
    @JsonKey(name: 'tracked_at')
    @WallClockConverter()
    required DateTime trackedAt,
    required String title,
    @Default([]) List<String> ingredients,
    @JsonKey(name: 'image_url') String? imageUrl,
    String? notes,

    /// When the row was created: a real instant (server `now()`).
    @JsonKey(name: 'created_at') DateTime? createdAt,
  }) = _MealEntry;

  factory MealEntry.fromJson(Map<String, dynamic> json) =>
      _$MealEntryFromJson(json);
}
