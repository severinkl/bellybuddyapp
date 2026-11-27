// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/src/internals.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/models/gut_feeling_entry.dart';
import 'package:belly_buddy/models/journey_rewards.dart';
import 'package:belly_buddy/providers/buddy_onboarding_gate_provider.dart';
import 'package:belly_buddy/providers/buddy_provider.dart';
import 'package:belly_buddy/providers/entries_provider.dart';
import 'package:belly_buddy/providers/insights_provider.dart';
import 'package:belly_buddy/providers/rating_provider.dart';
import 'package:belly_buddy/providers/tutorial_provider.dart';
import 'package:belly_buddy/repositories/buddy_repository.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';
import 'package:belly_buddy/services/app_version_service.dart';

import '../helpers/fakes.dart';
import '../helpers/fixtures.dart';
import '../helpers/riverpod_helpers.dart';

class _FakeLauncher implements RatingLauncher {
  bool available = true;
  bool throws = false;

  @override
  Future<bool> isAvailable() async {
    if (throws) throw Exception('no store');
    return available;
  }

  @override
  Future<void> request() async {}

  @override
  Future<void> openStoreListing() async {}
}

class _FakeVersion extends AppVersionService {
  @override
  Future<String> currentVersion() async => '1.3.0';
}

class _Tutorial extends TutorialNotifier {
  _Tutorial(this._running);
  final bool _running;

  @override
  bool build() => _running;
}

class _Entries extends EntriesNotifier {
  _Entries(this._state);
  final EntriesState _state;

  @override
  EntriesState build() => _state;
}

final _user = SwitchableUserId();

void main() {
  final now = DateTime(2026, 11, 26, 9);
  late _FakeLauncher launcher;
  late ProviderContainer container;
  late WidgetRef widgetRef;

  String flagKey(String userId) =>
      '${AppConstants.keyBuddyAnnouncedPrefix}${userId}_patternsUnlocked_once';

  /// A container for a journey user (default) whose patterns were freed
  /// and celebrated; [overrides] change what a test needs.
  Future<void> pump(
    WidgetTester tester, {
    bool? journey = true,
    bool freed = true,
    bool celebrated = true,
    bool unlocked = false,
    bool onboarding = false,
    bool tutorial = false,
    List<Override> overrides = const [],
    List<GutFeelingEntry> gutFeelings = const [],
    Map<String, Object> prefs = const {},
  }) async {
    SharedPreferences.setMockInitialValues({
      if (celebrated) flagKey(testUserId): true,
      ...prefs,
    });
    container = ProviderContainer.test(
      overrides: [
        _user.override,
        buddyClockProvider.overrideWithValue(() => now),
        buddyRepositoryProvider.overrideWithValue(FakeBuddyRepository()),
        entryRepositoryProvider.overrideWithValue(FakeEntryRepository()),
        ratingLauncherProvider.overrideWithValue(launcher),
        appVersionServiceProvider.overrideWithValue(_FakeVersion()),
        journeySeededWith(journey),
        journeyRewardsSeededWith(
          journey == true ? JourneyRewards(patternsFreed: freed) : null,
        ),
        insightsProviderSeededWith(
          unlocked
              ? lockedInsights(activeDays: 7, gutFeelings: 3)
              : lockedInsights(),
        ),
        buddyOnboardingRequiredProvider.overrideWithValue(onboarding),
        tutorialProvider.overrideWith(() => _Tutorial(tutorial)),
        entriesProvider.overrideWith(
          () => _Entries(EntriesState(gutFeelings: gutFeelings)),
        ),
        ...overrides,
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (_, ref, _) {
            widgetRef = ref;
            return const SizedBox();
          },
        ),
      ),
    );
  }

  Future<bool> due() async {
    final sub = container.listen(ratingAskDueProvider, (_, _) {});
    try {
      return await container.read(ratingAskDueProvider.future);
    } finally {
      sub.close();
    }
  }

  setUp(() => launcher = _FakeLauncher());

  testWidgets('due for a journey user once patterns are freed and the '
      'celebration was shown', (tester) async {
    await pump(tester);
    expect(await due(), isTrue);
  });

  testWidgets('not due while the patternsUnlocked announcement is still '
      'pending (its flag unset), or the patterns not freed', (tester) async {
    await pump(tester, celebrated: false);
    expect(await due(), isFalse);
    await pump(tester, freed: false);
    expect(await due(), isFalse);
  });

  testWidgets('due for a user off the journey with unlocked insights; not '
      'while insights are locked', (tester) async {
    await pump(tester, journey: false, unlocked: true, celebrated: false);
    await container.read(insightsProvider.future);
    expect(await due(), isTrue);
    await pump(tester, journey: false, celebrated: false);
    await container.read(insightsProvider.future);
    expect(await due(), isFalse);
  });

  testWidgets('not due signed out, with the journey undecided, during the '
      'Buddy onboarding, during the tutorial', (tester) async {
    await pump(tester);
    _user.set(container, null);
    expect(await due(), isFalse);
    await pump(tester, journey: null);
    expect(await due(), isFalse);
    await pump(tester, onboarding: true);
    expect(await due(), isFalse);
    await pump(tester, tutorial: true);
    expect(await due(), isFalse);
  });

  testWidgets('not due on a day with a Schlecht entry', (tester) async {
    final hard = testGutFeelingEntry(
      trackedAt: DateTime(2026, 11, 26, 8),
      bloating: 5,
      gas: 5,
      cramps: 5,
      fullness: 5,
    );
    await pump(tester, gutFeelings: [hard]);
    expect(await due(), isFalse);
  });

  testWidgets('not due when the launcher is unavailable, or when '
      'isAvailable throws', (tester) async {
    launcher.available = false;
    await pump(tester);
    expect(await due(), isFalse);
    launcher
      ..available = true
      ..throws = true;
    await pump(tester);
    expect(await due(), isFalse);
  });

  testWidgets('recordRatingAsk stores this version and today under the '
      'user id; due is false afterwards', (tester) async {
    await pump(tester);
    expect(await due(), isTrue);
    await recordRatingAsk(widgetRef);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('${AppConstants.keyRatingAskedVersionPrefix}$testUserId'),
      '1.3.0',
    );
    expect(
      prefs.getString('${AppConstants.keyRatingAskedOnPrefix}$testUserId'),
      '2026-11-26',
    );
    expect(await due(), isFalse);
  });

  testWidgets("user A's record does not affect user B on the same device", (
    tester,
  ) async {
    await pump(
      tester,
      prefs: {
        '${AppConstants.keyRatingAskedVersionPrefix}$testUserId': '1.3.0',
        '${AppConstants.keyRatingAskedOnPrefix}$testUserId': '2026-11-20',
        flagKey('user-b'): true,
      },
    );
    expect(await due(), isFalse);
    _user.set(container, 'user-b');
    expect(await due(), isTrue);
  });
}
