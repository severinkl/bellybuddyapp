import 'package:freezed_annotation/freezed_annotation.dart';

part 'buddy_state.freezed.dart';
part 'buddy_state.g.dart';

/// Converts a Postgres `date[]` ('yyyy-MM-dd' strings) to local-midnight
/// [DateTime]s and back.
class DateOnlyListConverter
    implements JsonConverter<List<DateTime>, List<dynamic>> {
  const DateOnlyListConverter();

  @override
  List<DateTime> fromJson(List<dynamic> json) => json.map((e) {
    final parts = (e as String).split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }).toList();

  @override
  List<dynamic> toJson(List<DateTime> object) => object.map((d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year.toString().padLeft(4, '0')}-$m-$day';
  }).toList();
}

@freezed
abstract class BuddyState with _$BuddyState {
  const factory BuddyState({
    String? id,
    @JsonKey(name: 'user_id') String? userId,
    @Default('Buddy') String name,
    @JsonKey(name: 'streak_goal') int? streakGoal,
    @Default(0) int savers,
    @JsonKey(name: 'saved_days')
    @DateOnlyListConverter()
    @Default(<DateTime>[])
    List<DateTime> savedDays,
    @JsonKey(name: 'last_milestone') @Default(0) int lastMilestone,
    @JsonKey(name: 'onboarding_completed_at') DateTime? onboardingCompletedAt,
  }) = _BuddyState;

  factory BuddyState.fromJson(Map<String, dynamic> json) =>
      _$BuddyStateFromJson(json);
}
