// ignore_for_file: invalid_use_of_internal_member
import 'dart:async';

import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/models/user_profile.dart';
import 'package:belly_buddy/providers/auth_provider.dart';
import 'package:belly_buddy/providers/health_consent_provider.dart';
import 'package:belly_buddy/providers/profile_provider.dart';
import 'package:belly_buddy/providers/upgrade_gate_provider.dart';
import 'package:belly_buddy/repositories/auth_repository.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';
import 'package:belly_buddy/repositories/ingredient_repository.dart';
import 'package:belly_buddy/repositories/profile_repository.dart';
import 'package:belly_buddy/router/app_router.dart';
import 'package:belly_buddy/router/route_names.dart';
import 'package:belly_buddy/screens/health_consent/health_consent_screen.dart';
import 'package:belly_buddy/screens/registration/steps/auth_step.dart';
import 'package:belly_buddy/screens/upgrade/upgrade_required_screen.dart';
import 'package:belly_buddy/widgets/common/bb_password_field.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/src/internals.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fakes.dart';
import '../helpers/fixtures.dart';
import '../helpers/registration_driver.dart';

/// Pared-down app root: owns the upgrade decision like [BellyBuddyApp] and
/// loads the profile on start when signed in, without the splash overlay.
class _GateTestHost extends ConsumerStatefulWidget {
  const _GateTestHost();

  @override
  ConsumerState<_GateTestHost> createState() => _GateTestHostState();
}

class _GateTestHostState extends ConsumerState<_GateTestHost> {
  @override
  void initState() {
    super.initState();
    if (ref.read(isAuthenticatedProvider)) {
      Future.microtask(() => ref.read(profileProvider.notifier).fetchProfile());
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    listenForUpgradeDecision(ref);
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('de', 'DE')],
      locale: const Locale('de', 'DE'),
    );
  }
}

/// A profile repository whose first [getProfile] call blocks until
/// [release] is called, to observe the router while the profile loads.
class _SlowProfileRepository extends FakeProfileRepository {
  final _gate = Completer<void>();

  void release() => _gate.complete();

  @override
  Future<UserProfile?> getProfile(String userId) async {
    await _gate.future;
    return super.getProfile(userId);
  }
}

List<Override> _overrides({
  required FakeProfileRepository profiles,
  bool signedIn = true,
  UpgradeDecision decision = UpgradeDecision.ok,
}) => [
  authRepositoryProvider.overrideWithValue(
    FakeAuthRepository(signedIn: signedIn),
  ),
  profileRepositoryProvider.overrideWithValue(profiles),
  entryRepositoryProvider.overrideWithValue(FakeEntryRepository()),
  ingredientRepositoryProvider.overrideWithValue(FakeIngredientRepository()),
  upgradeDecisionProvider.overrideWith((_) => Future.value(decision)),
];

