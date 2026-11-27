// ignore_for_file: invalid_use_of_internal_member
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/src/internals.dart' show Override;
import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/models/user_profile.dart';
import 'package:belly_buddy/screens/settings/widgets/settings_notifications_screen.dart';
import 'package:belly_buddy/providers/buddy_provider.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/profile_provider.dart';
import 'package:belly_buddy/repositories/notification_repository.dart';
import 'package:belly_buddy/repositories/profile_repository.dart';

import 'package:belly_buddy/widgets/common/weekly_tips_switch.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/app_lifecycle.dart';
import '../../helpers/fakes.dart';
import '../../helpers/fixtures.dart';
import '../../helpers/riverpod_helpers.dart';

List<Override> _overrides() {
  final profile = testUserProfile(remindersEnabled: true);
  final fakeRepo = FakeProfileRepository()..seedProfile(profile);
  return [
    profileRepositoryProvider.overrideWithValue(fakeRepo),
    notificationRepositoryProvider.overrideWithValue(
      FakeNotificationRepository(),
    ),
    currentUserIdProvider.overrideWithValue('test-user'),
    profileProviderSeededWith(profile),
  ];
}

/// The OS side: [permission] as the OS reports it; a request shows the
/// system dialog only while it was never asked ([grant] is the answer).
class _OsNotifications extends FakeNotificationRepository {
  _OsNotifications(NotificationPermission initial, {bool grant = true}) {
    permission = initial;
    grantOnRequest = grant;
  }

  @override
  Future<bool> requestPermission() => requestAllPermissions();
}

