import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/providers/buddy_provider.dart';
import 'package:belly_buddy/providers/daily_care_provider.dart';
import 'package:belly_buddy/providers/entries_provider.dart';

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

  test('counts the loaded day', () {
    final day = DateTime(2026, 11, 22);
    final c = makeContainer(
      EntriesState(
        day: day,
        meals: [
          testMealEntry(trackedAt: DateTime(2026, 11, 22, 9)),
          testMealEntry(trackedAt: DateTime(2026, 11, 22, 13)),
          testMealEntry(trackedAt: DateTime(2026, 11, 23, 9)),
        ],
      ),
    );

    expect(c.read(dailyCareProvider).meals, 2);
  });

  test("before the first load, today's by the Buddy's clock", () {
    final c = makeContainer(
      EntriesState(
        meals: [
          testMealEntry(trackedAt: DateTime(2026, 11, 22, 9)),
          testMealEntry(trackedAt: DateTime(2026, 11, 23, 9)),
        ],
      ),
    );

    expect(c.read(dailyCareProvider).meals, 1);
  });

  test('follows the entries', () {
    final c = makeContainer(EntriesState(day: DateTime(2026, 11, 23)));
    expect(c.read(dailyCareProvider).meals, 0);

    (c.read(entriesProvider.notifier) as _Entries).push(
      EntriesState(
        day: DateTime(2026, 11, 23),
        meals: [testMealEntry(trackedAt: DateTime(2026, 11, 23, 9))],
      ),
    );

    expect(c.read(dailyCareProvider).meals, 1);
  });
}
