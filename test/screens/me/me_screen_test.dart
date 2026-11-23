import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/providers/auth_provider.dart';
import 'package:belly_buddy/providers/buddy_provider.dart';
import 'package:belly_buddy/providers/tutorial_provider.dart';
import 'package:belly_buddy/providers/upgrade_gate_provider.dart';
import 'package:belly_buddy/router/route_names.dart';
import 'package:belly_buddy/screens/me/me_screen.dart';
import 'package:belly_buddy/widgets/buddy/animated_buddy.dart';
import 'package:belly_buddy/widgets/buddy/streak_chip.dart';

import '../../helpers/app_host.dart';
import '../../helpers/fakes.dart';

/// The launched URLs and modes.
class _Launches {
  final urls = <Uri>[];
  final modes = <LaunchMode>[];
  bool result = true;

  Future<bool> call(Uri url, {LaunchMode mode = LaunchMode.platformDefault}) {
    urls.add(url);
    modes.add(mode);
    return Future.value(result);
  }
}

BuddyStatus _status({int streak = 3, int? goal = 14, String name = 'Bruno'}) =>
    buddyStatus(name: name, goal: goal, streak: streak, todayCounted: true);

const _renameError = 'Bitte gib einen Namen mit 1 bis 20 Zeichen ein.';

