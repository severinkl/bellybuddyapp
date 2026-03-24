import '../models/user_profile.dart';

abstract final class IntoleranceHelpers {
  /// Returns the trigger list for a given intolerance name.
  static List<String> triggersFor(String intolerance, UserProfile profile) {
    return switch (intolerance) {
      'Fruktose' => profile.fructoseTriggers,
      'Laktose' => profile.lactoseTriggers,
      'Histamin' => profile.histaminTriggers,
      _ => [],
    };
  }

  /// Returns a new [UserProfile] with the triggers for [intolerance] updated.
  static UserProfile updateTriggers(
    String intolerance,
    UserProfile profile,
    List<String> triggers,
  ) {
    return switch (intolerance) {
      'Fruktose' => profile.copyWith(fructoseTriggers: triggers),
      'Laktose' => profile.copyWith(lactoseTriggers: triggers),
      'Histamin' => profile.copyWith(histaminTriggers: triggers),
      _ => profile,
    };
  }
}
