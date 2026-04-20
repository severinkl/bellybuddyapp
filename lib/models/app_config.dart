/// Version thresholds read from the Supabase `app_config` table and compared
/// against the installed app's semver.
class AppConfig {
  const AppConfig({required this.minimum, required this.latest});

  /// Clients below this version are blocked with the "Update erforderlich"
  /// screen until they update.
  final String minimum;

  /// Clients below this version (but at or above [minimum]) see a dismissible
  /// "Update verfügbar" nudge on cold start.
  final String latest;
}
