// ignore_for_file: invalid_use_of_internal_member
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:belly_buddy/models/insights.dart';
import 'package:belly_buddy/providers/insights_provider.dart';
import 'package:belly_buddy/providers/journey_provider.dart';

import '../helpers/fixtures.dart';
import '../helpers/riverpod_helpers.dart';

/// A never-completing load.
class _LoadingInsights extends InsightsNotifier {
  @override
  Future<Insights> build() => Completer<Insights>().future;
}

/// Loaded with 2 days, then [refreshing] holds that value while the next
/// one ([next]) loads.
class _RefreshingInsights extends InsightsNotifier {
  final next = Completer<Insights>();

  @override
  Future<Insights> build() async => lockedInsights(gutFeelings: 0);

  void refreshing() {
    state = const AsyncLoading<Insights>().copyWithPrevious(state);
    next.future.then((value) => state = AsyncData(value));
  }
}

final _user = SwitchableUserId('u1');

ProviderContainer _container(InsightsNotifier Function() insights) =>
    ProviderContainer.test(
      overrides: [_user.override, insightsProvider.overrideWith(insights)],
    );

/// A container whose insights are [insights], loaded.
ProviderContainer _seeded(Insights insights) => ProviderContainer.test(
  overrides: [_user.override, insightsProviderSeededWith(insights)],
);

Future<bool?> _decide(ProviderContainer c) async {
  c.listen(journeyProvider, (_, _) {});
  await pumpEventQueue();
  return c.read(journeyProvider);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<bool?> stored(String key) async =>
      (await SharedPreferences.getInstance()).getBool(key);

  test('a new user (2 days, locked) gets the journey, stored', () async {
    final c = _seeded(lockedInsights(activeDays: 2, gutFeelings: 0));

    expect(await _decide(c), isTrue);
    expect(await stored('insight_journey_u1'), isTrue);
  });

  test('a user past day 7 (9 days, 1 Bauchgefühl) gets none', () async {
    final c = _seeded(lockedInsights(activeDays: 9, gutFeelings: 1));

    expect(await _decide(c), isFalse);
    expect(await stored('insight_journey_u1'), isFalse);
  });

  test('an unlocked user gets none', () async {
    final c = _seeded(lockedInsights(activeDays: 7, gutFeelings: 3));

    expect(await _decide(c), isFalse);
  });

  test('decided once: stored true stays true at 9 days', () async {
    SharedPreferences.setMockInitialValues({'insight_journey_u1': true});
    final c = _seeded(lockedInsights(activeDays: 9, gutFeelings: 1));

    expect(await _decide(c), isTrue);
  });

  test('decided once: stored false stays false at 2 days', () async {
    SharedPreferences.setMockInitialValues({'insight_journey_u1': false});
    final c = _seeded(lockedInsights(activeDays: 2, gutFeelings: 0));

    expect(await _decide(c), isFalse);
  });

  test('undecided while the insights load', () async {
    final c = _container(_LoadingInsights.new);

    expect(await _decide(c), isNull);
    expect(await stored('insight_journey_u1'), isNull);
  });

  test('a refresh still holding the previous value never decides', () async {
    late _RefreshingInsights insights;
    final c = _container(() => insights = _RefreshingInsights());
    await c.read(insightsProvider.future);
    insights.refreshing();
    expect(c.read(insightsProvider).value, isNotNull);

    expect(await _decide(c), isNull);

    insights.next.complete(lockedInsights(activeDays: 9, gutFeelings: 1));
    await pumpEventQueue();
    expect(c.read(journeyProvider), isFalse);
  });

  test('per user: user B is decided under its own key', () async {
    SharedPreferences.setMockInitialValues({'insight_journey_u1': false});
    final c = _seeded(lockedInsights(activeDays: 2, gutFeelings: 0));
    expect(await _decide(c), isFalse);

    _user.set(c, 'u2');
    await pumpEventQueue();

    expect(c.read(journeyProvider), isTrue);
    expect(await stored('insight_journey_u2'), isTrue);
    expect(await stored('insight_journey_u1'), isFalse);
  });

  test('signed out: null', () async {
    final c = ProviderContainer.test(
      overrides: [
        SwitchableUserId(null).override,
        insightsProviderSeededWith(
          lockedInsights(activeDays: 2, gutFeelings: 0),
        ),
      ],
    );

    expect(await _decide(c), isNull);
  });
}
