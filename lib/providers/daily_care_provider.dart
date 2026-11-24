import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/buddy/daily_care.dart';
import 'buddy_provider.dart';
import 'entries_provider.dart';

/// The care of the day [entriesProvider] holds (Home's day; before the
/// first load, today by the Buddy's clock). Home's ring, mood and next
/// action and the „Eintragen" sheet's suggestion all derive from it.
final dailyCareProvider = Provider<DailyCare>((ref) {
  final entries = ref.watch(entriesProvider);
  return DailyCare.fromEntries(
    entries,
    entries.day ?? ref.read(buddyClockProvider)(),
  );
});
