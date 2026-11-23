import 'package:flutter/widgets.dart' show BuildContext;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/core_providers.dart';
import '../providers/profile_provider.dart';
import '../repositories/profile_repository.dart';
import '../router/route_names.dart';
import '../utils/logger.dart';

/// The dashboard onboarding tutorial: whether to show it ([shouldShow]),
/// marking it seen ([markSeen]) and replaying it from the Ich tab
/// ([replayFrom]).
///
/// The "seen" state lives on [UserProfile.tutorialSeenAt] and is read via
/// [profileProvider]. The state here is whether a replay is pending (in
/// memory only): set by [requestReplay], taken once by [consumeReplay];
/// Home listens to it.
class TutorialNotifier extends Notifier<bool> {
  static const _log = AppLogger('TutorialProvider');

  @override
  bool build() => false;

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

  /// Asks Home to show the tour again, even when it was seen. Pending until
  /// [consumeReplay] takes it; a second request before that is the same
  /// one. Home takes it after its first load, or at once when already
  /// built — so the caller must then go Home. [replayFrom] does both.
  void requestReplay() => state = true;

  /// Whether a replay was requested: true exactly once per [requestReplay].
  bool consumeReplay() {
    if (!state) return false;
    state = false;
    return true;
  }

  /// „Tutorial wiederholen": requests the replay and goes Home, where the
  /// tour starts.
  void replayFrom(BuildContext context) {
    requestReplay();
    context.go(RoutePaths.dashboard);
  }
}

final tutorialProvider = NotifierProvider<TutorialNotifier, bool>(
  TutorialNotifier.new,
);
