import 'package:freezed_annotation/freezed_annotation.dart';

import '../utils/date_format_utils.dart';

part 'buddy_state.freezed.dart';
part 'buddy_state.g.dart';

/// Converts a Postgres `date` ('yyyy-MM-dd') to a local-midnight
/// [DateTime] and back.
class DateOnlyConverter implements JsonConverter<DateTime, String> {
  const DateOnlyConverter();

  @override
  DateTime fromJson(String json) {
    final parts = json.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  @override
  String toJson(DateTime object) => formatIsoDate(object);
}

/// Converts a Postgres `date[]` ('yyyy-MM-dd' strings) to local-midnight
/// [DateTime]s and back.
class DateOnlyListConverter
    implements JsonConverter<List<DateTime>, List<dynamic>> {
  const DateOnlyListConverter();

  @override
  List<DateTime> fromJson(List<dynamic> json) =>
      json.map((e) => const DateOnlyConverter().fromJson(e as String)).toList();

  @override
  List<dynamic> toJson(List<DateTime> object) =>
      object.map(const DateOnlyConverter().toJson).toList();
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

    /// The local day the run reached the milestone that last added a saver;
    /// milestones pay at most one saver per 7 days (see `evaluateStreak`).
    @JsonKey(name: 'last_saver_earned_on')
    @DateOnlyConverter()
    DateTime? lastSaverEarnedOn,
    @JsonKey(name: 'onboarding_completed_at') DateTime? onboardingCompletedAt,
  }) = _BuddyState;

  factory BuddyState.fromJson(Map<String, dynamic> json) =>
      _$BuddyStateFromJson(json);
}
