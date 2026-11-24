import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/buddy/care_meters.dart';
import '../services/buddy/care_now.dart';
import 'buddy_provider.dart';
import 'entries_provider.dart';
import 'minute_provider.dart';

/// When each need was last logged, as the day [entriesProvider] holds and
/// the entries before it show (before the first load, today by the Buddy's
/// clock). Home's meters derive from it ([careNowProvider]).
final careLogProvider = Provider<CareLog>((ref) {
  final entries = ref.watch(entriesProvider);
  return CareLog.fromEntries(
    entries,
    entries.day ?? ref.read(buddyClockProvider)(),
  );
});

/// Home's needs at the current minute ([minuteProvider]): the meters, the
/// Buddy's mood, the next action and what the bubbles say. Its listeners
/// hear of a change only when one of those changed ([CareNow]'s `==`).
final careNowProvider = Provider<CareNow>(
  (ref) => CareNow.at(ref.watch(careLogProvider), ref.watch(minuteProvider)),
);
