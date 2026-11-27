import 'package:freezed_annotation/freezed_annotation.dart';
import '../config/constants.dart';
import '../utils/reminder_times_converter.dart';
import '../utils/symptoms_converter.dart';

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
    // Canonical values (kSymptomOptions); older spellings are read as them.
    @SymptomsConverter() @Default([]) List<String> symptoms,
    @Default([]) List<String> intolerances,
    @JsonKey(name: 'auth_method') String? authMethod,
    @JsonKey(name: 'meal_reminder_times')
    @ReminderTimesConverter()
    @Default(['18:00'])
    List<String> mealReminderTimes,
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
    @JsonKey(name: 'mood_reminder_times')
    @ReminderTimesConverter()
    @Default(['20:00'])
    List<String> moodReminderTimes,
    @JsonKey(name: 'fcm_token') String? fcmToken,
    @JsonKey(name: 'last_inactivity_nudge') DateTime? lastInactivityNudge,
    @JsonKey(name: 'tutorial_seen_at') DateTime? tutorialSeenAt,
    @JsonKey(name: 'email') String? email,
    // GDPR Art. 9 consent to health-data processing. Written only by
    // ProfileRepository.acceptHealthConsent, never by profile updates.
    @JsonKey(name: 'health_consent_at') DateTime? healthConsentAt,
    @JsonKey(name: 'privacy_policy_version') String? privacyPolicyVersion,
    // Opt-in to the weekly AI tips. Written only by
    // ProfileRepository.setWeeklyTips, never by profile updates.
    @JsonKey(name: 'weekly_tips_enabled')
    @Default(false)
    bool weeklyTipsEnabled,
    // From this local time ('HH:MM') Home shows the daily review.
    @JsonKey(name: 'daily_review_time')
    @Default(AppConstants.dailyReviewDefaultTime)
    String dailyReviewTime,
    // Opt-in to the evening notice that the daily review is there.
    @JsonKey(name: 'daily_review_reminder')
    @Default(false)
    bool dailyReviewReminder,
  }) = _UserProfile;

  const UserProfile._();

  factory UserProfile.fromJson(Map<String, dynamic> json) =>
      _$UserProfileFromJson(json);

  /// Whether any notification is on: a meal or Bauchgefühl reminder, tips,
  /// the daily review's evening notice.
  /// These say what the user wants; they only arrive while the OS allows
  /// notifications (see `NotificationPermission`).
  bool get anyNotificationOn =>
      remindersEnabled ||
      dailySummaryEnabled ||
      pushEnabled ||
      dailyReviewReminder;

  /// This profile with every notification [on] (or off). The daily review's
  /// evening notice stays opt-in: switched off with the rest, never on.
  UserProfile withNotifications(bool on) => copyWith(
    remindersEnabled: on,
    dailySummaryEnabled: on,
    pushEnabled: on,
    dailyReviewReminder: on && dailyReviewReminder,
  );

  bool get isComplete =>
      birthYear != null &&
      gender != null &&
      height != null &&
      weight != null &&
      diet != null;
}
