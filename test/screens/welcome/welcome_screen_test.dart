import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/router/route_names.dart';
import 'package:belly_buddy/screens/welcome/welcome_screen.dart';
import 'package:belly_buddy/widgets/buddy/buddy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

const _line1 = 'Hi! Ich bin dein Belly Buddy.';
const _line2 = 'Ich helfe dir herauszufinden, was deinem Bauch guttut.';
const _line3 = 'Lass uns uns kennenlernen!';
const _hint = 'Tippe, um ihn zu wecken';
const _letsGo = "Los geht's";
const _signIn = 'Ich habe schon ein Konto';

/// Auto-advance step used by the story tests (the screen paces at 2.5 s).
const _step = Duration(milliseconds: 2600);

/// Pumps the welcome screen on a phone-sized view inside a router with stub
/// registration and auth pages. The animated Buddy ticks forever, so tests
/// use `pump(Duration)` instead of `pumpAndSettle`.
Future<GoRouter> _pump(WidgetTester tester, {bool calm = false}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final router = GoRouter(
    initialLocation: RoutePaths.welcome,
    routes: [
      GoRoute(
        path: RoutePaths.welcome,
        builder: (_, _) => const WelcomeScreen(),
      ),
      GoRoute(
        path: RoutePaths.registration,
        builder: (_, _) => const Scaffold(body: Text('registration-page')),
      ),
      GoRoute(
        path: RoutePaths.auth,
        builder: (_, _) => const Scaffold(body: Text('auth-page')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp.router(
        theme: AppTheme.theme,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: calm),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  return router;
}

BuddyController _buddy(WidgetTester tester) =>
    tester.widget<AnimatedBuddy>(find.byType(AnimatedBuddy)).controller;

String _path(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.path;

/// Lets a page transition finish (the welcome Buddy is gone afterwards).
Future<void> _settleNavigation(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  group('WelcomeScreen', () {
    testWidgets('starts with a sleeping Buddy, the wake hint and the '
        'sign-in link, but no „Los geht\'s"', (tester) async {
      await _pump(tester);

      expect(find.byKey(WelcomeScreen.buddyAreaKey), findsOneWidget);
      expect(find.byKey(WelcomeScreen.hintKey), findsOneWidget);
      expect(find.text(_hint), findsOneWidget);
      expect(find.byKey(WelcomeScreen.registrationButtonKey), findsNothing);
      expect(find.text(_letsGo), findsNothing);
      expect(find.byKey(WelcomeScreen.signInButtonKey), findsOneWidget);
      expect(find.text(_signIn), findsOneWidget);

      final buddy = _buddy(tester);
      expect(buddy.currentAction, isNull);
      expect(buddy.bubble, isNull);
      // Asleep: eyes shut, zzZ.
      expect(buddy.mood, BuddyMood.asleep);
      expect(buddy.frame.face.lidTop, greaterThanOrEqualTo(0.95));
      expect(buddy.frame.face.zzz, greaterThan(0.9));
    });

    testWidgets('screen readers hear that the Buddy is asleep', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester);

      expect(find.bySemanticsLabel('Buddy, schläft'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('tapping the Buddy area wakes him up', (tester) async {
      await _pump(tester);

      await tester.tap(find.byKey(WelcomeScreen.buddyAreaKey));
      await tester.pump(const Duration(milliseconds: 100));

      expect(_buddy(tester).currentAction, BuddyAction.wakeUp);
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(WelcomeScreen.hintKey), findsNothing);
    });

    testWidgets('waking up opens his eyes and stops the zzZ', (tester) async {
      await _pump(tester);
      await tester.tap(find.byKey(WelcomeScreen.buddyAreaKey));

      // 1.6 s of real frames: lids opened, blinks done, hop under way.
      for (var i = 0; i < 96; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      final face = _buddy(tester).frame.face;
      expect(_buddy(tester).currentAction, BuddyAction.wakeUp);
      expect(face.lidTop, lessThan(0.1));
      expect(face.zzz, lessThan(0.05));

      // The zzZ must not come back when he starts waving and talking.
      var maxZzz = 0.0;
      for (var i = 0; i < 100; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        final z = _buddy(tester).frame.face.zzz;
        if (z > maxZzz) maxZzz = z;
      }
      expect(find.text(_line1), findsOneWidget);
      expect(maxZzz, lessThan(0.05));
    });

    testWidgets('tapping the hint wakes him up too', (tester) async {
      await _pump(tester);

      await tester.tap(find.byKey(WelcomeScreen.hintKey));
      await tester.pump(const Duration(milliseconds: 100));

      expect(_buddy(tester).currentAction, BuddyAction.wakeUp);
    });

    testWidgets('after waking up he waves and tells the three lines in '
        'order, then „Los geht\'s" appears', (tester) async {
      await _pump(tester);
      await tester.tap(find.byKey(WelcomeScreen.buddyAreaKey));

      await tester.pump(_step);
      expect(find.text(_line1), findsOneWidget);
      expect(_buddy(tester).currentAction, BuddyAction.wave);
      expect(find.text(_line2), findsNothing);
      expect(find.byKey(WelcomeScreen.registrationButtonKey), findsNothing);

      await tester.pump(_step);
      expect(find.text(_line2), findsOneWidget);
      expect(find.text(_line3), findsNothing);
      expect(find.byKey(WelcomeScreen.registrationButtonKey), findsNothing);

      await tester.pump(_step);
      expect(find.text(_line3), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(WelcomeScreen.registrationButtonKey), findsOneWidget);
      expect(find.text(_letsGo), findsOneWidget);
      expect(find.byKey(WelcomeScreen.signInButtonKey), findsOneWidget);

      // The last line stays up next to the button.
      await tester.pump(const Duration(seconds: 10));
      expect(find.text(_line3), findsOneWidget);
      expect(find.byKey(WelcomeScreen.registrationButtonKey), findsOneWidget);
    });

    testWidgets('tapping the Buddy area advances the lines without waiting', (
      tester,
    ) async {
      await _pump(tester);
      await tester.tap(find.byKey(WelcomeScreen.buddyAreaKey));
      await tester.pump(_step);
      expect(find.text(_line1), findsOneWidget);

      await tester.tap(find.byKey(WelcomeScreen.buddyAreaKey));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text(_line2), findsOneWidget);

      await tester.tap(find.byKey(WelcomeScreen.buddyAreaKey));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text(_line3), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(WelcomeScreen.registrationButtonKey), findsOneWidget);
    });

    testWidgets('„Los geht\'s" opens the registration', (tester) async {
      final router = await _pump(tester);
      await tester.tap(find.byKey(WelcomeScreen.buddyAreaKey));
      for (var i = 0; i < 4; i++) {
        await tester.pump(_step);
      }

      await tester.tap(find.byKey(WelcomeScreen.registrationButtonKey));
      await _settleNavigation(tester);

      expect(_path(router), RoutePaths.registration);
      expect(find.text('registration-page'), findsOneWidget);
    });

    testWidgets('once awake, tapping the Buddy starts like „Los geht\'s"', (
      tester,
    ) async {
      final router = await _pump(tester);
      await tester.tap(find.byKey(WelcomeScreen.buddyAreaKey));
      for (var i = 0; i < 4; i++) {
        await tester.pump(_step);
      }
      expect(find.byKey(WelcomeScreen.registrationButtonKey), findsOneWidget);

      await tester.tap(find.byKey(WelcomeScreen.buddyAreaKey));
      await _settleNavigation(tester);

      expect(_path(router), RoutePaths.registration);
      expect(find.text('registration-page'), findsOneWidget);
    });

    testWidgets('tapping the Buddy mid-story does not start the flow', (
      tester,
    ) async {
      final router = await _pump(tester);
      await tester.tap(find.byKey(WelcomeScreen.buddyAreaKey));
      await tester.pump(_step);
      expect(find.text(_line1), findsOneWidget);

      await tester.tap(find.byKey(WelcomeScreen.buddyAreaKey));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text(_line2), findsOneWidget);
      expect(_path(router), isNot(RoutePaths.registration));
    });

    testWidgets('„Ich habe schon ein Konto" opens the sign-in right away', (
      tester,
    ) async {
      final router = await _pump(tester);

      await tester.tap(find.byKey(WelcomeScreen.signInButtonKey));
      await _settleNavigation(tester);

      expect(_path(router), RoutePaths.auth);
      expect(find.text('auth-page'), findsOneWidget);
    });

    testWidgets('leaving mid-story cancels the story timers', (tester) async {
      final router = await _pump(tester);
      await tester.tap(find.byKey(WelcomeScreen.buddyAreaKey));
      await tester.pump(_step);
      expect(find.text(_line1), findsOneWidget);

      await tester.tap(find.byKey(WelcomeScreen.signInButtonKey));
      await _settleNavigation(tester);
      await tester.pump(const Duration(seconds: 10));

      expect(_path(router), RoutePaths.auth);
      expect(find.byType(WelcomeScreen), findsNothing);
    });

    testWidgets('with reduced motion waking skips straight to the first '
        'line and the story still reaches „Los geht\'s"', (tester) async {
      await _pump(tester, calm: true);

      await tester.tap(find.byKey(WelcomeScreen.buddyAreaKey));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text(_line1), findsOneWidget);
      expect(_buddy(tester).currentAction, isNot(BuddyAction.wakeUp));

      await tester.pump(_step);
      expect(find.text(_line2), findsOneWidget);
      await tester.pump(_step);
      expect(find.text(_line3), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(WelcomeScreen.registrationButtonKey), findsOneWidget);
    });
  });
}
