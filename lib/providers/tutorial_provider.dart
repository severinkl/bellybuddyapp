import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/core_providers.dart';
import '../providers/profile_provider.dart';
import '../repositories/profile_repository.dart';
import '../utils/logger.dart';

/// Action-only notifier for the dashboard onboarding tutorial.
///
/// The "seen" state itself lives on [UserProfile.tutorialSeenAt] and is read
/// via [profileProvider]. This notifier exposes the mutating action
/// ([markSeen]), a convenience query ([shouldShow]) and the replay request
/// from the Ich tab ([requestReplay], taken with [consumeReplay]).
class TutorialNotifier extends Notifier<void> {
  static const _log = AppLogger('TutorialProvider');

  @override
  void build() {}

  /// Whether the overlay should be displayed for the current profile.
  bool shouldShow() {
    final profile = ref.read(profileProvider).whenOrNull(data: (p) => p);
    return profile != null && profile.tutorialSeenAt == null;
  }

  /// Marks the tutorial as seen now. Called on normal completion and on
  /// "Überspringen". Safe to call even if the write fails — we log and
  /// continue so the UI isn't blocked on the network.
  Future<void> markSeen() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    try {
      await ref
          .read(profileRepositoryProvider)
          .updateTutorialSeenAt(userId, DateTime.now().toUtc());
      await ref.read(profileProvider.notifier).fetchProfile();
    } catch (e, st) {
      _log.error('markSeen failed', e, st);
    }
  }

  /// Asks Home to show the tour again, even when it was seen („Tutorial
  /// wiederholen" in the Ich tab). Pending until [consumeReplay] takes it;
  /// a second request before that is the same one.
  void requestReplay() => ref.read(tutorialReplayProvider.notifier)._request();

  /// Whether a replay was requested: true exactly once per [requestReplay].
  bool consumeReplay() => ref.read(tutorialReplayProvider.notifier)._consume();
}

final tutorialProvider = NotifierProvider<TutorialNotifier, void>(
  TutorialNotifier.new,
);

/// Whether a tour replay is pending (in memory only). Set and taken only
/// through [TutorialNotifier.requestReplay] and
/// [TutorialNotifier.consumeReplay]; Home listens to it.
class TutorialReplayNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void _request() => state = true;

  bool _consume() {
    if (!state) return false;
    state = false;
    return true;
  }
}

final tutorialReplayProvider = NotifierProvider<TutorialReplayNotifier, bool>(
  TutorialReplayNotifier.new,
);
