import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_provider.dart';

/// A line the dashboard's Buddy says first, once: the Buddy onboarding sets
/// it right before it opens the dashboard. It belongs to the signed-in
/// user: signing out (or another user) drops it.
class BuddyWelcomeNotifier extends Notifier<String?> {
  /// The dashboard greeting after the Buddy onboarding.
  static const line = 'Willkommen daheim! Hier sehen wir uns jeden Tag.';

  @override
  String? build() {
    ref.watch(currentUserIdProvider);
    return null;
  }

  void set(String text) => state = text;

  /// Returns the pending line and clears it.
  String? take() {
    final text = state;
    state = null;
    return text;
  }
}

final buddyWelcomeProvider = NotifierProvider<BuddyWelcomeNotifier, String?>(
  BuddyWelcomeNotifier.new,
);
