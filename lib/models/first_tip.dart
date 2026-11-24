/// What core's `diet-recommendations` answered to the day-3 first tip: the
/// saved set's [id] (null when saving it failed) and how many [tips] it
/// holds.
class FirstTipResult {
  const FirstTipResult({this.id, required this.tips});

  final String? id;
  final int tips;

  /// A saved set with at least one tip; anything else counts as failed.
  bool get ok => id != null && tips > 0;
}

/// Thrown by `RecommendationService.requestFirstTip`: an error answer with
/// its HTTP [status], or (null) no answer or one that can't be read.
class FirstTipException implements Exception {
  const FirstTipException([this.status]);

  final int? status;

  @override
  String toString() => 'FirstTipException($status)';
}
