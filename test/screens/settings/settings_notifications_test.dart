// ignore_for_file: invalid_use_of_internal_member
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/src/internals.dart' show Override;
import 'package:belly_buddy/models/user_profile.dart';
import 'package:belly_buddy/screens/settings/widgets/settings_notifications_screen.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/profile_provider.dart';
import 'package:belly_buddy/repositories/notification_repository.dart';
import 'package:belly_buddy/repositories/profile_repository.dart';

import 'package:belly_buddy/widgets/common/weekly_tips_switch.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../helpers/fakes.dart';
import '../../helpers/fixtures.dart';
import '../../helpers/riverpod_helpers.dart';

/// A ProfileNotifier that immediately provides a seeded profile.
class _SeededProfileNotifier extends ProfileNotifier {
  _SeededProfileNotifier(this._profile);
  final UserProfile _profile;

  @override
  AsyncValue<UserProfile?> build() => AsyncValue.data(_profile);
}

List<Override> _overrides() {
  final profile = testUserProfile(remindersEnabled: true);
  final fakeRepo = FakeProfileRepository()..seedProfile(profile);
  return [
    profileRepositoryProvider.overrideWithValue(fakeRepo),
    notificationRepositoryProvider.overrideWithValue(
      FakeNotificationRepository(),
    ),
    currentUserIdProvider.overrideWithValue('test-user'),
    profileProvider.overrideWith(() => _SeededProfileNotifier(profile)),
  ];
}

/// The OS side: [permission] as the OS reports it; a request shows the
/// system dialog only while it was never asked ([grant] is the answer).
class _OsNotifications extends FakeNotificationRepository {
  _OsNotifications(NotificationPermission initial, {this.grant = true}) {
    permission = initial;
  }

  bool grant;
  int requests = 0;

  @override
  Future<bool> requestAllPermissions() async {
    requests++;
    if (permission == NotificationPermission.notDetermined) {
      permission = grant
          ? NotificationPermission.granted
          : NotificationPermission.denied;
    }
    return permission == NotificationPermission.granted;
  }

  @override
  Future<bool> requestPermission() => requestAllPermissions();
}

void main() {
  group('SettingsNotificationsScreen reflects what can arrive', () {
    late ProviderContainer container;
    late _OsNotifications os;
    late List<Uri> opened;

    Future<void> pump(
      WidgetTester tester, {
      required NotificationPermission permission,
      bool grant = true,
      UserProfile? profile,
    }) async {
      os = _OsNotifications(permission, grant: grant);
      opened = [];
      final seeded = profile ?? testUserProfile();
      final repo = FakeProfileRepository()..seedProfile(seeded);
      container = ProviderContainer.test(
        overrides: [
          profileRepositoryProvider.overrideWithValue(repo),
          notificationRepositoryProvider.overrideWithValue(os),
          currentUserIdProvider.overrideWithValue('test-user'),
          profileProvider.overrideWith(() => _SeededProfileNotifier(seeded)),
        ],
      );
      Future<bool> open(
        Uri url, {
        LaunchMode mode = LaunchMode.platformDefault,
      }) async {
        opened.add(url);
        return true;
      }

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: SettingsNotificationsScreen(openUrl: open)),
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
      expect(opened, [Uri.parse('app-settings:')]);

      // Allowed in the Settings app, back in the app: the reminders the
      // user asked for are on.
      os.permission = NotificationPermission.granted;
      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
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

      // Master toggle + 3 notification toggles + the weekly tips = 5
      expect(find.byType(SwitchListTile), findsNWidgets(5));
    });
  });
}
