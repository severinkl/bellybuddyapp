// ignore_for_file: invalid_use_of_internal_member
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/src/internals.dart' show Override;
import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/config/buddy_reactions.dart';
import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/models/buddy_state.dart';
import 'package:belly_buddy/router/route_names.dart';
import 'package:belly_buddy/screens/buddy/buddy_onboarding_screen.dart';
import 'package:belly_buddy/screens/health_consent/widgets/health_consent_content.dart';
import 'package:belly_buddy/screens/registration/registration_wizard_screen.dart';
import 'package:belly_buddy/screens/registration/steps/steps.dart';
import 'package:belly_buddy/screens/registration/steps/email_capture_step.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/repositories/auth_repository.dart';
import 'package:belly_buddy/repositories/buddy_repository.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';
import 'package:belly_buddy/repositories/profile_repository.dart';
import 'package:belly_buddy/widgets/buddy/buddy.dart';
import 'package:belly_buddy/widgets/common/bb_password_field.dart';
import 'package:belly_buddy/widgets/common/bb_scroll_picker.dart';
import 'package:belly_buddy/widgets/common/bb_social_button.dart';
import 'package:belly_buddy/widgets/common/mascot_image.dart';

import '../../helpers/fakes.dart';
import '../../helpers/fixtures.dart';
import '../../helpers/registration_driver.dart';
import '../../helpers/riverpod_helpers.dart';

List<Override> _overrides() => [
  authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
  profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
  currentUserIdProvider.overrideWithValue(null),
];

/// The Gender and Diet steps use column layouts with chips that need more
/// vertical room than the default 800x600 test viewport provides.
void _tallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpWizard(WidgetTester tester) async {
  _tallView(tester);
  await tester.pumpWithProviders(
    const RegistrationWizardScreen(),
    overrides: _overrides(),
  );
  await tester.pumpAndSettle();
}

/// The wizard's Buddy (one stage hosts every step).
BuddyController _buddy(WidgetTester tester) =>
    tester.widget<BuddyStage>(find.byType(BuddyStage)).controller;

BuddyLine _line(String key) => kWizardReactions[key]!;

/// The catalog lines of [key] with `{name}` filled in.
List<String> _lines(String key, {String name = 'Buddy'}) => [
  for (final line in _line(key).lines) line.replaceAll('{name}', name),
];

Future<void> _tapNext(WidgetTester tester) async {
  await tester.tap(find.byKey(RegistrationWizardScreen.nextButtonKey));
  await tester.pumpAndSettle();
}

/// From the name step to the step titled [titleKey], picking the default
/// chip on gated steps.
Future<void> _walkTo(WidgetTester tester, Key titleKey) async {
  await confirmRegistrationBuddyName(tester);
  await acceptRegistrationHealthConsent(tester);
  final picks = <Key, Key>{
    GenderStep.genderTitleKey: GenderStep.genderMaennlichKey,
    DietStep.dietTitleKey: DietStep.dietAllesKey,
  };
  for (final title in [
    BirthYearStep.birthYearTitleKey,
    GenderStep.genderTitleKey,
    HeightWeightStep.heightWeightTitleKey,
    DietStep.dietTitleKey,
    SymptomsStep.symptomsTitleKey,
    IntolerancesStep.intolerancesTitleKey,
  ]) {
    expect(find.byKey(title), findsOneWidget);
    if (title == titleKey) return;
    final pick = picks[title];
    if (pick != null) {
      await tester.tap(find.byKey(pick));
      await tester.pumpAndSettle();
    }
    await _tapNext(tester);
  }
}

/// A Buddy repository whose saves fail.
class _FailingBuddyRepository extends FakeBuddyRepository {
  @override
  Future<void> save(String userId, BuddyState state) async {
    saveCount++;
    throw Exception('save failed');
  }
}

class _RoutedWizard {
  _RoutedWizard(this.router, this.buddyRepo, this.profileRepo);

  final GoRouter router;
  final FakeBuddyRepository buddyRepo;
  final FakeProfileRepository profileRepo;

  String get path => router.routerDelegate.currentConfiguration.uri.path;
  String? get buddyName => buddyRepo.store[testUserId]?.name;
}

