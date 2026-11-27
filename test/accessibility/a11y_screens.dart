// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:riverpod/src/internals.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/models/buddy_state.dart';
import 'package:belly_buddy/models/insight_rules.dart';
import 'package:belly_buddy/providers/buddy_provider.dart';
import 'package:belly_buddy/providers/upgrade_gate_provider.dart';
import 'package:belly_buddy/router/app_router.dart';
import 'package:belly_buddy/router/route_names.dart';
import 'package:belly_buddy/services/share_service.dart';

import '../helpers/app_host.dart';
import '../helpers/fakes.dart';
import '../helpers/fixtures.dart';
import '../helpers/riverpod_helpers.dart';
import '../helpers/share_fakes.dart';

/// The checks the guardrail runs on every screen.
enum A11yCheck {
  androidTapTarget,
  iosTapTarget,
  labeledTapTarget,
  textContrast,
  textScale200,
}

/// The overrides a screen starts from, built fresh for every test.
typedef A11yOverrides = List<Override> Function();

List<Override> _noSeed() => const [];

/// A main screen of the app as the guardrail tests open it: signed in
/// through [base] (by default [baseOverrides]), plus [seed], and routed to
/// [path].
///
/// [base] and [seed] are functions so the list stays `const` and every test
/// gets fresh fakes. [base] exists because Riverpod refuses a provider
/// overridden twice: a screen that needs other repositories than
/// [baseOverrides]' defaults (entries, a profile, the auth state) builds
/// them through [baseOverrides]' parameters there, and [seed] adds the
/// providers [baseOverrides] doesn't touch.
///
/// [pending] lists the checks the screen doesn't pass yet, each with the
/// task that clears it (XA4–XA10). A pending check is removed only together
/// with its fix.
class A11yScreen {
  const A11yScreen(
    this.name,
    this.path, {
    this.base = baseOverrides,
    this.seed = _noSeed,
    this.pending = const {},
  });

  /// German screen name, e.g. 'Tagebuch'.
  final String name;

  /// A [RoutePaths] value with its ids filled in.
  final String path;

  final A11yOverrides base;

  /// Added after [base].
  final A11yOverrides seed;

  /// Check → owning task id, e.g. `{A11yCheck.textContrast: 'XA5'}`.
  final Map<A11yCheck, String> pending;
}

/// The app's clock in the harness: Friday, 27 Nov 2026, 12:40.
final a11yNow = DateTime(2026, 11, 27, 12, 40);

DateTime _today(int hour) =>
    DateTime(a11yNow.year, a11yNow.month, a11yNow.day, hour);

// -- Seeds ------------------------------------------------------------------

List<Override> _signedOut() =>
    baseOverrides(auth: FakeAuthRepository(signedIn: false));

/// One meal, drink, Bauchgefühl and Klo entry today.
List<Override> _diaryBase() => baseOverrides(
  entries: FakeEntryRepository()
    ..seedResult(
      testEntryQueryResult(
        meals: [testMealEntry(trackedAt: _today(8))],
        drinks: [testDrinkEntry(trackedAt: _today(9))],
        gutFeelings: [testGutFeelingEntry(trackedAt: _today(10))],
        toiletEntries: [testToiletEntry(trackedAt: _today(11))],
      ),
    ),
);

List<Override> _patternsLockedBase() => baseOverrides(
  entries: FakeEntryRepository()
    ..insightSource = insightSourceFor(
      activeDays: 3,
      gutFeelings: 1,
      now: a11yNow,
    ),
);

List<Override> _patternsUnlockedBase() => baseOverrides(
  entries: FakeEntryRepository()
    ..insightSource = insightSourceFor(
      activeDays: InsightRules.daysNeeded,
      gutFeelings: InsightRules.gutFeelingsNeeded,
      now: a11yNow,
    ),
);

/// One own recipe, `rec-1` (the collection's `recipe-1` is
/// [FakeRecipeRepository]'s default).
List<Override> _ownRecipeBase() => baseOverrides(
  userRecipes: FakeUserRecipeRepository(
    seed: [testUserRecipe(userId: testUserId)],
  ),
);

/// The gender as the app stores it („männlich"; the fixture's `male` is
/// no option of the profile's dropdown).
List<Override> _profileBase() => baseOverrides(
  profiles: FakeProfileRepository()
    ..seedProfile(testUserProfile(gender: 'männlich')),
);

List<Override> _consentBase() => baseOverrides(
  profiles: FakeProfileRepository()
    ..seedProfile(testUserProfile(hasHealthConsent: false)),
);

/// A Buddy whose onboarding isn't done, so the gate opens it.
List<Override> _onboardingBase() => baseOverrides(
  buddies: FakeBuddyRepository()
    ..store[testUserId] = const BuddyState(userId: testUserId),
);

List<Override> _upgradeBase() =>
    baseOverrides(decision: UpgradeDecision.hardGate);

List<Override> _oneShare() => [
  shareServiceProvider.overrideWithValue(FakeShareService([testShare()])),
];

List<Override> _mealToEdit() => [
  entriesProviderSeededWith([testMealEntry()]),
];

// -- Pending checks -----------------------------------------------------------

const _tapTargets9 = {
  A11yCheck.androidTapTarget: 'XA9',
  A11yCheck.iosTapTarget: 'XA9',
};

// -- The screens --------------------------------------------------------------

