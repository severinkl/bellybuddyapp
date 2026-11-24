// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/models/insight_progress.dart';
import 'package:belly_buddy/models/insights.dart';
import 'package:belly_buddy/providers/buddy_provider.dart';
import 'package:belly_buddy/providers/insights_provider.dart';
import 'package:belly_buddy/providers/log_moment.dart';
import 'package:belly_buddy/services/buddy/buddy_mood_logic.dart';

class _Insights extends InsightsNotifier {
  @override
  Future<Insights> build() async => const Insights(
    progress: InsightProgress(activeDays: 2, gutFeelingEntries: 1),
    calendar: [],
    goodDays: DayColumn(days: 0),
    hardDays: DayColumn(days: 0),
    noticed: [],
    pick: NothingYetPick(),
  );

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

  Future<void> pump(WidgetTester tester) async {
    container = ProviderContainer.test(
      overrides: [
        insightsProvider.overrideWith(_Insights.new),
        buddyClockProvider.overrideWithValue(() => _now),
      ],
    );
    await container.read(insightsProvider.future);
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
}