/// The wizard on `/registration` with stub routes for where it leads, a
/// signed-out [authRepo] and a Buddy repository to check the saved name.
Future<_RoutedWizard> _pumpRoutedWizard(
  WidgetTester tester, {
  FakeAuthRepository? authRepo,
  FakeBuddyRepository? buddyRepo,
}) async {
  _tallView(tester);
  final buddies = buddyRepo ?? FakeBuddyRepository();
  final profiles = FakeProfileRepository();
  final container = ProviderContainer.test(
    overrides: [
      authRepositoryProvider.overrideWithValue(
        authRepo ??
            FakeAuthRepository(signedIn: false, signInEmail: 'new@example.com'),
      ),
      profileRepositoryProvider.overrideWithValue(profiles),
      currentUserIdProvider.overrideWithValue(testUserId),
      buddyRepositoryProvider.overrideWithValue(buddies),
      entryRepositoryProvider.overrideWithValue(FakeEntryRepository()),
    ],
  );
  final router = GoRouter(
    initialLocation: RoutePaths.registration,
    routes: [
      GoRoute(
        path: RoutePaths.registration,
        builder: (_, _) => const RegistrationWizardScreen(),
      ),
      GoRoute(
        path: RoutePaths.buddyOnboarding,
        builder: (_, state) {
          final extra = state.extra;
          final entry = extra is BuddyOnboardingEntry ? extra.name : '-';
          return Scaffold(body: Text('onboarding:$entry'));
        },
      ),
      GoRoute(
        path: RoutePaths.dashboard,
        builder: (_, _) => const Scaffold(body: Text('dashboard-stub')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: AppTheme.theme,
        routerConfig: router,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('de', 'DE')],
        locale: const Locale('de', 'DE'),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _RoutedWizard(router, buddies, profiles);
}

Future<void> _signUpWithEmail(WidgetTester tester) async {
  await tester.enterText(find.byKey(AuthStep.emailFieldKey), 'new@example.com');
  await tester.enterText(
    find.byKey(BbPasswordField.passwordFieldKey),
    'TestPassword123',
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(AuthStep.submitButtonKey));
  await tester.pumpAndSettle();
}

void main() {
  group('RegistrationWizardScreen', () {
    testWidgets('renders linear progress indicator', (tester) async {
      await tester.pumpWithProviders(
        const RegistrationWizardScreen(),
        overrides: _overrides(),
      );
      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('renders Weiter button on first step', (tester) async {
      await tester.pumpWithProviders(
        const RegistrationWizardScreen(),
        overrides: _overrides(),
      );
      await tester.pump();

      expect(find.text('Weiter'), findsOneWidget);
    });

    testWidgets('renders Zur Anmeldung button', (tester) async {
      await tester.pumpWithProviders(
        const RegistrationWizardScreen(),
        overrides: _overrides(),
      );
      await tester.pump();

      expect(find.text('Zur Anmeldung'), findsOneWidget);
    });

    testWidgets('Weiter button is present and tappable', (tester) async {
      await tester.pumpWithProviders(
        const RegistrationWizardScreen(),
        overrides: _overrides(),
      );
      await tester.pump();

      expect(find.text('Weiter'), findsOneWidget);
      await tester.tap(find.text('Weiter'));
      await tester.pump(const Duration(milliseconds: 500));

      // After advancing, PageView moves to next step
      expect(find.byType(PageView), findsOneWidget);
    });
  });

  group('Health consent step', () {
    testWidgets('comes after the name and blocks "Weiter" until ticked', (
      tester,
    ) async {
      await tester.pumpWithProviders(
        const RegistrationWizardScreen(),
        overrides: _overrides(),
      );
      await tester.pumpAndSettle();
      await confirmRegistrationBuddyName(tester);

      expect(find.byKey(HealthConsentStep.titleKey), findsOneWidget);
      // The host shows the Buddy; the step has no mascot of its own.
      expect(find.byType(MascotImage), findsNothing);
      expect(find.text(HealthConsentContent.consentText), findsOneWidget);
      expect(find.text('Datenschutzerklärung lesen'), findsOneWidget);
      expect(registrationNextEnabled(tester), isFalse);

      // Tapping the disabled button does not advance.
      await tester.tap(find.byKey(RegistrationWizardScreen.nextButtonKey));
      await tester.pumpAndSettle();
      expect(find.byKey(HealthConsentStep.titleKey), findsOneWidget);
      expect(find.byKey(BirthYearStep.birthYearTitleKey), findsNothing);

      // Ticking and unticking toggles the button.
      final checkbox = find.byKey(HealthConsentContent.checkboxKey);
      await tester.ensureVisible(checkbox);
      await tester.tap(checkbox);
      await tester.pump();
      expect(registrationNextEnabled(tester), isTrue);
      await tester.tap(checkbox);
      await tester.pump();
      expect(registrationNextEnabled(tester), isFalse);

      await tester.tap(checkbox);
      await tester.pump();
      await tester.tap(find.byKey(RegistrationWizardScreen.nextButtonKey));
      await tester.pumpAndSettle();
      expect(find.byKey(BirthYearStep.birthYearTitleKey), findsOneWidget);
    });
  });

  group('Buddy name step', () {
    testWidgets('comes first, prefilled „Buddy", under the Buddy', (
      tester,
    ) async {
      await _pumpWizard(tester);

      expect(find.byKey(BuddyNameStep.titleKey), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(BuddyNameStep.fieldKey),
          matching: find.text('Buddy'),
        ),
        findsOneWidget,
      );
      expect(find.byType(BuddyStage), findsOneWidget);
      expect(find.byType(AnimatedBuddy), findsOneWidget);
      expect(registrationNextEnabled(tester), isTrue);
    });

    testWidgets('a blank name disables „Weiter"', (tester) async {
      await _pumpWizard(tester);
      final field = find.byKey(BuddyNameStep.fieldKey);

      await tester.enterText(field, '');
      await tester.pump();
      expect(registrationNextEnabled(tester), isFalse);

      await tester.enterText(field, '   ');
      await tester.pump();
      expect(registrationNextEnabled(tester), isFalse);

      // Tapping the disabled button does not advance.
      await _tapNext(tester);
      expect(find.byKey(BuddyNameStep.titleKey), findsOneWidget);

      await tester.enterText(field, 'Bauchi');
      await tester.pump();
      expect(registrationNextEnabled(tester), isTrue);
    });

    testWidgets('confirming makes the Buddy cheer with his new name', (
      tester,
    ) async {
      await _pumpWizard(tester);
      await tester.enterText(find.byKey(BuddyNameStep.fieldKey), ' Bauchi ');
      await tester.pump();
      await _tapNext(tester);

      final buddy = _buddy(tester);
      final confirmed = _line('name:confirmed');
      expect(find.byKey(HealthConsentStep.titleKey), findsOneWidget);
      expect(_lines('name:confirmed', name: 'Bauchi'), contains(buddy.bubble));
      expect(buddy.mood, confirmed.mood);
      expect(buddy.currentAction, confirmed.action);
      // The Buddy is called by his new name.
      expect(tester.widget<BuddyStage>(find.byType(BuddyStage)).name, 'Bauchi');
    });

    testWidgets(
      'the consent step then shows the Buddy\'s quiet line above it',
      (tester) async {
        // Ticking so the speech bubble renders what the Buddy says.
        AnimatedBuddy.tickerEnabled = true;
        addTearDown(() => AnimatedBuddy.tickerEnabled = false);
        _tallView(tester);
        await tester.pumpWithProviders(
          const RegistrationWizardScreen(),
          overrides: _overrides(),
        );
        await tester.pump();

        await tester.tap(find.byKey(RegistrationWizardScreen.nextButtonKey));
        await tester.pump();
        await tester.pump(AppConstants.animMedium);
        expect(find.byKey(HealthConsentStep.titleKey), findsOneWidget);

        await tester.pump(RegistrationWizardScreen.buddyFollowUpDelay);
        await tester.pump(AppConstants.animMedium);

        final consentLine = _line('consent:intro').lines.single;
        expect(consentLine, startsWith('Bevor du mir von deinem Bauch'));
        expect(_buddy(tester).bubble, consentLine);
        expect(find.text(consentLine), findsOneWidget);
      },
    );

    testWidgets('stays usable with the keyboard open on a small phone', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWithProviders(
        const RegistrationWizardScreen(),
        overrides: _overrides(),
      );
      await tester.pumpAndSettle();

      final field = find.byKey(BuddyNameStep.fieldKey);
      await tester.showKeyboard(field);
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();

      // No overflow; the field scrolled above the keyboard and „Weiter"
      // is still reachable.
      expect(tester.takeException(), isNull);
      expect(field.hitTestable(), findsOneWidget);
      expect(tester.getRect(field).bottom, lessThanOrEqualTo(667 - 260));
      final next = find.byKey(RegistrationWizardScreen.nextButtonKey);
      expect(next.hitTestable(), findsOneWidget);
      expect(tester.getRect(next).bottom, lessThanOrEqualTo(667 - 260));

      await tester.enterText(field, 'Bauchi');
      await tester.pump();
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(find.byKey(HealthConsentStep.titleKey), findsOneWidget);
    });
  });

  group('Small phone', () {
    testWidgets('every profile step fits 375×667 under the Buddy', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWithProviders(
        const RegistrationWizardScreen(),
        overrides: _overrides(),
      );
      await tester.pumpAndSettle();

      Future<void> tapVisible(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      await confirmRegistrationBuddyName(tester);
      await acceptRegistrationHealthConsent(tester);
      await _tapNext(tester); // birth year
      await tapVisible(find.byKey(GenderStep.genderAndereKey));
      await _tapNext(tester);
      await _tapNext(tester); // height & weight
      await tapVisible(find.text('Vegan'));
      await _tapNext(tester);
      await tapVisible(find.text(kRegistrationSymptoms.last));
      await _tapNext(tester);
      await tapVisible(find.text('Gluten'));

      // Overflows would have failed the test on the way. (The auth step's
      // social buttons are too wide for 375 px in the test font, as before.)
      expect(find.byKey(IntolerancesStep.intolerancesTitleKey), findsOneWidget);
      expect(find.byType(BuddyStage), findsOneWidget);
    });
  });

  group('Buddy reactions', () {
    testWidgets('every step introduces itself, the auth step too', (
      tester,
    ) async {
      await _pumpWizard(tester);
      await confirmRegistrationBuddyName(tester);
      await acceptRegistrationHealthConsent(tester);

      final buddy = _buddy(tester);
      expect(_lines('step:birthYear'), contains(buddy.bubble));
      await _tapNext(tester);
      expect(_lines('step:gender'), contains(buddy.bubble));
      expect(buddy.mood, _line('step:gender').mood);

      await tester.tap(find.byKey(GenderStep.genderMaennlichKey));
      await tester.pumpAndSettle();
      await _tapNext(tester);
      expect(_lines('step:heightWeight'), contains(buddy.bubble));
      await _tapNext(tester);
      expect(_lines('step:diet'), contains(buddy.bubble));
      expect(buddy.mood, _line('step:diet').mood);

      await tester.tap(find.byKey(DietStep.dietAllesKey));
      await tester.pumpAndSettle();
      await _tapNext(tester);
      expect(_lines('step:symptoms'), contains(buddy.bubble));

      await tester.tap(find.text(kRegistrationSymptoms.first));
      await tester.pumpAndSettle();
      await _tapNext(tester);
      expect(_lines('step:intolerances'), contains(buddy.bubble));

      await tester.tap(find.text('Gluten'));
      await tester.pumpAndSettle();
      await _tapNext(tester);
      expect(find.byType(AuthStep), findsOneWidget);
      expect(_lines('auth:intro'), contains(buddy.bubble));
    });

    testWidgets('going back introduces the previous step again', (
      tester,
    ) async {
      await _pumpWizard(tester);
      await _walkTo(tester, GenderStep.genderTitleKey);

      await tester.tap(find.text('Zurück'));
      await tester.pumpAndSettle();

      expect(find.byKey(BirthYearStep.birthYearTitleKey), findsOneWidget);
      expect(_lines('step:birthYear'), contains(_buddy(tester).bubble));
    });

    testWidgets('choosing „weiblich" gets the catalog line', (tester) async {
      await _pumpWizard(tester);
      await _walkTo(tester, GenderStep.genderTitleKey);

      await tester.tap(find.byKey(GenderStep.genderWeiblichKey));
      await tester.pumpAndSettle();

      final buddy = _buddy(tester);
      expect(_lines('gender:weiblich'), contains(buddy.bubble));
      expect(buddy.mood, _line('gender:weiblich').mood);
    });

    testWidgets('choosing „vegan" makes the Buddy fall in love', (
      tester,
    ) async {
      await _pumpWizard(tester);
      await _walkTo(tester, DietStep.dietTitleKey);

      await tester.tap(find.text('Vegan'));
      await tester.pumpAndSettle();

      final buddy = _buddy(tester);
      expect(buddy.mood, BuddyMood.inLove);
      expect(_lines('diet:vegan'), contains(buddy.bubble));
    });

    testWidgets('a settled birth year gets a nod, not every scroll tick', (
      tester,
    ) async {
      await _pumpWizard(tester);
      await _walkTo(tester, BirthYearStep.birthYearTitleKey);
      final buddy = _buddy(tester);
      expect(_lines('step:birthYear'), contains(buddy.bubble));
      final id = buddy.bubbleId;

      await tester.drag(find.byType(BbScrollPicker), const Offset(0, -120));
      await tester.pumpAndSettle();
      expect(buddy.bubbleId, id);

      await tester.pump(RegistrationWizardScreen.buddyPickerSettle);
      expect(_lines('birthYear:any'), contains(buddy.bubble));
      expect(buddy.currentAction, BuddyAction.nodYes);
    });

    testWidgets('symptoms: the newest pick gets a reaction, a deselect not', (
      tester,
    ) async {
      await _pumpWizard(tester);
      await _walkTo(tester, SymptomsStep.symptomsTitleKey);
      final buddy = _buddy(tester);

      await tester.tap(find.text('Nervige Verstopfung'));
      await tester.pumpAndSettle();
      expect(_lines('symptom:Nervige Verstopfung'), contains(buddy.bubble));

      await tester.tap(find.text('Unangenehme Blähungen'));
      await tester.pumpAndSettle();
      expect(_lines('symptom:Unangenehme Blähungen'), contains(buddy.bubble));
      expect(buddy.mood, BuddyMood.empathetic);

      final id = buddy.bubbleId;
      await tester.tap(find.text('Nervige Verstopfung'));
      await tester.pumpAndSettle();
      expect(buddy.bubbleId, id);
    });

    testWidgets('no symptoms: the Buddy cheers on „Weiter", then asks on', (
      tester,
    ) async {
      await _pumpWizard(tester);
      await _walkTo(tester, SymptomsStep.symptomsTitleKey);
      final buddy = _buddy(tester);

      await _tapNext(tester);
      expect(find.byKey(IntolerancesStep.intolerancesTitleKey), findsOneWidget);
      expect(_lines('symptom:none'), contains(buddy.bubble));
      expect(buddy.currentAction, BuddyAction.celebrate);

      await tester.pump(RegistrationWizardScreen.buddyFollowUpDelay);
      expect(_lines('step:intolerances'), contains(buddy.bubble));
    });

    testWidgets('intolerances: a pick makes him think; none gets a cheer', (
      tester,
    ) async {
      await _pumpWizard(tester);
      await _walkTo(tester, IntolerancesStep.intolerancesTitleKey);
      final buddy = _buddy(tester);

      await tester.tap(find.text('Gluten'));
      await tester.pumpAndSettle();
      expect(_lines('intolerance:Gluten'), contains(buddy.bubble));
      expect(buddy.currentAction, BuddyAction.think);

      // Deselecting reacts with nothing; leaving with none selected cheers.
      final id = buddy.bubbleId;
      await tester.tap(find.text('Gluten'));
      await tester.pumpAndSettle();
      expect(buddy.bubbleId, id);

      await _tapNext(tester);
      expect(find.byType(AuthStep), findsOneWidget);
      expect(_lines('intolerance:none'), contains(buddy.bubble));
      expect(buddy.currentAction, BuddyAction.celebrate);

      await tester.pump(RegistrationWizardScreen.buddyFollowUpDelay);
      expect(_lines('auth:intro'), contains(buddy.bubble));
    });

    testWidgets('the profile steps show no mascot of their own', (
      tester,
    ) async {
      await _pumpWizard(tester);
      await confirmRegistrationBuddyName(tester);
      await acceptRegistrationHealthConsent(tester);
      for (final pick in <Key?>[
        null,
        GenderStep.genderMaennlichKey,
        null,
        DietStep.dietAllesKey,
        null,
        null,
      ]) {
        expect(find.byType(MascotImage), findsNothing);
        if (pick != null) {
          await tester.tap(find.byKey(pick));
          await tester.pumpAndSettle();
        }
        await _tapNext(tester);
      }
      expect(find.byType(AuthStep), findsOneWidget);
      expect(find.byType(BuddyStage), findsOneWidget);
    });
  });

  group('After sign-up', () {
    testWidgets('email sign-up saves the profile and the typed name, then '
        'opens the Buddy onboarding', (tester) async {
      final app = await _pumpRoutedWizard(tester);

      await tester.enterText(find.byKey(BuddyNameStep.fieldKey), 'Bauchi');
      await tester.pump();
      await advanceToAuthStep(tester);
      await _signUpWithEmail(tester);

      expect(app.path, RoutePaths.buddyOnboarding);
      expect(find.text('onboarding:afterRegistration'), findsOneWidget);
      expect(app.buddyName, 'Bauchi');
      final stored = app.profileRepo.storedProfile!;
      expect(stored.healthConsentAt, isNotNull);
      expect(stored.healthConsentAt!.isUtc, isTrue);
      expect(stored.privacyPolicyVersion, AppConstants.privacyPolicyVersion);
    });

    testWidgets('Google with a real email saves the default name', (
      tester,
    ) async {
      final app = await _pumpRoutedWizard(tester);

      await advanceToAuthStep(tester);
      await tester.tap(
        find.widgetWithText(BbSocialButton, 'Mit Google fortfahren'),
      );
      await tester.pumpAndSettle();

      expect(app.path, RoutePaths.buddyOnboarding);
      expect(find.text('onboarding:afterRegistration'), findsOneWidget);
      expect(app.buddyName, 'Buddy');
      expect(app.profileRepo.lastWrittenEmail, 'new@example.com');
    });

    testWidgets('email capture skip saves the name, then opens the Buddy '
        'onboarding', (tester) async {
      final app = await _pumpRoutedWizard(
        tester,
        authRepo: FakeAuthRepository(
          signedIn: false,
          signInEmail: 'abc@privaterelay.appleid.com',
        ),
      );

      await tester.enterText(find.byKey(BuddyNameStep.fieldKey), 'Bauchi');
      await tester.pump();
      await advanceToAuthStep(tester);
      await tester.tap(
        find.widgetWithText(BbSocialButton, 'Mit Google fortfahren'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(EmailCaptureStep), findsOneWidget);
      expect(app.buddyName, isNull);

      await tester.tap(find.byKey(EmailCaptureStep.skipButtonKey));
      await tester.pumpAndSettle();

      expect(app.path, RoutePaths.buddyOnboarding);
      expect(find.text('onboarding:afterRegistration'), findsOneWidget);
      expect(app.buddyName, 'Bauchi');
      final stored = app.profileRepo.storedProfile!;
      expect(stored.email, isNull);
      expect(stored.healthConsentAt, isNotNull);
      expect(stored.privacyPolicyVersion, AppConstants.privacyPolicyVersion);
    });

    testWidgets('email capture submit saves the name, then opens the Buddy '
        'onboarding', (tester) async {
      final app = await _pumpRoutedWizard(
        tester,
        authRepo: FakeAuthRepository(signedIn: false, signInEmail: null),
      );

      await tester.enterText(find.byKey(BuddyNameStep.fieldKey), 'Bauchi');
      await tester.pump();
      await advanceToAuthStep(tester);
      await tester.tap(
        find.widgetWithText(BbSocialButton, 'Mit Google fortfahren'),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(EmailCaptureStep.emailFieldKey),
        'user@example.com',
      );
      await tester.pump();
      await tester.tap(find.byKey(EmailCaptureStep.submitButtonKey));
      await tester.pumpAndSettle();

      expect(app.path, RoutePaths.buddyOnboarding);
      expect(find.text('onboarding:afterRegistration'), findsOneWidget);
      expect(app.buddyName, 'Bauchi');
      expect(app.profileRepo.lastWrittenEmail, 'user@example.com');
    });

    testWidgets('a failing name save does not block the onboarding', (
      tester,
    ) async {
      final buddies = _FailingBuddyRepository();
      final app = await _pumpRoutedWizard(tester, buddyRepo: buddies);

      await advanceToAuthStep(tester);
      await _signUpWithEmail(tester);

      expect(buddies.saveCount, greaterThan(0));
      expect(app.path, RoutePaths.buddyOnboarding);
      expect(find.text('onboarding:afterRegistration'), findsOneWidget);
      expect(app.profileRepo.storedProfile, isNotNull);
    });
  });

  group('OAuth email capture branch', () {
    // All three tests drive sign-in through the Google button. Apple's
    // `BbSocialButton.apple` is only rendered when `Platform.isIOS`, which is
    // false under `flutter test` on the host VM. The detection logic in the
    // wizard (`_needsEmailCapture` + `_finalizeAfterOAuthSignIn`) is
    // provider-agnostic, so driving the three seeded-email cases through
    // Google exercises the same branching regardless of which OAuth provider
    // would be used in production.

    Future<void> pumpWizard(
      WidgetTester tester, {
      required FakeAuthRepository authRepo,
      required FakeProfileRepository profileRepo,
    }) async {
      // The Gender and Diet steps use column layouts with chips that need
      // more vertical room than the default 800x600 test viewport provides.
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWithProviders(
        const RegistrationWizardScreen(),
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepo),
          profileRepositoryProvider.overrideWithValue(profileRepo),
          currentUserIdProvider.overrideWithValue(null),
        ],
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'Google sign-in with a real email skips the email capture step',
      (tester) async {
        final authRepo = FakeAuthRepository(
          signedIn: false,
          signInEmail: 'real@example.com',
        );
        final profileRepo = FakeProfileRepository();
        await pumpWizard(tester, authRepo: authRepo, profileRepo: profileRepo);
        await advanceToAuthStep(tester);

        await tester.tap(
          find.widgetWithText(BbSocialButton, 'Mit Google fortfahren'),
        );
        await tester.pumpAndSettle();

        expect(find.byType(EmailCaptureStep), findsNothing);
        // Positive assertion: the skip branch must have reached _createProfile
        // with the auth user's email. Without this, a silent failure in
        // _finalizeAfterOAuthSignIn (e.g. GoRouter not found) would also
        // produce `findsNothing` and pass vacuously.
        expect(profileRepo.lastWrittenEmail, equals('real@example.com'));

        // The consent given on the first step is stored with the profile.
        final stored = profileRepo.storedProfile!;
        expect(stored.healthConsentAt, isNotNull);
        expect(stored.healthConsentAt!.isUtc, isTrue);
        expect(stored.privacyPolicyVersion, AppConstants.privacyPolicyVersion);
      },
    );

    testWidgets(
      'Google sign-in with Apple relay email shows the email capture step',
      (tester) async {
        // Seeds an Apple relay address on the Google path (see group comment):
        // the branching logic is provider-agnostic, so this exercises the
        // "Apple Hide My Email" case through the only button that renders
        // in the host-VM test binding.
        final authRepo = FakeAuthRepository(
          signedIn: false,
          signInEmail: 'abc@privaterelay.appleid.com',
        );
        final profileRepo = FakeProfileRepository();
        await pumpWizard(tester, authRepo: authRepo, profileRepo: profileRepo);
        await advanceToAuthStep(tester);

        await tester.tap(
          find.widgetWithText(BbSocialButton, 'Mit Google fortfahren'),
        );
        await tester.pumpAndSettle();

        expect(find.byType(EmailCaptureStep), findsOneWidget);
        // createProfile must NOT have fired yet — the wizard is waiting on
        // the user to type a real email on the new step.
        expect(profileRepo.lastWrittenEmail, isNull);
      },
    );

    testWidgets(
      'Google sign-in with empty email shows the email capture step',
      (tester) async {
        // Seeds a null email (simulates Apple second-sign-in) via the Google
        // path for the reasons documented in the group comment.
        final authRepo = FakeAuthRepository(signedIn: false, signInEmail: null);
        final profileRepo = FakeProfileRepository();
        await pumpWizard(tester, authRepo: authRepo, profileRepo: profileRepo);
        await advanceToAuthStep(tester);

        await tester.tap(
          find.widgetWithText(BbSocialButton, 'Mit Google fortfahren'),
        );
        await tester.pumpAndSettle();

        expect(find.byType(EmailCaptureStep), findsOneWidget);
        expect(profileRepo.lastWrittenEmail, isNull);
      },
    );
  });
}
