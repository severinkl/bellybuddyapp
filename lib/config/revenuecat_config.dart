/// RevenueCat public SDK keys, passed in with `--dart-define-from-file=env.json`.
///
/// Empty (the default) means the store purchase SDK is not available on this
/// build; the app still runs. Deliberately not part of `_validateEnv`.
class RevenueCatConfig {
  static const String iosKey = String.fromEnvironment('REVENUECAT_IOS_KEY');
  static const String androidKey = String.fromEnvironment(
    'REVENUECAT_ANDROID_KEY',
  );
}
