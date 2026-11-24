// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/models/insights.dart';
import 'package:belly_buddy/providers/buddy_provider.dart';
import 'package:belly_buddy/providers/insights_provider.dart';
import 'package:belly_buddy/providers/log_moment.dart';
import 'package:belly_buddy/services/buddy/buddy_mood_logic.dart';

import '../helpers/fakes.dart';
import '../helpers/fixtures.dart';

class _Insights extends InsightsNotifier {
  @override
  Future<Insights> build() async => lockedInsights();

  void reloading() =>
      state = const AsyncLoading<Insights>().copyWithPrevious(state);

  void failed() => state = AsyncError<Insights>(
    StateError('x'),
    StackTrace.empty,
  ).copyWithPrevious(state);
}

final _now = DateTime(2026, 11, 23, 14);

void main() {
  late WidgetRef ref;
  late ProviderContainer container;
  late FakeBuddyNotifier buddy;

  Future<void> pump(WidgetTester tester) async {
    buddy = FakeBuddyNotifier(() => buddyStatus(streak: 4));
    container = ProviderContainer.test(
      overrides: [
        insightsProvider.overrideWith(_Insights.new),
        buddyProvider.overrideWith(() => buddy),
        buddyClockProvider.overrideWithValue(() => _now),
      ],
    );
    await container.read(insightsProvider.future);
    await container.read(buddyProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (_, r, _) {
            ref = r;
            return const SizedBox();
          },
        ),
      ),
    );
  }

  String? line() => captureLogMoment(
    ref,
    kind: EntryKind.gutFeeling,
    trackedAt: _now,
  ).buddyLine;

  testWidgets('loaded insights: the line', (tester) async {
    await pump(tester);
    expect(line(), isNotNull);
  });

  testWidgets('a reload still holding a value: no line', (tester) async {
    await pump(tester);
    (container.read(insightsProvider.notifier) as _Insights).reloading();
    expect(container.read(insightsProvider).value, isNotNull);
    expect(line(), isNull);
  });

  testWidgets('an error holding a value: no line', (tester) async {
    await pump(tester);
    (container.read(insightsProvider.notifier) as _Insights).failed();
    expect(container.read(insightsProvider).value, isNotNull);
    expect(line(), isNull);
  });

  int? ignites() =>
      captureLogMoment(ref, kind: EntryKind.meal, trackedAt: _now).ignitesDay;

  testWidgets('a loaded Buddy: the first entry ignites the next day', (
    tester,
  ) async {
    await pump(tester);
    expect(ignites(), 5);
  });

  testWidgets('a Buddy reloading with a value: no ignite', (tester) async {
    await pump(tester);
    buddy.state = const AsyncLoading<BuddyStatus?>().copyWithPrevious(
      buddy.state,
    );
    expect(container.read(buddyProvider).value, isNotNull);
    expect(ignites(), isNull);
  });
}
