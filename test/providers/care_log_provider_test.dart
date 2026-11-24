import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/providers/buddy_provider.dart';
import 'package:belly_buddy/providers/care_log_provider.dart';
import 'package:belly_buddy/providers/entries_provider.dart';
import 'package:belly_buddy/services/entry_query_service.dart';

import '../helpers/fixtures.dart';
import '../helpers/riverpod_helpers.dart';

/// [EntriesNotifier] serving a seeded state that tests can replace.
class _Entries extends EntriesNotifier {
  _Entries(this._initial);

  final EntriesState _initial;

  @override
  EntriesState build() => _initial;

  void push(EntriesState s) => state = s;
}

void main() {
  final now = DateTime(2026, 11, 23, 12, 40);

  ProviderContainer makeContainer(EntriesState entries) => createContainer(
    overrides: [
      entriesProvider.overrideWith(() => _Entries(entries)),
      buddyTodayProvider.overrideWithValue(() => now),
    ],
  );

  test('follows the entries', () {
    final c = makeContainer(EntriesState(day: DateTime(2026, 11, 23)));
    expect(c.read(careLogProvider).lastMealAt, isNull);

    (c.read(entriesProvider.notifier) as _Entries).push(
      EntriesState(
        day: DateTime(2026, 11, 23),
        meals: [testMealEntry(trackedAt: DateTime(2026, 11, 23, 9))],
      ),
    );

    expect(c.read(careLogProvider).lastMealAt, DateTime(2026, 11, 23, 9));
  });

  test("before the first load, today by the Buddy's clock", () {
    final c = makeContainer(
      EntriesState(
        meals: [testMealEntry(trackedAt: DateTime(2026, 11, 22, 9))],
        toiletEntries: [testToiletEntry(trackedAt: DateTime(2026, 11, 23, 8))],
        gutFeelings: [
          testGutFeelingEntry(
            trackedAt: DateTime(2026, 11, 22, 18),
            bloating: 5,
            gas: 5,
            cramps: 5,
            fullness: 5,
          ),
        ],
      ),
    );

    final log = c.read(careLogProvider);
    expect(log.lastToiletAt, DateTime(2026, 11, 23, 8));
    // Yesterday's Bauchgefühl is no level of today.
    expect(log.lastGutFeelingLevel, isNull);
  });

  test('careLogProvider follows a reload without the deleted entry', () {
    final day = DateTime(2026, 11, 23);
    final c = makeContainer(
      EntriesState(
        day: day,
        drinks: [testDrinkEntry(trackedAt: DateTime(2026, 11, 23, 10))],
      ),
    );
    expect(c.read(careLogProvider).lastDrinkAt, DateTime(2026, 11, 23, 10));

    (c.read(entriesProvider.notifier) as _Entries).push(
      EntriesState(
        day: day,
        latestBefore: LatestEntries(drink: DateTime(2026, 11, 22, 21)),
      ),
    );

    expect(c.read(careLogProvider).lastDrinkAt, DateTime(2026, 11, 22, 21));
  });
}
