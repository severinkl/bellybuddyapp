// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:riverpod/src/internals.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'package:url_launcher/url_launcher.dart';

import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/models/data_share.dart';
import 'package:belly_buddy/models/user_profile.dart';
import 'package:belly_buddy/providers/auth_provider.dart';
import 'package:belly_buddy/providers/buddy_provider.dart';
import 'package:belly_buddy/providers/profile_provider.dart';
import 'package:belly_buddy/providers/rating_provider.dart';
import 'package:belly_buddy/services/share_service.dart';
import 'package:belly_buddy/providers/tutorial_provider.dart';
import 'package:belly_buddy/providers/upgrade_gate_provider.dart';
import 'package:belly_buddy/repositories/notification_repository.dart';
import 'package:belly_buddy/repositories/profile_repository.dart';
import 'package:belly_buddy/router/route_names.dart';
import 'package:belly_buddy/screens/buddy/streak_goal_picker.dart';
import 'package:belly_buddy/screens/dashboard/widgets/streak_sheet.dart';
import 'package:belly_buddy/screens/me/me_screen.dart';
import 'package:belly_buddy/services/app_version_service.dart';
import 'package:belly_buddy/utils/buddy_name.dart';
import 'package:belly_buddy/widgets/buddy/animated_buddy.dart';
import 'package:belly_buddy/widgets/buddy/streak_chip.dart';

import '../../helpers/app_host.dart';
import '../../helpers/fakes.dart';
import '../../helpers/fixtures.dart';
import '../../helpers/riverpod_helpers.dart';
import '../../helpers/share_fakes.dart';

BuddyStatus _status({int streak = 3, int? goal = 14, String name = 'Bruno'}) =>
    buddyStatus(name: name, goal: goal, streak: streak, todayCounted: true);

const _renameError = 'Bitte gib einen Namen mit 1 bis 20 Zeichen ein.';

