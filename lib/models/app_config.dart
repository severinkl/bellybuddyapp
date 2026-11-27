/// Remote settings read from the `app_config` table: the version thresholds
/// compared against the installed app's semver, and remote feature switches
/// (Plus paywall, Ruhe für den Bauch).
class AppConfig {
  const AppConfig({
    required this.minimum,
    required this.latest,
    this.paywallEnabled = false,
    this.akuthilfeEnabled = false,
  });

  /// Clients below this version are blocked with the "Update erforderlich"
  /// screen until they update.
  final String minimum;

  /// Clients below this version (but at or above [minimum]) see a dismissible
  /// "Update verfügbar" nudge on cold start.
  final String latest;

  /// Belly Buddy Plus switch (`paywall_enabled`): on only for the exact value
  /// `'true'`. Off ⇒ the app behaves as before Plus and never touches the
  /// purchases SDK.
  final bool paywallEnabled;

  /// Remote switch of "Ruhe für den Bauch" (`akuthilfe_enabled`); only the
  /// value `true` turns it on, a missing row means off.
  final bool akuthilfeEnabled;
}
