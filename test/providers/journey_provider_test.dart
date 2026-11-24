import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:belly_buddy/models/insight_progress.dart';
import 'package:belly_buddy/models/insights.dart';
import 'package:belly_buddy/providers/insights_provider.dart';
import 'package:belly_buddy/providers/journey_provider.dart';

import '../helpers/riverpod_helpers.dart';

Future<void> settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Insights _insights({required int days, required int gutFeelings}) => Insights(
  progress: InsightProgress(activeDays: days, gutFeelingEntries: gutFeelings),
  calendar: const [],
  goodDays: const DayColumn(days: 0),
  hardDays: const DayColumn(days: 0),
  noticed: const [],
  pick: const NothingYetPick(),
);

class _FakeInsights extends InsightsNotifier {
  _FakeInsights(this._value);
  final FutureOr<Insights> _value;
  @override
  Future<Insights> build() async => _value;
}

/// A never-completing load.
class _LoadingInsights extends InsightsNotifier {
  @override
  Future<Insights> build() => Completer<Insights>().future;
}

final _user = SwitchableUserId('u1');

ProviderContainer _container(InsightsNotifier Function() insights) =>
    ProviderContainer.test(
      overrides: [_user.override, insightsProvider.overrideWith(insights)],
    );

Future<bool?> _decide(ProviderContainer c) async {
  c.listen(journeyProvider, (_, _) {});
  await settle();
  return c.read(journeyProvider);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<bool?> stored(String key) async =>
      (await SharedPreferences.getInstance()).getBool(key);

  test('a new user (2 days, locked) gets the journey, stored', () async {
    final c = _container(
      () => _FakeInsights(_insights(days: 2, gutFeelings: 0)),
    );

    expect(await _decide(c), isTrue);
    expect(await stored('insight_journey_u1'), isTrue);
  });

  test('a user past day 7 (9 days, 1 Bauchgefühl) gets none', () async {
    final c = _container(
      () => _FakeInsights(_insights(days: 9, gutFeelings: 1)),
    );

    expect(await _decide(c), isFalse);
    expect(await stored('insight_journey_u1'), isFalse);
  });

  test('an unlocked user gets none', () async {
    final c = _container(
      () => _FakeInsights(_insights(days: 7, gutFeelings: 3)),
    );

    expect(await _decide(c), isFalse);
  });

  test('decided once: stored true stays true at 9 days', () async {
    SharedPreferences.setMockInitialValues({'insight_journey_u1': true});
    final c = _container(
      () => _FakeInsights(_insights(days: 9, gutFeelings: 1)),
    );

    expect(await _decide(c), isTrue);
  });

  test('decided once: stored false stays false at 2 days', () async {
    SharedPreferences.setMockInitialValues({'insight_journey_u1': false});
    final c = _container(
      () => _FakeInsights(_insights(days: 2, gutFeelings: 0)),
    );

    expect(await _decide(c), isFalse);
  });

  test('undecided while the insights load', () async {
    final c = _container(_LoadingInsights.new);

    expect(await _decide(c), isNull);
    expect(await stored('insight_journey_u1'), isNull);
  });

  test('per user: user B is decided under its own key', () async {
    SharedPreferences.setMockInitialValues({'insight_journey_u1': false});
    final c = _container(
      () => _FakeInsights(_insights(days: 2, gutFeelings: 0)),
    );
    expect(await _decide(c), isFalse);

    _user.set(c, 'u2');
    await settle();

    expect(c.read(journeyProvider), isTrue);
    expect(await stored('insight_journey_u2'), isTrue);
    expect(await stored('insight_journey_u1'), isFalse);
  });

  test('signed out: null', () async {
    final c = ProviderContainer.test(
      overrides: [
        SwitchableUserId(null).override,
        insightsProvider.overrideWith(
          () => _FakeInsights(_insights(days: 2, gutFeelings: 0)),
        ),
      ],
    );

    expect(await _decide(c), isNull);
  });
}
