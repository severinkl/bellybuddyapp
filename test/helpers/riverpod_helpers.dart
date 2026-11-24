// ignore_for_file: invalid_use_of_internal_member
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/src/internals.dart' show Override;

import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/models/insights.dart';
import 'package:belly_buddy/models/journey_rewards.dart';
import 'package:belly_buddy/models/meal_entry.dart';
import 'package:belly_buddy/models/user_profile.dart';
import 'package:belly_buddy/providers/auth_provider.dart';
import 'package:belly_buddy/providers/entries_provider.dart';
import 'package:belly_buddy/providers/insights_provider.dart';
import 'package:belly_buddy/providers/journey_rewards_provider.dart';
import 'package:belly_buddy/providers/profile_provider.dart';

import 'app_host.dart';
import 'fixtures.dart';

/// Creates a [ProviderContainer] with the given overrides.
/// Automatically disposes after the test via [ProviderContainer.test].
/// MUST be called inside a `test()` or `setUp()` block.
ProviderContainer createContainer({List<Override> overrides = const []}) {
  return ProviderContainer.test(overrides: overrides);
}

/// A value a test switches while its container lives (the signed-in user,
/// a setting): override the provider under test with
/// `ref.watch(switchableProvider)`, then call [set].
class Switchable<T> extends Notifier<T> {
  Switchable(this._initial);
  final T _initial;

  @override
  T build() => _initial;

  void set(T value) => state = value;
}

/// The signed-in user's id, switchable (a sign-out, another user):
/// [override] makes [currentUserIdProvider] follow it; [set] switches it in
/// a container.
class SwitchableUserId {
  SwitchableUserId([String? initial = testUserId])
    : _id = NotifierProvider<Switchable<String?>, String?>(
        () => Switchable(initial),
      );

  final NotifierProvider<Switchable<String?>, String?> _id;

  Override get override =>
      currentUserIdProvider.overrideWith((ref) => ref.watch(_id));

  void set(ProviderContainer container, String? id) =>
      container.read(_id.notifier).set(id);
}

/// A [ProfileNotifier] that starts with [_profile] loaded.
class _SeededProfileNotifier extends ProfileNotifier {
  _SeededProfileNotifier(this._profile);
  final UserProfile? _profile;

  @override
  AsyncValue<UserProfile?> build() => AsyncValue.data(_profile);
}

/// An [Override] for [profileProvider] that starts with [profile] loaded
/// (no fetch first).
Override profileProviderSeededWith(UserProfile? profile) =>
    profileProvider.overrideWith(() => _SeededProfileNotifier(profile));

/// An [InsightsNotifier] serving [_insights] as loaded.
class _SeededInsightsNotifier extends InsightsNotifier {
  _SeededInsightsNotifier(this._insights);
  final Insights _insights;

  @override
  Future<Insights> build() async => _insights;
}

/// An [Override] for [insightsProvider] that serves [insights] (e.g.
/// `lockedInsights()`) instead of computing them.
Override insightsProviderSeededWith(Insights insights) =>
    insightsProvider.overrideWith(() => _SeededInsightsNotifier(insights));

/// A [JourneyRewardsNotifier] that starts with [_rewards] and keeps its
/// answers in memory: nothing read, moved on or stored.
class _SeededJourneyRewardsNotifier extends JourneyRewardsNotifier {
  _SeededJourneyRewardsNotifier(this._rewards);
  final JourneyRewards? _rewards;

  @override
  JourneyRewards? build() => _rewards;

  @override
  Future<void> answerTipOffer({required bool accepted}) async {
    if (state case final r? when r.tipOffer == TipOffer.offered) {
      state = r.copyWith(
        tipOffer: accepted ? TipOffer.accepted : TipOffer.declined,
      );
    }
  }

  @override
  Future<void> setFirstTip(FirstTipState firstTip) async =>
      state = state?.copyWith(firstTip: firstTip);
}

/// An [Override] for [journeyRewardsProvider] that serves [rewards] (null:
/// no journey) and keeps `answerTipOffer` and `setFirstTip` in memory.
Override journeyRewardsSeededWith(JourneyRewards? rewards) =>
    journeyRewardsProvider.overrideWith(
      () => _SeededJourneyRewardsNotifier(rewards),
    );

/// An [EntriesNotifier] whose [build] returns a pre-seeded [EntriesState] so
/// widgets that `ref.read(entriesProvider)` in `initState` see the supplied
/// meals without needing to wait for [EntriesNotifier.loadEntries].
class _SeededEntriesNotifier extends EntriesNotifier {
  _SeededEntriesNotifier(this._meals);
  final List<MealEntry> _meals;

  @override
  EntriesState build() => EntriesState(meals: _meals);
}

/// Returns an [Override] for [entriesProvider] that serves the supplied list
/// of meals (and empty lists for the other entry types). Use this in widget
/// tests that render the meal edit flow, since the screen reads meals from
/// [entriesProvider] in `initState` to seed the tracker.
Override entriesProviderSeededWith(List<MealEntry> meals) {
  return entriesProvider.overrideWith(() => _SeededEntriesNotifier(meals));
}

/// Extension on [WidgetTester] to pump a widget with ProviderScope,
/// MaterialApp, AppTheme, and German locale — matching the real app setup.
extension PumpWithProviders on WidgetTester {
  Future<void> pumpWithProviders(
    Widget widget, {
    List<Override> overrides = const [],
  }) async {
    await pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          theme: AppTheme.theme,
          localizationsDelegates: germanLocalizations,
          supportedLocales: const [germanLocale],
          locale: germanLocale,
          home: widget,
        ),
      ),
    );
  }
}
