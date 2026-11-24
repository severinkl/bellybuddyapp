import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_provider.dart';

/// A line the dashboard's Buddy says first, once: the Buddy onboarding sets
/// it right before it opens the dashboard. It belongs to the signed-in
/// user: signing out (or another user) drops it.
///
/// Home's tour waits for it ([played]): the Buddy greets first, then the
/// tour explains Home.
class BuddyWelcomeNotifier extends Notifier<String?> {
  /// The dashboard greeting after the Buddy onboarding.
  static const line = 'Willkommen daheim! Hier sehen wir uns jeden Tag.';

  /// Pending from [set] until the Buddy has said the line ([markPlayed]).
  Completer<void>? _played;

  @override
  String? build() {
    ref.watch(currentUserIdProvider);
    _release();
    return null;
  }

  void set(String text) {
    _release();
    _played = Completer<void>();
    state = text;
  }

  /// Returns the pending line and clears it. [played] stays pending until
  /// [markPlayed].
  String? take() {
    final text = state;
    state = null;
    return text;
  }

  /// The Buddy has said the welcome (its time on stage is over).
  void markPlayed() => _release();

  /// Completes once the welcome set last has been said; at once when none
  /// is pending or playing.
  Future<void> get played => _played?.future ?? Future<void>.value();

  void _release() {
    final played = _played;
    _played = null;
    if (played != null && !played.isCompleted) played.complete();
  }
}

final buddyWelcomeProvider = NotifierProvider<BuddyWelcomeNotifier, String?>(
  BuddyWelcomeNotifier.new,
);
