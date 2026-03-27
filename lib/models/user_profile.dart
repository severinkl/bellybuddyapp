import 'package:freezed_annotation/freezed_annotation.dart';
import '../utils/reminder_times_converter.dart';

part 'user_profile.freezed.dart';
part 'user_profile.g.dart';

@freezed
abstract class UserProfile with _$UserProfile {
  const factory UserProfile({
    @JsonKey(name: 'user_id') String? userId,
    @JsonKey(name: 'birth_year') int? birthYear,
    String? gender,
    int? height,
    int? weight,
    String? diet,
    @Default([]) List<String> symptoms,
    @Default([]) List<String> intolerances,
    @JsonKey(name: 'auth_method') String? authMethod,
    @JsonKey(name: 'reminder_times')
    @ReminderTimesConverter()
    @Default(['18:00'])
    List<String> reminderTimes,
    @Default('Europe/Berlin') String? timezone,
    @JsonKey(name: 'fructose_triggers')
    @Default([])
    List<String> fructoseTriggers,
    @JsonKey(name: 'lactose_triggers')
    @Default([])
    List<String> lactoseTriggers,
    @JsonKey(name: 'histamin_triggers')
    @Default([])
    List<String> histaminTriggers,
    @JsonKey(name: 'reminders_enabled') @Default(true) bool remindersEnabled,
    @JsonKey(name: 'daily_summary_enabled')
    @Default(true)
    bool dailySummaryEnabled,
    @JsonKey(name: 'push_enabled') @Default(false) bool pushEnabled,
    @JsonKey(name: 'daily_summary_time')
    @Default('20:00')
    String dailySummaryTime,
    @JsonKey(name: 'fcm_token') String? fcmToken,
    @JsonKey(name: 'notification_modal_shown')
    @Default(false)
    bool notificationModalShown,
    @JsonKey(name: 'last_inactivity_nudge') DateTime? lastInactivityNudge,
  }) = _UserProfile;

  const UserProfile._();

  factory UserProfile.fromJson(Map<String, dynamic> json) =>
      _$UserProfileFromJson(json);

  bool get isComplete =>
      birthYear != null &&
      gender != null &&
      height != null &&
      weight != null &&
      diet != null;
}