/// Signed-out tests start on /welcome, whose hint pulses forever unless
/// animations are disabled; `pumpAndSettle` needs it steady.
void _calmWelcome(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

String _currentPath(ProviderContainer container) =>
    container.read(routerProvider).routerDelegate.currentConfiguration.uri.path;

Future<ProviderContainer> _pumpHost(
  WidgetTester tester,
  List<Override> overrides,
) async {
  final container = ProviderContainer.test(overrides: overrides);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const _GateTestHost(),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

FakeProfileRepository _profilesWith(UserProfile profile) =>
    FakeProfileRepository()..seedProfile(profile);

void main() {
  setUp(() {
    // Keep the dashboard's notification opt-in dialog out of the way.
    SharedPreferences.setMockInitialValues({
      AppConstants.keyNotificationModalShown: true,
    });
  });

  group('Health consent gate', () {
    testWidgets('signed-in user without consent lands on the consent screen '
        'and cannot navigate away', (tester) async {
      final container = await _pumpHost(
        tester,
        _overrides(
          profiles: _profilesWith(testUserProfile(hasHealthConsent: false)),
        ),
      );

      expect(container.read(healthConsentRequiredProvider), isTrue);
      expect(_currentPath(container), RoutePaths.healthConsent);
      expect(find.byType(HealthConsentScreen), findsOneWidget);

      final router = container.read(routerProvider);
      for (final route in [
        RoutePaths.dashboard,
        RoutePaths.recommendations,
        RoutePaths.settings,
        RoutePaths.welcome,
      ]) {
        router.go(route);
        await tester.pumpAndSettle();
        expect(_currentPath(container), RoutePaths.healthConsent);
      }
      expect(find.byType(HealthConsentScreen), findsOneWidget);
    });

    testWidgets('an outdated privacy policy version triggers the gate', (
      tester,
    ) async {
      final container = await _pumpHost(
        tester,
        _overrides(
          profiles: _profilesWith(
            testUserProfile(privacyPolicyVersion: '2020-01-01'),
          ),
        ),
      );

      expect(_currentPath(container), RoutePaths.healthConsent);
      expect(find.byType(HealthConsentScreen), findsOneWidget);
    });

    testWidgets('a current consent passes and /health-consent is '
        'unreachable', (tester) async {
      final container = await _pumpHost(
        tester,
        _overrides(profiles: _profilesWith(testUserProfile())),
      );

      expect(container.read(healthConsentRequiredProvider), isFalse);
      expect(_currentPath(container), RoutePaths.dashboard);

      container.read(routerProvider).go(RoutePaths.healthConsent);
      await tester.pumpAndSettle();
      expect(_currentPath(container), RoutePaths.dashboard);
    });

    testWidgets('accepting writes both fields and leaves the gate', (
      tester,
    ) async {
      final profiles = _profilesWith(testUserProfile(hasHealthConsent: false));
      final container = await _pumpHost(tester, _overrides(profiles: profiles));
      expect(_currentPath(container), RoutePaths.healthConsent);

      await tester.ensureVisible(
        find.byKey(HealthConsentScreen.consentCheckboxKey),
      );
      await tester.tap(find.byKey(HealthConsentScreen.consentCheckboxKey));
      await tester.pump();
      await tester.ensureVisible(
        find.byKey(HealthConsentScreen.acceptButtonKey),
      );
      await tester.tap(find.byKey(HealthConsentScreen.acceptButtonKey));
      await tester.pumpAndSettle();

      expect(profiles.acceptHealthConsentCount, 1);
      final stored = profiles.storedProfile!;
      expect(stored.healthConsentAt, isNotNull);
      expect(stored.healthConsentAt!.isUtc, isTrue);
      expect(stored.privacyPolicyVersion, AppConstants.privacyPolicyVersion);

      final loaded = container.read(profileProvider).value!;
      expect(loaded.healthConsentAt, isNotNull);
      expect(loaded.privacyPolicyVersion, AppConstants.privacyPolicyVersion);

      expect(container.read(healthConsentRequiredProvider), isFalse);
      expect(_currentPath(container), RoutePaths.dashboard);
      expect(find.byType(HealthConsentScreen), findsNothing);

      // The gate stays lifted when the dashboard reloads the profile.
      container.read(routerProvider).go(RoutePaths.diary);
      await tester.pumpAndSettle();
      expect(_currentPath(container), RoutePaths.diary);
    });

    testWidgets('signed-out users are not gated', (tester) async {
      _calmWelcome(tester);
      final container = await _pumpHost(
        tester,
        _overrides(
          signedIn: false,
          profiles: _profilesWith(testUserProfile(hasHealthConsent: false)),
        ),
      );

      expect(container.read(healthConsentRequiredProvider), isFalse);
      expect(_currentPath(container), RoutePaths.welcome);

      final router = container.read(routerProvider);
      for (final route in [
        RoutePaths.auth,
        RoutePaths.registration,
        RoutePaths.resetPassword,
      ]) {
        router.go(route);
        await tester.pumpAndSettle();
        expect(_currentPath(container), route);
      }

      router.go(RoutePaths.healthConsent);
      await tester.pumpAndSettle();
      expect(_currentPath(container), RoutePaths.welcome);
    });

    testWidgets('a user who just registered is not gated', (tester) async {
      // The wizard's chip steps need more room than the 800x600 default.
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      _calmWelcome(tester);

      final profiles = FakeProfileRepository();
      final container = await _pumpHost(
        tester,
        _overrides(signedIn: false, profiles: profiles),
      );
      container.read(routerProvider).go(RoutePaths.registration);
      await tester.pumpAndSettle();

      await advanceToAuthStep(tester);
      await tester.enterText(
        find.byKey(AuthStep.emailFieldKey),
        'new@example.com',
      );
      await tester.enterText(
        find.byKey(BbPasswordField.passwordFieldKey),
        'TestPassword123',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AuthStep.submitButtonKey));
      await tester.pumpAndSettle();

      final stored = profiles.storedProfile!;
      expect(stored.healthConsentAt, isNotNull);
      expect(stored.privacyPolicyVersion, AppConstants.privacyPolicyVersion);
      expect(container.read(healthConsentRequiredProvider), isFalse);
      expect(_currentPath(container), RoutePaths.dashboard);
      expect(find.byType(HealthConsentScreen), findsNothing);
    });

    testWidgets('signing out from the consent screen reaches sign-in', (
      tester,
    ) async {
      final container = await _pumpHost(
        tester,
        _overrides(
          profiles: _profilesWith(testUserProfile(hasHealthConsent: false)),
        ),
      );
      expect(_currentPath(container), RoutePaths.healthConsent);

      await tester.ensureVisible(find.text('Abmelden'));
      await tester.tap(find.text('Abmelden'));
      await tester.pumpAndSettle();

      expect(_currentPath(container), RoutePaths.auth);
      expect(find.byType(HealthConsentScreen), findsNothing);
    });

    testWidgets('the gate waits for the profile instead of flashing', (
      tester,
    ) async {
      final profiles = _SlowProfileRepository()
        ..seedProfile(testUserProfile(hasHealthConsent: false));
      final container = await _pumpHost(tester, _overrides(profiles: profiles));

      // Profile still loading: no consent screen yet.
      expect(container.read(profileProvider).isLoading, isTrue);
      expect(container.read(healthConsentRequiredProvider), isFalse);
      expect(find.byType(HealthConsentScreen), findsNothing);

      profiles.release();
      await tester.pumpAndSettle();

      expect(_currentPath(container), RoutePaths.healthConsent);
      expect(find.byType(HealthConsentScreen), findsOneWidget);
    });

    testWidgets('the upgrade hard gate wins over the consent gate', (
      tester,
    ) async {
      final container = await _pumpHost(
        tester,
        _overrides(
          decision: UpgradeDecision.hardGate,
          profiles: _profilesWith(testUserProfile(hasHealthConsent: false)),
        ),
      );

      expect(container.read(healthConsentRequiredProvider), isTrue);
      expect(container.read(hardGateActiveProvider), isTrue);
      expect(_currentPath(container), RoutePaths.upgradeRequired);
      expect(find.byType(UpgradeRequiredScreen), findsOneWidget);

      final router = container.read(routerProvider);
      for (final route in [RoutePaths.healthConsent, RoutePaths.dashboard]) {
        router.go(route);
        await tester.pumpAndSettle();
        expect(_currentPath(container), RoutePaths.upgradeRequired);
      }
      expect(find.byType(HealthConsentScreen), findsNothing);
    });
  });
}