void main() {
  final today = DateTime(2026, 11, 23, 13);
  late RecordingUrlOpener launches;
  late GoRouter router;
  late ProviderContainer container;
  late FakeShareService shareService;

  setUp(() {
    launches = RecordingUrlOpener();
    shareService = FakeShareService();
    SharedPreferences.setMockInitialValues({});
  });

  Future<FakeBuddyNotifier> pump(
    WidgetTester tester, {
    FutureOr<BuddyStatus?> Function()? status,
    bool failRename = false,
    Size size = const Size(393, 852),
    double textScale = 1,
    FakeViewPadding padding = FakeViewPadding.zero,
    List<Override> extra = const [],
  }) async {
    tester.view.physicalSize = size;
    tester.view.padding = padding;
    addTearDown(tester.view.resetPadding);
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
        shareServiceProvider.overrideWithValue(shareService),
        ...extra,
      ],
    );
    router = GoRouter(
      initialLocation: RoutePaths.me,
      routes: [
        GoRoute(
          path: RoutePaths.me,
          builder: (_, _) => MeScreen(openUrl: launches.call),
        ),
        ...stubRoutes([
          RoutePaths.settings,
          RoutePaths.dashboard,
          RoutePaths.progress,
          RoutePaths.shares,
          RoutePaths.shareCreate,
        ]),
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

  testWidgets(
    'no „Ich" header: the Buddy card starts at the top, below the status bar',
    (tester) async {
      await pump(tester);
      expect(find.byType(AppBar), findsNothing);
      expect(find.text('Ich'), findsNothing);
      expect(
        tester.getRect(find.byType(AnimatedBuddy)).top,
        lessThan(kToolbarHeight),
      );

      await pump(tester, padding: const FakeViewPadding(top: 59));
      expect(
        tester.getRect(find.byType(AnimatedBuddy)).top,
        greaterThanOrEqualTo(59),
      );
    },
  );

  testWidgets('header shows the Buddy and his name', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester);

    expect(find.byType(AnimatedBuddy), findsOneWidget);
    expect(find.text('Bruno'), findsOneWidget);
    // His name is the screen's heading, now that there is no app bar.
    expect(
      tester.getSemantics(find.text('Bruno')),
      isSemantics(label: 'Bruno', isHeader: true),
    );
    handle.dispose();
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
      MeScreen.progressKey,
      MeScreen.shareKey,
      MeScreen.settingsKey,
      MeScreen.tutorialKey,
      MeScreen.rateKey,
      MeScreen.feedbackKey,
    ]) {
      expect(find.byKey(key), findsOneWidget);
    }
  });

  group('„Mit Berater:in teilen"', () {
    testWidgets('sits between Streak & Ziel and Einstellungen', (tester) async {
      await pump(tester);

      expect(find.text('Mit Berater:in teilen'), findsOneWidget);
      expect(
        find.text('Tagebuch für Diätolog:in oder Ärzt:in freigeben'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.person_add_alt_1_outlined), findsOneWidget);
      final streak = tester.getTopLeft(find.byKey(MeScreen.streakKey)).dy;
      final share = tester.getTopLeft(find.byKey(MeScreen.shareKey)).dy;
      final settings = tester.getTopLeft(find.byKey(MeScreen.settingsKey)).dy;
      expect(streak, lessThan(share));
      expect(share, lessThan(settings));
    });

    testWidgets('„Neu" until the row was tapped once', (tester) async {
      await pump(tester);
      expect(find.text('Neu'), findsOneWidget);

      await tapRow(tester, MeScreen.shareKey);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('Neu'), findsNothing);

      // Remembered on the device: a fresh screen has no badge either.
      await pump(tester);
      expect(find.text('Neu'), findsNothing);
    });

    testWidgets('no shares: opens the create screen', (tester) async {
      await pump(tester);
      await tapRow(tester, MeScreen.shareKey);
      expect(find.text('page:/shares/new'), findsOneWidget);
      // The list lies beneath the create screen.
      expect(find.text('page:/shares', skipOffstage: false), findsOneWidget);
    });

    testWidgets('with shares: opens the list', (tester) async {
      shareService.shares = [testShare()];
      await pump(tester);
      await tapRow(tester, MeScreen.shareKey);
      expect(find.text('page:/shares'), findsOneWidget);
    });

    testWidgets('a double tap opens the list once', (tester) async {
      shareService.shares = [testShare()];
      await pump(tester);
      await tester.ensureVisible(find.byKey(MeScreen.shareKey));
      await tester.tap(find.byKey(MeScreen.shareKey));
      await tester.tap(find.byKey(MeScreen.shareKey));
      await tester.pumpAndSettle();
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('page:/shares'), findsNothing);
      expect(find.byKey(MeScreen.shareKey), findsOneWidget);
    });

    testWidgets('after leaving the list by go, the row opens it again', (
      tester,
    ) async {
      shareService.shares = [testShare()];
      await pump(tester);
      await tapRow(tester, MeScreen.shareKey);
      expect(find.text('page:/shares'), findsOneWidget);
      // A deep link or a tab switch replaces the stack: the push never
      // completes.
      router.go(RoutePaths.me);
      await tester.pumpAndSettle();
      await tapRow(tester, MeScreen.shareKey);
      expect(find.text('page:/shares'), findsOneWidget);
    });

    testWidgets('failed list: opens the create screen', (tester) async {
      shareService.failList = true;
      await pump(tester);
      await tapRow(tester, MeScreen.shareKey);
      expect(find.text('page:/shares/new'), findsOneWidget);
      expect(find.text('page:/shares', skipOffstage: false), findsOneWidget);
    });

    testWidgets('while the list loads: shown and tappable', (tester) async {
      shareService = _NeverLoads();
      await pump(tester);
      expect(find.byKey(MeScreen.shareKey), findsOneWidget);
      await tapRow(tester, MeScreen.shareKey);
      expect(find.text('page:/shares/new'), findsOneWidget);
      expect(find.text('page:/shares', skipOffstage: false), findsOneWidget);
    });
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
    // „Dein Verlauf" does not need a Buddy status.
    expect(find.byKey(MeScreen.progressKey), findsOneWidget);
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

  testWidgets('rename rejects empty and caps the length', (tester) async {
    final buddy = await pump(tester);

    await openRename(tester);
    expect(find.text(_renameError), findsNothing);
    expect(saveButton(tester).onPressed, isNotNull);

    // Empty is rejected with the error.
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(find.text(_renameError), findsOneWidget);
    expect(saveButton(tester).onPressed, isNull);

    // Neither the button nor the keyboard's done saves it.
    await tester.tap(find.text('Speichern'));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('Buddy umbenennen'), findsOneWidget);

    // Like in the registration, a 21st character is not taken at all.
    await tester.enterText(find.byType(TextField), 'a' * 21);
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'a' * 20,
    );
    expect(find.text('20/20'), findsOneWidget);
    expect(find.text(_renameError), findsNothing);

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

  testWidgets('rename counts the characters a person sees', (tester) async {
    await pump(tester);

    await openRename(tester);
    const heart = '\u2764\uFE0F';
    await tester.enterText(find.byType(TextField), 'Kiwi ${heart * 7}');
    await tester.pump();

    expect(find.text('12/20'), findsOneWidget);
    expect(find.text(_renameError), findsNothing);
    expect(saveButton(tester).onPressed, isNotNull);
  });

  testWidgets('rename saves 20 hearts', (tester) async {
    final buddy = await pump(tester);

    await openRename(tester);
    final hearts = '\u2764\uFE0F' * 20;
    await tester.enterText(find.byType(TextField), hearts);
    await tester.pump();
    expect(find.text(_renameError), findsNothing);
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    expect(buddy.names, [hearts]);
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

  testWidgets('rename refused by a database counting fewer symbols says '
      'so', (tester) async {
    // Refused as a check counting fewer code points than the app would.
    final hearts = '\u2764\uFE0F' * 10;
    final buddy = await pump(tester);
    buddy.renameError = const PostgrestException(
      message:
          'new row for relation "buddy_state" violates check constraint '
          '"buddy_state_name_check"',
      code: '23514',
    );

    await openRename(tester);
    await tester.enterText(find.byType(TextField), hearts);
    await tester.pump();
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    expect(buddy.names, [hearts]);
    expect(find.text(BuddyNameRules.tooManySymbols), findsOneWidget);
    expect(
      find.text('Umbenennen hat nicht geklappt. Versuch es später nochmal.'),
      findsNothing,
    );
    expect(find.text('Bruno'), findsOneWidget);
  });

  testWidgets('rename refused by another check keeps the general message', (
    tester,
  ) async {
    final buddy = await pump(tester);
    buddy.renameError = const PostgrestException(
      message:
          'new row for relation "buddy_state" violates check constraint '
          '"buddy_state_savers_check"',
      code: '23514',
    );

    await openRename(tester);
    await tester.enterText(find.byType(TextField), 'Pepe');
    await tester.pump();
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    expect(find.text(BuddyNameRules.tooManySymbols), findsNothing);
    expect(
      find.text('Umbenennen hat nicht geklappt. Versuch es später nochmal.'),
      findsOneWidget,
    );
  });

  testWidgets('Einstellungen pushes /settings', (tester) async {
    await pump(tester);

    await tapRow(tester, MeScreen.settingsKey);

    expect(find.text('page:${RoutePaths.settings}'), findsOneWidget);
    expect(router.canPop(), isTrue);
  });

  testWidgets('„Dein Verlauf" after „Streak & Ziel" pushes /progress', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Dein Verlauf'), findsOneWidget);
    expect(find.text('Wie es dir über die Wochen geht'), findsOneWidget);
    double top(Key key) => tester.getTopLeft(find.byKey(key)).dy;
    expect(top(MeScreen.progressKey), greaterThan(top(MeScreen.streakKey)));
    expect(top(MeScreen.progressKey), lessThan(top(MeScreen.settingsKey)));

    await tapRow(tester, MeScreen.progressKey);

    expect(find.text('page:${RoutePaths.progress}'), findsOneWidget);
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

  testWidgets('while a chosen goal saves, „Dein Streak" does not open '
      'again', (tester) async {
    final buddy = await pump(tester);
    final save = Completer<void>();
    buddy.goalSave = save.future;

    await tapRow(tester, MeScreen.streakKey);
    await tester.ensureVisible(find.byKey(StreakSheet.changeGoalKey));
    await tester.tap(find.byKey(StreakSheet.changeGoalKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('30 Tage'));
    await tester.pump();
    await tester.tap(find.byKey(StreakGoalChooser.confirmKey));
    await tester.pumpAndSettle();
    expect(find.byType(StreakSheet), findsNothing);

    await tester.ensureVisible(find.byType(StreakChip));
    await tester.tap(find.byType(StreakChip));
    await tester.pumpAndSettle();
    expect(find.byType(StreakSheet), findsNothing);

    save.complete();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(StreakChip));
    await tester.tap(find.byType(StreakChip));
    await tester.pumpAndSettle();
    expect(find.byType(StreakSheet), findsOneWidget);
    expect(buddy.goals, [30]);
  });

  testWidgets('while a new name saves, Umbenennen does not open again', (
    tester,
  ) async {
    final buddy = await pump(tester);
    final save = Completer<void>();
    buddy.nameSave = save.future;

    await openRename(tester);
    await tester.enterText(find.byType(TextField), 'Pepe');
    await tester.pump();
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(find.text('Buddy umbenennen'), findsNothing);

    await tester.tap(find.byKey(MeScreen.renameKey));
    await tester.pumpAndSettle();
    expect(find.text('Buddy umbenennen'), findsNothing);

    save.complete();
    await tester.pumpAndSettle();
    await openRename(tester);
    expect(buddy.names, ['Pepe']);
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

  group('Belly Buddy bewerten', () {
    testWidgets('the row sits directly above „Feedback geben" with its title '
        'and subtitle', (tester) async {
      await pump(tester);

      expect(find.text('Belly Buddy bewerten'), findsOneWidget);
      expect(find.text('Sag anderen, wie dir die App gefällt'), findsOneWidget);
      final rate = tester.getRect(find.byKey(MeScreen.rateKey));
      final feedback = tester.getRect(find.byKey(MeScreen.feedbackKey));
      final tutorial = tester.getRect(find.byKey(MeScreen.tutorialKey));
      expect(rate.top, greaterThan(tutorial.bottom));
      expect(rate.bottom, lessThan(feedback.top));
      expect(feedback.top - rate.bottom, lessThan(AppConstants.spacingLg));
    });

    testWidgets('two quick taps open the store listing once', (tester) async {
      final launcher = FakeRatingLauncher()..listingHold = Completer();
      await pump(
        tester,
        extra: [
          ratingLauncherProvider.overrideWithValue(launcher),
          appVersionServiceProvider.overrideWithValue(FakeAppVersionService()),
        ],
      );
      await tester.ensureVisible(find.byKey(MeScreen.rateKey));
      await tester.tap(find.byKey(MeScreen.rateKey));
      await tester.pump();
      await tester.tap(find.byKey(MeScreen.rateKey));
      await tester.pump();
      launcher.listingHold!.complete();
      await tester.pumpAndSettle();

      expect(launcher.listings, 1);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('tap opens the store listing through the launcher', (
      tester,
    ) async {
      final launcher = FakeRatingLauncher();
      final version = FakeAppVersionService();
      await pump(
        tester,
        extra: [
          ratingLauncherProvider.overrideWithValue(launcher),
          appVersionServiceProvider.overrideWithValue(version),
        ],
      );

      await tapRow(tester, MeScreen.rateKey);

      expect(launcher.listings, 1);
      expect(version.opened, 0);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('listing fails: the store page opens through '
        'AppVersionService', (tester) async {
      final launcher = FakeRatingLauncher(listingThrows: true);
      final version = FakeAppVersionService();
      await pump(
        tester,
        extra: [
          ratingLauncherProvider.overrideWithValue(launcher),
          appVersionServiceProvider.overrideWithValue(version),
        ],
      );

      await tapRow(tester, MeScreen.rateKey);

      expect(launcher.listings, 1);
      expect(version.opened, 1);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('both fail: „Der Store konnte nicht geöffnet werden." is '
        'shown', (tester) async {
      await pump(
        tester,
        extra: [
          ratingLauncherProvider.overrideWithValue(
            FakeRatingLauncher(listingThrows: true),
          ),
          appVersionServiceProvider.overrideWithValue(
            FakeAppVersionService(openStoreThrows: true),
          ),
        ],
      );

      await tapRow(tester, MeScreen.rateKey);

      expect(
        find.text('Der Store konnte nicht geöffnet werden.'),
        findsOneWidget,
      );
    });

    testWidgets('listing fails and the store page does not launch (false): '
        'the message is shown', (tester) async {
      await pump(
        tester,
        extra: [
          ratingLauncherProvider.overrideWithValue(
            FakeRatingLauncher(listingThrows: true),
          ),
          appVersionServiceProvider.overrideWithValue(
            FakeAppVersionService(openStoreResult: false),
          ),
        ],
      );

      await tapRow(tester, MeScreen.rateKey);

      expect(
        find.text('Der Store konnte nicht geöffnet werden.'),
        findsOneWidget,
      );
    });

    testWidgets('tapping does not record a rating request', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await pump(
        tester,
        extra: [
          ratingLauncherProvider.overrideWithValue(FakeRatingLauncher()),
          appVersionServiceProvider.overrideWithValue(FakeAppVersionService()),
        ],
      );

      await tapRow(tester, MeScreen.rateKey);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getKeys().where((k) => k.startsWith('rating_asked_')),
        isEmpty,
      );
    });
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

  group('„Erinnerungen sind aus"', () {
    late FakeNotificationRepository os;

    setUp(() {
      os = FakeNotificationRepository();
      SharedPreferences.setMockInitialValues({});
    });

    /// Ich with [profile] loaded and the OS as [os] reports it.
    Future<void> pumpWith(WidgetTester tester, UserProfile profile) => pump(
      tester,
      extra: [
        notificationRepositoryProvider.overrideWithValue(os),
        profileRepositoryProvider.overrideWithValue(
          FakeProfileRepository()..seedProfile(profile),
        ),
        profileProviderSeededWith(profile),
      ],
    );

    Finder row() => find.byKey(MeScreen.remindersKey);

    testWidgets('shows while they are off in the app; „Einschalten" asks the '
        'OS and the row goes once they are on', (tester) async {
      os.permission = NotificationPermission.notDetermined;
      await pumpWith(tester, testUserProfile().withNotifications(false));

      expect(row(), findsOneWidget);
      expect(
        find.descendant(
          of: row(),
          matching: find.text('Erinnerungen sind aus'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row(), matching: find.text('Einschalten')),
        findsOneWidget,
      );

      await tapRow(tester, MeScreen.remindersKey);
      expect(os.requests, 1);
      expect(container.read(profileProvider).value!.anyNotificationOn, isTrue);
      expect(row(), findsNothing);
    });

    testWidgets('shows while the OS doesn\'t allow them; denied for good, '
        '„Einschalten" opens the system settings', (tester) async {
      os.permission = NotificationPermission.denied;
      await pumpWith(tester, testUserProfile().withNotifications(true));

      expect(row(), findsOneWidget);
      await tapRow(tester, MeScreen.remindersKey);
      expect(os.settingsOpened, 1);
      expect(os.requests, 0);
    });

    testWidgets('hidden while they are on', (tester) async {
      await pumpWith(tester, testUserProfile().withNotifications(true));
      expect(row(), findsNothing);
      expect(find.text('Erinnerungen sind aus'), findsNothing);
    });

    testWidgets('hidden while no profile is loaded', (tester) async {
      await pump(tester);
      expect(row(), findsNothing);
    });
  });
}

class _NeverLoads extends FakeShareService {
  @override
  Future<List<DataShare>> list() => Completer<List<DataShare>>().future;
}
