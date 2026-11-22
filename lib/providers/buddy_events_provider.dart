import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/buddy/buddy_mood_logic.dart';
import '../utils/logger.dart';
import 'buddy_provider.dart';

/// Something the user just logged in a tracker; the Buddy reacts to it.
class BuddyLogEvent {
  const BuddyLogEvent(this.kind, this.sentiment, {required this.at});

  final EntryKind kind;
  final LogSentiment sentiment;
  final DateTime at;
}

/// Holds the latest unconsumed [BuddyLogEvent].
class BuddyEventsNotifier extends Notifier<BuddyLogEvent?> {
  static const _log = AppLogger('BuddyEvents');

  @override
  BuddyLogEvent? build() => null;

  /// Stores [e] and refreshes the Buddy's streak in the background.
  void emit(BuddyLogEvent e) {
    state = e;
    unawaited(_refreshBuddy());
  }

  /// Returns the pending event and clears it.
  BuddyLogEvent? consume() {
    final e = state;
    state = null;
    return e;
  }

  Future<void> _refreshBuddy() async {
    try {
      await ref.read(buddyProvider.notifier).refresh();
    } catch (e, st) {
      _log.error('Refreshing the Buddy after a log failed', e, st);
    }
  }
}

final buddyEventsProvider =
    NotifierProvider<BuddyEventsNotifier, BuddyLogEvent?>(
      BuddyEventsNotifier.new,
    );
