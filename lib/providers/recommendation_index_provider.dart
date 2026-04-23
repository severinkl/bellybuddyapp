import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks the currently-visible PageView index in `RecommendationsScreen`.
///
/// The screen seeds this to `recommendations.length - 1` (the latest) on
/// first data-resolve. `onPageChanged` writes to it; chevron taps call
/// [RecommendationIndexNotifier.set] and a `ref.listen` on the screen
/// animates the PageController to match.
class RecommendationIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void set(int index) => state = index;
}

final recommendationIndexProvider =
    NotifierProvider<RecommendationIndexNotifier, int>(
      RecommendationIndexNotifier.new,
    );
