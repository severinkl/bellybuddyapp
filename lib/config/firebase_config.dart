class FirebaseConfig {
  static const String androidApiKey = String.fromEnvironment(
    'FIREBASE_ANDROID_API_KEY',
  );
  static const String androidAppId = String.fromEnvironment(
    'FIREBASE_ANDROID_APP_ID',
  );
  static const String iosApiKey = String.fromEnvironment(
    'FIREBASE_IOS_API_KEY',
  );
  static const String iosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const String messagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const String projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const String storageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
  );
  static const String iosBundleId = String.fromEnvironment(
    'FIREBASE_IOS_BUNDLE_ID',
  );
}
