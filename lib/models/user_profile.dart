import 'package:freezed_annotation/freezed_annotation.dart';

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
    @JsonKey(name: 'reminder_times') @Default([18]) List<int> reminderTimes,
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
