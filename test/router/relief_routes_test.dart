// ignore_for_file: invalid_use_of_internal_member
import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/providers/relief_provider.dart';
import 'package:belly_buddy/router/app_router.dart';
import 'package:belly_buddy/router/route_names.dart';
import 'package:belly_buddy/screens/relief/relief_list_screen.dart';
import 'package:belly_buddy/screens/relief/relief_player_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:riverpod/src/internals.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/app_host.dart';

String _path(ProviderContainer c) =>
    c.read(routerProvider).routerDelegate.currentConfiguration.uri.path;

Future<ProviderContainer> _pump(WidgetTester tester, {required bool on}) async {
  final container = ProviderContainer.test(
    overrides: <Override>[
      ...baseOverrides(),
      reliefEnabledProvider.overrideWithValue(on),
      reliefReviewMarkersProvider.overrideWithValue(false),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const AppTestHost()),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      AppConstants.keyNotificationModalShown: true,
    });
  });

  testWidgets('gate off sends /relief to /discover', (tester) async {
    final container = await _pump(tester, on: false);
    container.read(routerProvider).go(RoutePaths.relief);
    await tester.pumpAndSettle();
    expect(_path(container), RoutePaths.discover);
    expect(find.byType(ReliefListScreen), findsNothing);
  });

  testWidgets('gate off sends a player link to /discover', (tester) async {
    final container = await _pump(tester, on: false);
    container.read(routerProvider).go(RoutePaths.reliefExerciseFor('waerme'));
    await tester.pumpAndSettle();
    expect(_path(container), RoutePaths.discover);
  });

  testWidgets('gate on sends an unknown id to /relief', (tester) async {
    final container = await _pump(tester, on: true);
    container.read(routerProvider).go(RoutePaths.reliefExerciseFor('unknown'));
    await tester.pumpAndSettle();
    expect(_path(container), RoutePaths.relief);
    expect(find.byType(ReliefListScreen), findsOneWidget);
  });

  testWidgets('a known id opens the player', (tester) async {
    final container = await _pump(tester, on: true);
    container.read(routerProvider).go(RoutePaths.reliefExerciseFor('waerme'));
    await tester.pumpAndSettle();
    expect(find.byType(ReliefPlayerScreen), findsOneWidget);
  });

  testWidgets('closing a deep-linked player goes to the list', (tester) async {
    final container = await _pump(tester, on: true);
    container.read(routerProvider).go(RoutePaths.reliefExerciseFor('waerme'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(_path(container), RoutePaths.relief);
    expect(find.byType(ReliefListScreen), findsOneWidget);
  });
}