void main() {
  group('SettingsNotificationsScreen reflects what can arrive', () {
    late ProviderContainer container;
    late _OsNotifications os;

    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<void> pump(
      WidgetTester tester, {
      required NotificationPermission permission,
      bool grant = true,
      UserProfile? profile,
    }) async {
      os = _OsNotifications(permission, grant: grant);
      final seeded = profile ?? testUserProfile();
      final repo = FakeProfileRepository()..seedProfile(seeded);
      container = ProviderContainer.test(
        overrides: [
          profileRepositoryProvider.overrideWithValue(repo),
          notificationRepositoryProvider.overrideWithValue(os),
          currentUserIdProvider.overrideWithValue('test-user'),
          buddyClockProvider.overrideWithValue(() => DateTime(2026, 11, 26, 9)),
          profileProviderSeededWith(seeded),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SettingsNotificationsScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    bool switchOn(WidgetTester tester, String title) => tester
        .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, title))
        .value;

    UserProfile stored() => container.read(profileProvider).value!;

    testWidgets('the weekly switch works without notification permission', (
      tester,
    ) async {
      await pump(tester, permission: NotificationPermission.notDetermined);

      expect(
        find.ancestor(
          of: find.byKey(WeeklyTipsSwitch.switchKey),
          matching: find.byWidgetPredicate(
            (w) => w is IgnorePointer && w.ignoring,
          ),
        ),
        findsNothing,
      );
      await tester.ensureVisible(find.byKey(WeeklyTipsSwitch.switchKey));
      await tester.tap(find.byKey(WeeklyTipsSwitch.switchKey));
      await tester.pumpAndSettle();

      expect(stored().weeklyTipsEnabled, isTrue);
    });

    testWidgets('a reminder time saved after the weekly switch keeps it on', (
      tester,
    ) async {
      await pump(
        tester,
        permission: NotificationPermission.granted,
        profile: testUserProfile(mealReminderTimes: ['08:00', '18:00']),
      );

      // Removing 08:00 arms the debounced save with the profile as it is.
      await tester.tap(
        find.descendant(
          of: find.ancestor(
            of: find.text('08:00'),
            matching: find.byType(GestureDetector),
          ),
          matching: find.byIcon(Icons.close),
        ),
      );
      await tester.ensureVisible(find.byKey(WeeklyTipsSwitch.switchKey));
      await tester.tap(find.byKey(WeeklyTipsSwitch.switchKey));
      await tester.pump();
      await tester.pumpAndSettle(AppConstants.debounceDuration);

      expect(stored().mealReminderTimes, ['18:00']);
      expect(stored().weeklyTipsEnabled, isTrue);
      expect(switchOn(tester, WeeklyTipsSwitch.title), isTrue);
    });

    testWidgets('Tipps per Push is greyed without permission', (tester) async {
      await pump(tester, permission: NotificationPermission.notDetermined);

      expect(
        find.ancestor(
          of: find.widgetWithText(SwitchListTile, 'Tipps per Push'),
          matching: find.byWidgetPredicate(
            (w) => w is IgnorePointer && w.ignoring,
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('never asked: everything shows off although the profile '
        'still says on', (tester) async {
      await pump(tester, permission: NotificationPermission.notDetermined);

      expect(switchOn(tester, 'Benachrichtigungen erlauben'), isFalse);
      expect(switchOn(tester, 'Mahlzeiten'), isFalse);
      expect(switchOn(tester, 'Bauchgefühl'), isFalse);
      expect(switchOn(tester, 'Tipps per Push'), isFalse);
      // No reminder times offered for reminders that cannot arrive.
      expect(find.text('18:00'), findsNothing);
      expect(os.requests, 0);
    });

    testWidgets('turning it on asks the OS once; allowed, every reminder is '
        'on', (tester) async {
      await pump(
        tester,
        permission: NotificationPermission.notDetermined,
        profile: testUserProfile(
          remindersEnabled: false,
          dailySummaryEnabled: false,
        ),
      );

      await tester.tap(find.text('Benachrichtigungen erlauben'));
      await tester.pumpAndSettle();

      expect(os.requests, 1);
      expect(switchOn(tester, 'Benachrichtigungen erlauben'), isTrue);
      expect(switchOn(tester, 'Mahlzeiten'), isTrue);
      expect(switchOn(tester, 'Bauchgefühl'), isTrue);
      expect(switchOn(tester, 'Tipps per Push'), isTrue);
      expect(stored().remindersEnabled, isTrue);
      expect(stored().dailySummaryEnabled, isTrue);
      expect(stored().pushEnabled, isTrue);
    });

    testWidgets('declined for good: stays off and offers the Settings app', (
      tester,
    ) async {
      await pump(
        tester,
        permission: NotificationPermission.denied,
        profile: testUserProfile(
          remindersEnabled: false,
          dailySummaryEnabled: false,
        ),
      );
      expect(find.text('Einstellungen öffnen'), findsNothing);

      await tester.tap(find.text('Benachrichtigungen erlauben'));
      await tester.pumpAndSettle();

      expect(switchOn(tester, 'Benachrichtigungen erlauben'), isFalse);
      expect(stored().remindersEnabled, isFalse);
      expect(
        find.textContaining('in den Einstellungen deines Geräts'),
        findsOneWidget,
      );
      await tester.tap(find.text('Einstellungen öffnen'));
      await tester.pumpAndSettle();
      // The system notification settings, on iOS and Android alike.
      expect(os.settingsOpened, 1);

      // Allowed in the Settings app, back in the app: the reminders the
      // user asked for are on.
      os.permission = NotificationPermission.granted;
      returnFromBackground();
      await tester.pumpAndSettle();
      expect(switchOn(tester, 'Benachrichtigungen erlauben'), isTrue);
      expect(stored().remindersEnabled, isTrue);
      expect(find.text('Einstellungen öffnen'), findsNothing);
    });

    testWidgets('allowed and on: the switches show the profile', (
      tester,
    ) async {
      await pump(
        tester,
        permission: NotificationPermission.granted,
        profile: testUserProfile(dailySummaryEnabled: false),
      );

      expect(switchOn(tester, 'Benachrichtigungen erlauben'), isTrue);
      expect(switchOn(tester, 'Mahlzeiten'), isTrue);
      expect(switchOn(tester, 'Bauchgefühl'), isFalse);
      expect(find.text('18:00'), findsOneWidget);
    });

    testWidgets('turned off in the OS later: shows off and says where to '
        'turn it back on', (tester) async {
      await pump(tester, permission: NotificationPermission.denied);

      expect(switchOn(tester, 'Benachrichtigungen erlauben'), isFalse);
      expect(switchOn(tester, 'Mahlzeiten'), isFalse);
      expect(find.text('Einstellungen öffnen'), findsOneWidget);
    });

    testWidgets('the system settings don\'t open: a SnackBar says so', (
      tester,
    ) async {
      await pump(tester, permission: NotificationPermission.denied);
      os.settingsOpen = false;

      await tester.tap(find.text('Einstellungen öffnen'));
      await tester.pumpAndSettle();
      expect(
        find.text('Die Einstellungen konnten nicht geöffnet werden.'),
        findsOneWidget,
      );
    });

    Future<String?> lastAskDay() async =>
        (await SharedPreferences.getInstance()).getString(
          '${AppConstants.keyReminderAskedOnPrefix}test-user',
        );

    testWidgets('switched off here: the Buddy doesn\'t ask again for a '
        'week (today is stored as his last ask)', (tester) async {
      await pump(tester, permission: NotificationPermission.granted);

      await tester.tap(find.text('Benachrichtigungen erlauben'));
      await tester.pumpAndSettle();
      expect(await lastAskDay(), '2026-11-26');
    });

    testWidgets('the last reminder switched off one by one: the same', (
      tester,
    ) async {
      await pump(
        tester,
        permission: NotificationPermission.granted,
        profile: testUserProfile(dailySummaryEnabled: false),
      );

      await tester.tap(find.text('Mahlzeiten'));
      await tester.pumpAndSettle();
      expect(stored().anyNotificationOn, isFalse);
      expect(await lastAskDay(), '2026-11-26');
    });

    testWidgets('one of several switched off: nothing stored', (tester) async {
      await pump(tester, permission: NotificationPermission.granted);

      await tester.tap(find.text('Mahlzeiten'));
      await tester.pumpAndSettle();
      expect(stored().anyNotificationOn, isTrue);
      expect(await lastAskDay(), isNull);
    });

    testWidgets('turning it off turns every reminder off', (tester) async {
      await pump(
        tester,
        permission: NotificationPermission.granted,
        profile: testUserProfile(pushEnabled: true),
      );

      await tester.tap(find.text('Benachrichtigungen erlauben'));
      await tester.pumpAndSettle();

      expect(switchOn(tester, 'Benachrichtigungen erlauben'), isFalse);
      expect(stored().remindersEnabled, isFalse);
      expect(stored().dailySummaryEnabled, isFalse);
      expect(stored().pushEnabled, isFalse);
    });

    // --- Tagesrückblick ---

    Finder reviewTimeRow() => find.byKey(
      SettingsNotificationsScreen.dailyReviewTimeKey,
      skipOffstage: false,
    );

    /// Opens the time picker from „Ab", types [hour]:[minute] in its input
    /// mode and confirms.
    Future<void> pickTime(WidgetTester tester, int hour, int minute) async {
      // A phone in portrait: the picker's input mode fits.
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpAndSettle();
      await tester.ensureVisible(reviewTimeRow());
      await tester.tap(reviewTimeRow());
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.keyboard_outlined));
      await tester.pumpAndSettle();
      final fields = find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(fields.at(0), '$hour'.padLeft(2, '0'));
      await tester.enterText(fields.at(1), '$minute'.padLeft(2, '0'));
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
    }

    testWidgets('settings: section shows „Ab 19:30"; picking 21:15 stores '
        '"21:15"; picking 09:00 stores "16:00"', (tester) async {
      await pump(tester, permission: NotificationPermission.granted);

      expect(find.text('Tagesrückblick'), findsOneWidget);
      expect(find.byIcon(Icons.nightlight_outlined), findsOneWidget);
      expect(
        find.descendant(of: reviewTimeRow(), matching: find.text('Ab')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: reviewTimeRow(), matching: find.text('19:30')),
        findsOneWidget,
      );
      expect(
        find.text(
          'Ab dieser Uhrzeit zeigt dir Home deinen Rückblick auf den '
          'Tag.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Ich sag dir Bescheid, wenn er da ist – nur an Tagen mit '
          'eingetragener Mahlzeit.',
        ),
        findsOneWidget,
      );

      await pickTime(tester, 21, 15);
      expect(stored().dailyReviewTime, '21:15');
      expect(
        find.descendant(of: reviewTimeRow(), matching: find.text('21:15')),
        findsOneWidget,
      );

      await pickTime(tester, 9, 0);
      expect(stored().dailyReviewTime, '16:00');
      expect(
        find.descendant(of: reviewTimeRow(), matching: find.text('16:00')),
        findsOneWidget,
      );
    });

    testWidgets('settings: the switch is greyed while notifications are not '
        'allowed; the time row is not', (tester) async {
      await pump(
        tester,
        permission: NotificationPermission.notDetermined,
        profile: testUserProfile(dailyReviewReminder: true),
      );

      Finder ignoring(Finder of) => find.ancestor(
        of: of,
        matching: find.byWidgetPredicate(
          (w) => w is IgnorePointer && w.ignoring,
        ),
      );
      expect(
        ignoring(find.widgetWithText(SwitchListTile, 'Erinnerung am Abend')),
        findsOneWidget,
      );
      expect(switchOn(tester, 'Erinnerung am Abend'), isFalse);
      expect(ignoring(reviewTimeRow()), findsNothing);

      await pickTime(tester, 20, 0);
      expect(stored().dailyReviewTime, '20:00');
    });

    testWidgets('settings: the switch turns the evening notice on and off', (
      tester,
    ) async {
      await pump(tester, permission: NotificationPermission.granted);
      expect(switchOn(tester, 'Erinnerung am Abend'), isFalse);

      await tester.ensureVisible(find.text('Erinnerung am Abend'));
      await tester.tap(find.text('Erinnerung am Abend'));
      await tester.pumpAndSettle();
      expect(stored().dailyReviewReminder, isTrue);
      expect(switchOn(tester, 'Erinnerung am Abend'), isTrue);

      await tester.tap(find.text('Erinnerung am Abend'));
      await tester.pumpAndSettle();
      expect(stored().dailyReviewReminder, isFalse);
    });

    testWidgets('settings: turning the master switch on leaves „Erinnerung am '
        'Abend" off', (tester) async {
      await pump(
        tester,
        permission: NotificationPermission.notDetermined,
        profile: testUserProfile(
          remindersEnabled: false,
          dailySummaryEnabled: false,
        ),
      );

      await tester.tap(find.text('Benachrichtigungen erlauben'));
      await tester.pumpAndSettle();

      expect(switchOn(tester, 'Mahlzeiten'), isTrue);
      expect(switchOn(tester, 'Erinnerung am Abend'), isFalse);
      expect(stored().dailyReviewReminder, isFalse);
    });
  });

  group('SettingsNotificationsScreen', () {
    testWidgets('renders Benachrichtigungen app bar title', (tester) async {
      await tester.pumpWithProviders(
        const SettingsNotificationsScreen(),
        overrides: _overrides(),
      );
      await tester.pump();

      expect(find.text('Benachrichtigungen'), findsAtLeast(1));
    });

    testWidgets('renders master permission toggle', (tester) async {
      await tester.pumpWithProviders(
        const SettingsNotificationsScreen(),
        overrides: _overrides(),
      );
      await tester.pump();

      expect(find.text('Benachrichtigungen erlauben'), findsOneWidget);
    });

    testWidgets('renders Erinnerungen row', (tester) async {
      await tester.pumpWithProviders(
        const SettingsNotificationsScreen(),
        overrides: _overrides(),
      );
      await tester.pump();

      expect(find.text('Erinnerungen'), findsAtLeast(1));
    });

    testWidgets('renders Mahlzeiten and Bauchgefühl toggles', (tester) async {
      await tester.pumpWithProviders(
        const SettingsNotificationsScreen(),
        overrides: _overrides(),
      );
      await tester.pump();

      expect(find.text('Mahlzeiten'), findsOneWidget);
      expect(find.text('Bauchgefühl'), findsOneWidget);
    });

    testWidgets('renders Tipps section', (tester) async {
      await tester.pumpWithProviders(
        const SettingsNotificationsScreen(),
        overrides: _overrides(),
      );
      await tester.pump();

      expect(find.text('Tipps'), findsAtLeast(1));
    });

    testWidgets('renders SwitchListTiles for all toggles', (tester) async {
      await tester.pumpWithProviders(
        const SettingsNotificationsScreen(),
        overrides: _overrides(),
      );
      await tester.pump();

      // Master toggle + 4 notification toggles + the weekly tips = 6
      expect(
        find.byType(SwitchListTile, skipOffstage: false),
        findsNWidgets(6),
      );
    });
  });
}
