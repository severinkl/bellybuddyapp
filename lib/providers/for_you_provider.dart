import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_profile.dart';
import '../services/knowledge/knowledge_matcher.dart';
import 'auth_provider.dart';
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
/// A reload of the signed-in user's profile keeps the loaded one meanwhile
/// ([_forYouProfileProvider]).
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
  final profile = ref.watch(_forYouProfileProvider);
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

/// [profileProvider], except that while it reloads the signed-in user's
/// profile (app resume, pull to refresh: a fetch sets it loading) the
/// profile loaded for that user stays. Never another user's: a sign-out
/// resets the profile (no user loaded), and a user change starts over.
class _ForYouProfileNotifier extends Notifier<AsyncValue<UserProfile?>> {
  @override
  AsyncValue<UserProfile?> build() {
    final userId = ref.watch(currentUserIdProvider);
    ref.listen(profileProvider, (_, next) {
      // A fetch sets loading before it records whom it loads for, so here
      // loadedFor is still the user of the value held.
      final reloading =
          next.isLoading &&
          !next.hasValue &&
          state is AsyncData &&
          ref.read(profileProvider.notifier).loadedFor == userId;
      if (!reloading) state = next;
    });
    return ref.read(profileProvider);
  }
}

final _forYouProfileProvider =
    NotifierProvider<_ForYouProfileNotifier, AsyncValue<UserProfile?>>(
      _ForYouProfileNotifier.new,
    );
