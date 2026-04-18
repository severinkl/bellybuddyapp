import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/core_providers.dart';
import '../providers/profile_provider.dart';
import '../repositories/profile_repository.dart';
import '../utils/logger.dart';

/// Action-only notifier for the dashboard onboarding tutorial.
///
/// The "seen" state itself lives on [UserProfile.tutorialSeenAt] and is read
/// via [profileProvider]. This notifier exists only to expose the mutating
/// actions ([markSeen], [reset]) and a convenience query ([shouldShow]).
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

  /// Clears the seen-flag so the tutorial runs again on next dashboard open.
  /// Used by the "Tour neu starten" button in Settings.
  Future<void> reset() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    await ref
        .read(profileRepositoryProvider)
        .updateTutorialSeenAt(userId, null);
    await ref.read(profileProvider.notifier).fetchProfile();
  }
}

final tutorialProvider = NotifierProvider<TutorialNotifier, void>(
  TutorialNotifier.new,
);
