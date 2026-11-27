// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:riverpod/src/internals.dart' show Override;
import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/router/route_names.dart';
import 'package:belly_buddy/screens/auth/auth_screen.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/repositories/auth_repository.dart';
import 'package:belly_buddy/repositories/profile_repository.dart';

import '../../helpers/fakes.dart';
import '../../helpers/riverpod_helpers.dart';

List<Override> _overrides() => [
  authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
  profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
  currentUserIdProvider.overrideWithValue(null),
];

void main() {
  group('AuthScreen', () {
    testWidgets('renders email field', (tester) async {
      await tester.pumpWithProviders(
        const AuthScreen(),
        overrides: _overrides(),
      );
      await tester.pump();

      expect(find.text('E-Mail'), findsAtLeast(1));
    });

    testWidgets('renders Anmelden button', (tester) async {
      await tester.pumpWithProviders(
        const AuthScreen(),
        overrides: _overrides(),
      );
      await tester.pump();

      expect(find.text('Anmelden'), findsOneWidget);
    });

    testWidgets('renders Willkommen zurück heading', (tester) async {
      await tester.pumpWithProviders(
        const AuthScreen(),
        overrides: _overrides(),
      );
      await tester.pump();

      expect(find.text('Willkommen zurück'), findsOneWidget);
    });

    testWidgets('switches to forgot-password view on tap', (tester) async {
      await tester.pumpWithProviders(
        const AuthScreen(),
        overrides: _overrides(),
      );
      await tester.pump();

      // Tap the TextButton "Passwort vergessen?" (not the label, the button)
      await tester.tap(find.text('Passwort vergessen?').first);
      await tester.pump();

      expect(find.text('Zurücksetzen'), findsOneWidget);
    });

    testWidgets('shows validation error when submitting empty form', (
      tester,
    ) async {
      await tester.pumpWithProviders(
        const AuthScreen(),
        overrides: _overrides(),
      );
      await tester.pump();

      await tester.tap(find.text('Anmelden'));
      await tester.pump();

      expect(find.text('E-Mail ist erforderlich'), findsOneWidget);
    });

    testWidgets('a wrong password puts „E-Mail oder Passwort ist falsch." in '
        'a live region', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWithProviders(
        const AuthScreen(),
        overrides: [
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(signedIn: false, shouldFailEmailSignIn: true),
          ),
          profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
          currentUserIdProvider.overrideWithValue(null),
        ],
      );
      await tester.pump();

      await tester.enterText(
        find.byKey(AuthScreen.emailFieldKey),
        'du@example.com',
      );
      await tester.enterText(
        find.byKey(AuthScreen.passwordFieldKey),
        'falschesPasswort1',
      );
      await tester.tap(find.byKey(AuthScreen.submitLoginButtonKey));
      await tester.pumpAndSettle();

      expect(
        find.semantics.byPredicate(
          (n) =>
              n.label == 'E-Mail oder Passwort ist falsch.' &&
              n.flagsCollection.isLiveRegion,
        ),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('AuthScreen navigation', () {
    /// The sign-in screen in a router with a stub welcome page; starts on
    /// the welcome page and pushes the sign-in like „Ich habe schon ein
    /// Konto" does ([pushed]), or opens the sign-in directly (after
    /// signing out, or from the registration).
    Future<GoRouter> pumpRouted(
      WidgetTester tester, {
      required bool pushed,
    }) async {
      final router = GoRouter(
        initialLocation: pushed ? RoutePaths.welcome : RoutePaths.auth,
        routes: [
          GoRoute(
            path: RoutePaths.welcome,
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () => context.push(RoutePaths.auth),
                child: const Text('welcome-page'),
              ),
            ),
          ),
          GoRoute(path: RoutePaths.auth, builder: (_, _) => const AuthScreen()),
          GoRoute(
            path: RoutePaths.registration,
            builder: (_, _) => const Scaffold(body: Text('registration-page')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: _overrides(),
          child: MaterialApp.router(
            theme: AppTheme.theme,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (pushed) {
        await tester.tap(find.text('welcome-page'));
        await tester.pumpAndSettle();
      }
      expect(find.byType(AuthScreen), findsOneWidget);
      return router;
    }

    // The top-most location, pushed routes included.
    String path(GoRouter router) =>
        router.routerDelegate.currentConfiguration.last.matchedLocation;

    for (final pushed in [true, false]) {
      final how = pushed ? 'from the welcome screen' : 'opened directly';
      testWidgets('the back button leads to the welcome screen ($how)', (
        tester,
      ) async {
        final router = await pumpRouted(tester, pushed: pushed);

        await tester.tap(find.byKey(AuthScreen.backButtonKey));
        await tester.pumpAndSettle();

        expect(path(router), RoutePaths.welcome);
        expect(find.text('welcome-page'), findsOneWidget);
      });

      testWidgets('„Registrieren" goes straight into the sign-up, not back '
          'to the sleeping Buddy ($how)', (tester) async {
        final router = await pumpRouted(tester, pushed: pushed);

        final register = find.text('Noch kein Konto? Registrieren');
        await tester.ensureVisible(register);
        await tester.tap(register);
        await tester.pumpAndSettle();

        expect(path(router), RoutePaths.registration);
        expect(find.text('registration-page'), findsOneWidget);
      });
    }

    testWidgets('in „Passwort vergessen?" the back button returns to the '
        'sign-in', (tester) async {
      final router = await pumpRouted(tester, pushed: true);

      await tester.tap(find.text('Passwort vergessen?').first);
      await tester.pumpAndSettle();
      expect(find.text('Zurücksetzen'), findsOneWidget);

      await tester.tap(find.byKey(AuthScreen.backButtonKey));
      await tester.pumpAndSettle();

      expect(path(router), RoutePaths.auth);
      expect(find.text('Willkommen zurück'), findsOneWidget);
    });
  });
}
