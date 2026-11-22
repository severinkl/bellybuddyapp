import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:belly_buddy/providers/buddy_events_provider.dart';
import 'package:belly_buddy/providers/buddy_provider.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/repositories/buddy_repository.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';
import 'package:belly_buddy/services/buddy/buddy_mood_logic.dart';

import '../helpers/fakes.dart';
import '../helpers/riverpod_helpers.dart';

Future<void> settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late FakeBuddyRepository buddyRepo;
  late FakeEntryRepository entryRepo;
  final event = BuddyLogEvent(
    EntryKind.meal,
    LogSentiment.good,
    at: DateTime(2026, 11, 22, 12),
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    buddyRepo = FakeBuddyRepository();
    entryRepo = FakeEntryRepository();
  });

  ProviderContainer makeContainer({String? userId = 'u1'}) => createContainer(
    overrides: [
      buddyRepositoryProvider.overrideWithValue(buddyRepo),
      entryRepositoryProvider.overrideWithValue(entryRepo),
      currentUserIdProvider.overrideWithValue(userId),
      buddyTodayProvider.overrideWithValue(() => DateTime(2026, 11, 22, 14)),
    ],
  );

  test('starts empty', () {
    expect(makeContainer().read(buddyEventsProvider), isNull);
  });

  test('emit then consume returns the event and clears it', () async {
    final c = makeContainer();
    final notifier = c.read(buddyEventsProvider.notifier);

    notifier.emit(event);
    expect(c.read(buddyEventsProvider), same(event));

    expect(notifier.consume(), same(event));
    expect(c.read(buddyEventsProvider), isNull);
    expect(notifier.consume(), isNull);
    await settle();
  });

  test('emit refreshes the Buddy', () async {
    final c = makeContainer();
    await c.read(buddyProvider.future);
    final fetchesBefore = buddyRepo.fetchCount;
    final daysBefore = entryRepo.activityDaysFetchCount;

    c.read(buddyEventsProvider.notifier).emit(event);
    await settle();

    expect(buddyRepo.fetchCount, fetchesBefore + 1);
    expect(entryRepo.activityDaysFetchCount, daysBefore + 1);
  });

  test('a failing refresh is logged, not thrown', () async {
    final c = makeContainer();
    await c.read(buddyProvider.future);
    buddyRepo.throwOnFetch = true;

    c.read(buddyEventsProvider.notifier).emit(event);
    await settle();

    expect(c.read(buddyEventsProvider), same(event));
    expect(c.read(buddyProvider).value, isNotNull);
  });

  test('emit while signed out only stores the event', () async {
    final c = makeContainer(userId: null);

    c.read(buddyEventsProvider.notifier).emit(event);
    await settle();

    expect(c.read(buddyEventsProvider), same(event));
    expect(buddyRepo.fetchCount, 0);
  });
}
