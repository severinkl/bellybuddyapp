import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/knowledge/knowledge_matcher.dart';
import '../utils/settled_value.dart';
import 'insights_provider.dart';
import 'knowledge_opened_provider.dart';
import 'knowledge_provider.dart';
import 'profile_provider.dart';
import 'progress_provider.dart';

/// The Wissen articles „Für dich" (spec §4.2): at most [forYouMax], each
/// with its reason, none the user opened.
///
/// Empty until the feed, the profile and the opened articles have values
/// (so a pick never shows and then vanishes once the opened ones are read).
/// The Muster ([insightsProvider]) and this week's entries
/// ([progressProvider]'s `recent`) are optional: picks work without them,
/// and a value is left out while it is the previous user's (reloading
/// after a user change) or failed.
///
/// Subscription seam: `includePatterns` is `true` until the subscription
/// track replaces it with „Plus access is open", so a locked user's reason
/// line never leaks the paid Muster result. Knowledge itself stays free.
final forYouProvider = Provider<List<ForYouPick>>((ref) {
  final feed = ref.watch(knowledgeFeedProvider).value;
  final profile = ref.watch(profileProvider);
  final opened = ref.watch(knowledgeOpenedProvider).currentValue;
  if (feed == null || profile is! AsyncData || opened == null) {
    return const [];
  }
  // Watched only once the rest is there, so they load only when needed.
  final insights = ref.watch(insightsProvider).currentValue;
  final progress = ref.watch(progressProvider).currentValue;
  return pickForYou(
    feed.articles,
    forYouSignals(
      profile: profile.value,
      insights: insights,
      recent: progress?.recent,
      includePatterns: true,
    ),
    opened: opened,
  );
});
