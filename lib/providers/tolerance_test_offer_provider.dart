import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/pattern_stats.dart';
import '../models/tolerance_test.dart';
import '../utils/settled_value.dart';
import 'insights_provider.dart';
import 'notification_provider.dart';
import 'pattern_stats_provider.dart';
import 'plus_provider.dart';
import 'tolerance_test_provider.dart';

/// The flag suffix of [BuddyAnnouncement.testOffer] for [s]: `<kind>_<key>`,
/// so each subject is offered once.
String testOfferSuffix(TestSubject s) => '${s.kind}_${s.key}';

/// The flag suffix of [BuddyAnnouncement.testReintro] for [t].
String testReintroSuffix(ToleranceTestView t) => '${t.id}_reintro';

/// The flag suffix of [BuddyAnnouncement.testDone] for [t].
String testDoneSuffix(ToleranceTestView t) => '${t.id}_done';

/// The subject the Buddy offers to test on Home (spec §5.5), or null. Only
/// while Plus is open, the insights are settled and unlocked, his ask for
/// reminders is known not to be due (an ask that failed counts as not
/// due), and the pattern stats are loaded ([canOfferTest]: [AsyncData],
/// not reloading, not restrictive, no active test) with a proposal.
final toleranceTestOfferDueProvider = Provider<TestSubject?>((ref) {
  if (ref.watch(plusLockedProvider)) return null;
  if (!(ref.watch(insightsProvider).settledValue?.unlocked ?? false)) {
    return null;
  }
  final ask = ref.watch(reminderAskDueProvider);
  if (ask.isLoading || ask.value == true) return null;
  final stats = ref.watch(patternStatsProvider);
  if (!canOfferTest(stats)) return null;
  return stats.value?.proposal;
});

/// The test whose Buddy lines may play (Plus and the stats open): the
/// stats' value, kept while the same user's stats refetch ([currentValue]);
/// null when unknown or locked. [settled] takes only a loaded value
/// ([settledValue]), as the offers do.
ToleranceTestView? _lineTest(Ref ref, {required bool settled}) {
  if (ref.watch(plusLockedProvider)) return null;
  final stats = ref.watch(patternStatsProvider);
  if (stats.isLocked) return null;
  final PatternStats? value = settled ? stats.settledValue : stats.currentValue;
  return value?.test;
}

/// The first reintroduction day of an active test: day L+1.
bool _onFirstReintroDay(ToleranceTestView t) =>
    t.isActive &&
    t.phase == TestPhase.reintro &&
    t.dayIndex == t.leaveOutDays + 1;

/// A test with its result (active and over, or completed within 14 days).
bool _resultShown(ToleranceTestView t) =>
    t.status != 'stopped' && t.phase == TestPhase.done && t.result != null;

/// The test of [BuddyAnnouncement.testReintro] (its line on the first
/// reintroduction day), from loaded stats; null otherwise.
final testReintroDueProvider = Provider<ToleranceTestView?>((ref) {
  final t = _lineTest(ref, settled: true);
  return t != null && _onFirstReintroDay(t) ? t : null;
});

/// The test of [BuddyAnnouncement.testDone] (its line once the result is
/// there, for the 14 days the stats show it), from loaded stats; null
/// otherwise.
final testDoneDueProvider = Provider<ToleranceTestView?>((ref) {
  final t = _lineTest(ref, settled: true);
  return t != null && _resultShown(t) ? t : null;
});

/// Whether a pending test line with flag suffix [suffix] still applies as
/// it plays: the stats (kept while refetching) still show its condition
/// for that test. Plus or the stats locked, or the test unknown (no stats
/// kept: another user's loading, failed), it does not: the line can't name
/// its test ([testLineSubjectProvider]). None pending, it applies.
bool testLineStillApplies(
  Ref ref, {
  required bool done,
  required String? suffix,
}) {
  if (ref.watch(plusLockedProvider)) return false;
  final async = ref.watch(patternStatsProvider);
  if (async.isLocked) return false;
  if (suffix == null) return true;
  final stats = async.currentValue;
  if (stats == null) return false;
  final t = stats.test;
  if (t == null) return false;
  return done
      ? _resultShown(t) && testDoneSuffix(t) == suffix
      : _onFirstReintroDay(t) && testReintroSuffix(t) == suffix;
}

/// The subject the pending test line names: the stats' test (kept while
/// refetching); null when unknown.
final testLineSubjectProvider = Provider<TestSubject?>(
  (ref) => _lineTest(ref, settled: false)?.subject,
);

/// Whether a pending test offer with flag suffix [suffix] still applies as
/// it plays. Withdrawn (it then counts as shown) only once that is known:
/// Plus or the stats locked, or loaded stats that offer no test or another
/// subject. Anything still loading, or his ask for reminders due, leaves
/// it pending; the sheet checks [toleranceTestOfferDueProvider] itself.
bool testOfferStillApplies(Ref ref, {required String? suffix}) {
  if (ref.watch(plusLockedProvider)) return false;
  final stats = ref.watch(patternStatsProvider);
  if (stats.isLocked) return false;
  if (stats is! AsyncData<PatternStats?> || stats.isLoading) return true;
  if (!canOfferTest(stats)) return false;
  final proposal = stats.value?.proposal;
  if (proposal == null) return false;
  return suffix == null || testOfferSuffix(proposal) == suffix;
}
