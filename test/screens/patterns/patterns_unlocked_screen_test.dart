import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/screens/patterns/patterns_unlocked_screen.dart';
import 'package:belly_buddy/widgets/buddy/animated_buddy.dart';
import 'package:belly_buddy/widgets/buddy/buddy_actions.dart';
import 'package:belly_buddy/widgets/buddy/buddy_controller.dart';
import 'package:belly_buddy/widgets/buddy/buddy_stage.dart';

import '../../helpers/app_host.dart';
import '../../helpers/layout_checks.dart';

/// The router: /dashboard, with the celebration pushed on top; [alone],
/// the celebration opened directly (a deep link, restored state).
Future<GoRouter> _pump(
  WidgetTester tester, {
  double textScale = 1,
  bool reducedMotion = false,
  Size size = const Size(375, 667),
  bool alone = false,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: alone ? '/patterns-unlocked' : '/dashboard',
    routes: [
      GoRoute(
        path: '/dashboard',
        builder: (_, _) => const Scaffold(body: Text('page:/dashboard')),
      ),
      GoRoute(
        path: '/patterns-unlocked',
        builder: (_, _) => const PatternsUnlockedScreen(),
      ),
      GoRoute(
        path: '/patterns',
        builder: (_, _) => const Scaffold(body: Text('page:/patterns')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      child: MediaQuery(
        data: MediaQueryData(
          size: size,
          disableAnimations: reducedMotion,
          textScaler: TextScaler.linear(textScale),
        ),
        child: germanRouterApp(router),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (!alone) {
    unawaited(router.push('/patterns-unlocked'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }
  return router;
}

String _location(GoRouter r) =>
    r.routerDelegate.currentConfiguration.last.matchedLocation;

BuddyController _controller(WidgetTester tester) =>
    tester.widget<BuddyStage>(find.byType(BuddyStage)).controller;

void main() {
  testWidgets('shows the title, the line and „Muster ansehen"', (tester) async {
    await _pump(tester);
    expect(find.text('Muster frei!'), findsOneWidget);
    expect(find.text(PatternsUnlockedScreen.line), findsOneWidget);
    expect(find.text('Muster ansehen'), findsOneWidget);
    expect(find.byType(AnimatedBuddy), findsOneWidget);
  });

  testWidgets('Muster frei! reads its title, its line and its button', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);
    await tester.pump(const Duration(seconds: 1));
    // The title is not yet a heading node (the shared overlay draws it
    // as plain text, see the XA8 report); it is in the tree and read.
    expect(find.bySemanticsLabel(RegExp('Muster frei!')), findsWidgets);
    expect(
      tester.getSemantics(find.byKey(PatternsUnlockedScreen.openKey)),
      matchesSemantics(
        label: 'Muster ansehen',
        isButton: true,
        isEnabled: true,
        hasEnabledState: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('„Muster ansehen" replaces it with Muster', (tester) async {
    final router = await _pump(tester);
    await tester.tap(find.byKey(PatternsUnlockedScreen.openKey));
    await tester.pumpAndSettle();
    expect(_location(router), '/patterns');
    router.pop();
    await tester.pumpAndSettle();
    expect(_location(router), '/dashboard');
  });

  testWidgets('a tap elsewhere goes back', (tester) async {
    final router = await _pump(tester);
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(_location(router), '/dashboard');
  });

  testWidgets('nothing below: a tap elsewhere goes Home', (tester) async {
    final router = await _pump(tester, alone: true);
    expect(_location(router), '/patterns-unlocked');

    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(_location(router), '/dashboard');
  });

  testWidgets('the Buddy celebrates once', (tester) async {
    await _pump(tester);
    expect(_controller(tester).currentAction, BuddyAction.celebrate);
  });

  testWidgets('reduced motion: the Buddy doesn\'t celebrate', (tester) async {
    await _pump(tester, reducedMotion: true);
    expect(_controller(tester).currentAction, isNull);
  });

  testWidgets('fits 375×667 @1.3', (tester) async {
    final errors = await collectFlutterErrors(() async {
      await _pump(tester, textScale: 1.3);
    });
    expect(verticalOverflows(errors), isEmpty);
    expect(
      tester.getRect(find.byType(AnimatedBuddy)).height,
      greaterThanOrEqualTo(minBuddyHeight),
    );
    final button = tester.getRect(find.byKey(PatternsUnlockedScreen.openKey));
    expect(button.bottom, lessThanOrEqualTo(667));
  });
}
