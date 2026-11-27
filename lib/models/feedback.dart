/// What a feedback message is about; [jsonValue] is the API's `category`.
enum FeedbackCategory {
  idea('idea', 'Idee'),
  problem('problem', 'Problem'),
  praise('praise', 'Lob'),
  other('other', 'Sonstiges');

  const FeedbackCategory(this.jsonValue, this.label);

  final String jsonValue;
  final String label;
}

/// What the app sends along with a feedback message.
class FeedbackContext {
  const FeedbackContext({
    required this.appVersion,
    required this.platform,
    required this.osVersion,
  });

  final String appVersion;

  /// `ios` or `android`.
  final String platform;
  final String osVersion;

  /// The system as people read it: `iOS 18.1`, `Android 14`.
  String get systemLabel =>
      '${platform == 'ios' ? 'iOS' : 'Android'} $osVersion';
}