void main() {
  final today = DateTime(2026, 11, 23, 13);
  late _Launches launches;
  late GoRouter router;
  late ProviderContainer container;

  setUp(() => launches = _Launches());

  Future<FakeBuddyNotifier> pump(
    WidgetTester tester, {
    FutureOr<BuddyStatus?> Function()? status,
    bool failRename = false,
    Size size = const Size(393, 852),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final buddy = FakeBuddyNotifier(status ?? _status)..failRename = failRename;
    container = ProviderContainer.test(
      overrides: [
        buddyProvider.overrideWith(() => buddy),
        buddyClockProvider.overrideWithValue(() => today),
        currentUserIdProvider.overrideWithValue('u1'),
        currentVersionProvider.overrideWith((_) async => '1.2.3'),
      ],
    );
    router = GoRouter(
      initialLocation: RoutePaths.me,
      routes: [
        GoRoute(
          path: RoutePaths.me,
          builder: (_, _) => MeScreen(openUrl: launches.call),
        ),
        ...stubRoutes([RoutePaths.settings, RoutePaths.dashboard]),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: germanRouterApp(router, textScale: textScale),
      ),
    );
    await tester.pumpAndSettle();
    return buddy;
  }

  Future<void> tapRow(WidgetTester tester, Key key) async {
    await tester.ensureVisible(find.byKey(key));
    await tester.tap(find.byKey(key));
    await tester.pumpAndSettle();
  }

  Future<void> openRename(WidgetTester tester) async {
    await tester.tap(find.byKey(MeScreen.renameKey));
    await tester.pumpAndSettle();
    expect(find.text('Buddy umbenennen'), findsOneWidget);
  }

  TextButton saveButton(WidgetTester tester) =>
      tester.widget<TextButton>(find.widgetWithText(TextButton, 'Speichern'));

  testWidgets('header shows the Buddy and his name', (tester) async {
    await pump(tester);

    expect(find.byType(AnimatedBuddy), findsOneWidget);
    expect(find.text('Bruno'), findsOneWidget);
    expect(find.byType(StreakChip), findsOneWidget);
    expect(find.byKey(MeScreen.renameKey), findsOneWidget);
    expect(find.text('Umbenennen'), findsOneWidget);
  });

  testWidgets('rows', (tester) async {
    await pump(tester);

    expect(find.text('Streak & Ziel'), findsOneWidget);
    expect(find.text('🔥 3 Tage · Ziel: 14 Tage'), findsOneWidget);
    expect(find.text('Einstellungen'), findsOneWidget);
    expect(find.text('Profil, Benachrichtigungen, Konto'), findsOneWidget);
    expect(find.text('Tutorial wiederholen'), findsOneWidget);
    expect(find.text('Die Tour durch Home nochmal ansehen'), findsOneWidget);
    expect(find.text('Feedback geben'), findsOneWidget);
    expect(find.text('Teile uns deine Ideen und Wünsche mit'), findsOneWidget);
    expect(find.text('Version 1.2.3'), findsOneWidget);
    for (final key in [
      MeScreen.streakKey,
      MeScreen.settingsKey,
      MeScreen.tutorialKey,
      MeScreen.feedbackKey,
    ]) {
      expect(find.byKey(key), findsOneWidget);
    }
  });

  testWidgets('rows: no goal yet, a 1-day streak', (tester) async {
    await pump(tester, status: () => _status(streak: 1, goal: null));

    expect(find.text('🔥 1 Tag · Noch kein Ziel'), findsOneWidget);
  });

  testWidgets('rows: no goal yet', (tester) async {
    await pump(tester, status: () => _status(goal: null));

    expect(find.text('🔥 3 Tage · Noch kein Ziel'), findsOneWidget);
  });

  testWidgets('while the Buddy loads: „Buddy", no streak, no rename', (
    tester,
  ) async {
    await pump(tester, status: () => Completer<BuddyStatus?>().future);

    expect(find.byType(AnimatedBuddy), findsOneWidget);
    expect(find.text('Buddy'), findsOneWidget);
    expect(find.byType(StreakChip), findsNothing);
    expect(find.byKey(MeScreen.renameKey), findsNothing);
    expect(find.byKey(MeScreen.streakKey), findsNothing);
    expect(find.byKey(MeScreen.settingsKey), findsOneWidget);
    expect(find.byKey(MeScreen.feedbackKey), findsOneWidget);
  });

  testWidgets('rename saves a valid name', (tester) async {
    final buddy = await pump(tester);

    await openRename(tester);
    await tester.enterText(find.byType(TextField), '  Pepe ');
    await tester.pump();
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    expect(buddy.names, ['Pepe']);
    expect(find.text('Buddy umbenennen'), findsNothing);
    expect(find.text('Pepe'), findsOneWidget);
    expect(find.text('Bruno'), findsNothing);
  });

  testWidgets('rename rejects empty and too long', (tester) async {
    final buddy = await pump(tester);

    await openRename(tester);
    expect(find.text(_renameError), findsNothing);
    expect(saveButton(tester).onPressed, isNotNull);

    for (final invalid in ['   ', 'a' * 21]) {
      await tester.enterText(find.byType(TextField), invalid);
      await tester.pump();

      expect(find.text(_renameError), findsOneWidget, reason: invalid);
      expect(saveButton(tester).onPressed, isNull, reason: invalid);

      // Neither the button nor the keyboard's done saves it.
      await tester.tap(find.text('Speichern'));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('Buddy umbenennen'), findsOneWidget);
    }

    // 20 characters are fine again.
    await tester.enterText(find.byType(TextField), 'a' * 20);
    await tester.pump();
    expect(find.text(_renameError), findsNothing);
    expect(saveButton(tester).onPressed, isNotNull);

    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(find.text('Buddy umbenennen'), findsNothing);
    expect(buddy.names, isEmpty);
    expect(find.text('Bruno'), findsOneWidget);
  });

  testWidgets('rename to the same name saves nothing', (tester) async {
    final buddy = await pump(tester);

    await openRename(tester);
    await tester.enterText(find.byType(TextField), ' Bruno ');
    await tester.pump();
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    expect(find.text('Buddy umbenennen'), findsNothing);
    expect(buddy.names, isEmpty);
  });

  testWidgets('rename failure', (tester) async {
    final buddy = await pump(tester, failRename: true);

    await openRename(tester);
    await tester.enterText(find.byType(TextField), 'Pepe');
    await tester.pump();
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    expect(buddy.names, ['Pepe']);
    expect(
      find.text('Umbenennen hat nicht geklappt. Versuch es später nochmal.'),
      findsOneWidget,
    );
    expect(find.text('Bruno'), findsOneWidget);
    expect(find.text('Pepe'), findsNothing);
  });

  testWidgets('Einstellungen pushes /settings', (tester) async {
    await pump(tester);

    await tapRow(tester, MeScreen.settingsKey);

    expect(find.text('page:${RoutePaths.settings}'), findsOneWidget);
    expect(router.canPop(), isTrue);
  });

  testWidgets('Streak & Ziel opens „Dein Streak"', (tester) async {
    final buddy = await pump(tester);

    await tapRow(tester, MeScreen.streakKey);

    expect(find.text('Dein Streak'), findsOneWidget);
    expect(find.text('Ziel: 14 Tage'), findsOneWidget);
    expect(buddy.goals, isEmpty);
  });

  testWidgets('the streak chip opens „Dein Streak" too', (tester) async {
    await pump(tester);

    await tester.tap(find.byType(StreakChip));
    await tester.pumpAndSettle();

    expect(find.text('Dein Streak'), findsOneWidget);
  });

  testWidgets('Tutorial wiederholen requests a replay and goes Home', (
    tester,
  ) async {
    await pump(tester);
    expect(container.read(tutorialProvider), isFalse);

    await tapRow(tester, MeScreen.tutorialKey);

    expect(container.read(tutorialProvider), isTrue);
    expect(find.text('page:${RoutePaths.dashboard}'), findsOneWidget);
    expect(router.canPop(), isFalse);
  });

  testWidgets('Feedback opens the form', (tester) async {
    await pump(tester);

    await tapRow(tester, MeScreen.feedbackKey);

    expect(launches.urls, [Uri.parse(AppConstants.feedbackFormUrl)]);
    expect(launches.modes, [LaunchMode.externalApplication]);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('Feedback: a form that does not open says so', (tester) async {
    launches.result = false;
    await pump(tester);

    await tapRow(tester, MeScreen.feedbackKey);

    expect(
      find.text('Das Feedback-Formular konnte nicht geöffnet werden.'),
      findsOneWidget,
    );
  });

  testWidgets('text scale 1.3 on a small phone: no overflow', (tester) async {
    await pump(
      tester,
      status: () => _status(name: 'Wolfgang-Amadeus Bub'),
      size: const Size(375, 667),
      textScale: 1.3,
    );

    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -800));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Version 1.2.3'), findsOneWidget);
  });
}
