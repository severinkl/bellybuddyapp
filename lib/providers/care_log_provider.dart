import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/buddy/care_meters.dart';
import 'buddy_provider.dart';
import 'entries_provider.dart';

/// When each need was last logged, as the day [entriesProvider] holds and
/// the entries before it show (before the first load, today by the Buddy's
/// clock). Home's meters derive from it.
final careLogProvider = Provider<CareLog>((ref) {
  final entries = ref.watch(entriesProvider);
  return CareLog.fromEntries(
    entries,
    entries.day ?? ref.read(buddyClockProvider)(),
  );
});
