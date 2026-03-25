import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/widgets/common/bb_bottom_nav.dart';

/// Builds a real GoRouter that uses [BbBottomNav] as the shell.
GoRouter _buildRouter() {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => BbBottomNav(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) =>
                    const Scaffold(body: Text('Home Screen')),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/diary',
                builder: (context, state) =>
                    const Scaffold(body: Text('Diary Screen')),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

/// Pumps a widget tree with the given [router].
Future<void> pumpRouterApp(WidgetTester tester, GoRouter router) async {
  await tester.pumpWidget(
    ProviderScope(
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
}

void main() {
  group('BbBottomNav', () {
    testWidgets('renders Home and Tagebuch nav labels', (tester) async {
      await pumpRouterApp(tester, _buildRouter());
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Tagebuch'), findsOneWidget);
    });

    testWidgets('renders center Essen tracken label', (tester) async {
      await pumpRouterApp(tester, _buildRouter());
      expect(find.text('Essen tracken'), findsOneWidget);
    });

    testWidgets('renders home and menu_book icons', (tester) async {
      await pumpRouterApp(tester, _buildRouter());
      // Home branch active (index 0) — filled home icon shown
      expect(find.byIcon(Icons.home), findsOneWidget);
      // Diary branch inactive — outlined menu_book shown
      expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
    });
  });
}