/// Every [RoutePaths] route except loading (and the not-found page, which
/// has no route): spec §4.4.
const a11yScreens = <A11yScreen>[
  // Signed out.
  A11yScreen(
    'Willkommen',
    RoutePaths.welcome,
    base: _signedOut,
    // „Tippe, um ihn zu wecken": 42 px tall; 2.71:1 mid-pulse.
    pending: {
      A11yCheck.androidTapTarget: 'XA10',
      A11yCheck.iosTapTarget: 'XA10',
      A11yCheck.textContrast: 'XA10',
    },
  ),
  A11yScreen('Anmelden', RoutePaths.auth, base: _signedOut),
  A11yScreen(
    'Passwort zurücksetzen',
    RoutePaths.resetPassword,
    base: _signedOut,
  ),
  A11yScreen('Registrierung', RoutePaths.registration, base: _signedOut),

  // Gates.
  A11yScreen('Update nötig', RoutePaths.upgradeRequired, base: _upgradeBase),
  A11yScreen('Gesundheitsdaten', RoutePaths.healthConsent, base: _consentBase),
  A11yScreen(
    'Buddy-Onboarding',
    RoutePaths.buddyOnboarding,
    base: _onboardingBase,
  ),

  // The four tabs.
  A11yScreen('Home', RoutePaths.dashboard),
  A11yScreen('Tagebuch', RoutePaths.diary, base: _diaryBase),
  A11yScreen('Entdecken', RoutePaths.discover),
  A11yScreen('Wissen', RoutePaths.knowledge),
  A11yScreen('Rezeptsammlung', RoutePaths.discoverRecipes),
  A11yScreen('Ich', RoutePaths.me),

  // Trackers.
  A11yScreen('Mahlzeit', RoutePaths.mealTracker),
  A11yScreen('Mahlzeit bearbeiten', '/meal-tracker/meal-1', seed: _mealToEdit),
  A11yScreen('Klo', RoutePaths.toiletTracker),
  A11yScreen('Bauchgefühl', RoutePaths.gutFeelingTracker),
  A11yScreen('Getränk', RoutePaths.drinkTracker),

  // Entdecken.
  A11yScreen('Tipps', RoutePaths.recommendations),
  A11yScreen('Alternativen', RoutePaths.ingredientSuggestions),
  A11yScreen('Meine Rezepte', RoutePaths.recipes, base: _ownRecipeBase),
  A11yScreen('Neues Rezept', RoutePaths.recipeNew),
  A11yScreen('Eigenes Rezept', '/recipe/rec-1', base: _ownRecipeBase),
  A11yScreen('Rezept bearbeiten', '/recipe/rec-1/edit', base: _ownRecipeBase),
  A11yScreen('Sammlungsrezept', '/collection/recipe-1'),
  A11yScreen('Rezept anpassen', '/collection/recipe-1/adapt'),

  // Muster.
  A11yScreen(
    'Muster (gesperrt)',
    RoutePaths.patterns,
    base: _patternsLockedBase,
  ),
  A11yScreen('Muster (frei)', RoutePaths.patterns, base: _patternsUnlockedBase),
  A11yScreen(
    'Muster frei!',
    RoutePaths.patternsUnlocked,
    // An unlabelled tap area (32–370 × 601–681); the success overlay's
    // Column overflows 184 px at 200 %.
    pending: {A11yCheck.labeledTapTarget: 'XA8', A11yCheck.textScale200: 'XA8'},
  ),

  // Ich.
  A11yScreen('Einstellungen', RoutePaths.settings),
  // The diet chips, 40 px.
  A11yScreen(
    'Profil',
    RoutePaths.settingsProfile,
    base: _profileBase,
    pending: _tapTargets9,
  ),
  // The reminder-time chips and „Hinzufügen", 36 px.
  A11yScreen(
    'Benachrichtigungen',
    RoutePaths.settingsNotifications,
    pending: _tapTargets9,
  ),
  // „Passwort ändern", 24 px.
  A11yScreen('Konto', RoutePaths.settingsAccount, pending: _tapTargets9),
  A11yScreen('Freigaben', RoutePaths.shares, seed: _oneShare),
  A11yScreen('Neue Freigabe', RoutePaths.shareCreate, seed: _oneShare),
];

/// Once per test file: the German date symbols the screens format with.
void setUpA11yScreens() {
  setUpAll(() => initializeDateFormatting('de_DE'));
  setUp(
    () => SharedPreferences.setMockInitialValues({
      AppConstants.keyNotificationModalShown: true,
    }),
  );
}

/// Pumps frames until nothing is scheduled, for at most [_settleLimit] of
/// fake time. Unlike `pumpAndSettle` it doesn't fail on a screen that
/// animates for ever (the welcome hint breathes until the Buddy wakes): the
/// checks then run on the frame shown after [_settleLimit].
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  for (
    var waited = Duration.zero;
    tester.binding.hasScheduledFrame && waited < _settleLimit;
    waited += _settleStep
  ) {
    await tester.pump(_settleStep);
  }
}

const _settleStep = Duration(milliseconds: 100);
const _settleLimit = Duration(seconds: 10);

/// Opens [s] on a 402×874 phone (dpr 1, a notch and a home bar) with text
/// scaled by [textScale]: the real router in [AppTestHost], the clock pinned
/// to [a11yNow], then `go` to its path. Fails when a gate sent it elsewhere.
Future<void> pumpA11yScreen(
  WidgetTester tester,
  A11yScreen s, {
  double textScale = 1,
}) async {
  tester.view
    ..physicalSize = const Size(402, 874)
    ..devicePixelRatio = 1
    ..padding = const FakeViewPadding(top: 62, bottom: 34);
  addTearDown(tester.view.reset);
  final container = ProviderContainer.test(
    overrides: [
      ...s.base(),
      ...s.seed(),
      buddyTodayProvider.overrideWithValue(() => a11yNow),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: AppTestHost(textScale: textScale),
    ),
  );
  await _settle(tester);
  final router = container.read(routerProvider)..go(s.path);
  await _settle(tester);
  expect(
    router.routerDelegate.currentConfiguration.uri.path,
    s.path,
    reason: '${s.name} opens on its own path',
  );
}
