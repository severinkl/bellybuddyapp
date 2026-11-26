import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/models/user_profile.dart';
import 'package:belly_buddy/providers/auth_provider.dart';
import 'package:belly_buddy/providers/buddy_provider.dart';
import 'package:belly_buddy/providers/notification_provider.dart';
import 'package:belly_buddy/providers/profile_provider.dart';
import 'package:belly_buddy/repositories/notification_repository.dart';
import 'package:belly_buddy/repositories/profile_repository.dart';

import '../helpers/app_lifecycle.dart';
import '../helpers/fakes.dart';
import '../helpers/fixtures.dart';
import '../helpers/riverpod_helpers.dart';

/// An Android denial for good that its notification plugin asked for:
/// the OS reports it as never asked, and a request shows nothing.
class _AndroidDeniedForGood extends FakeNotificationRepository {
  _AndroidDeniedForGood() {
    permission = NotificationPermission.notDetermined;
  }

  @override
  Future<bool> requestAllPermissions() async {
    requests++;
    return false;
  }
}

void main() {
  final today = DateTime(2026, 11, 26);

  group('reminderAskScheduled', () {
    bool due({
      int asks = 0,
      DateTime? lastAsk,
      int activeDays = 2,
      DateTime? on,
    }) => reminderAskScheduled(
      asks: asks,
      lastAsk: lastAsk,
      activeDays: activeDays,
      today: on ?? today,
    );

    test('the first ask comes with the 2nd active day', () {
      expect(due(activeDays: 0), isFalse);
      expect(due(activeDays: 1), isFalse);
      expect(due(activeDays: 2), isTrue);
      expect(due(activeDays: 5), isTrue);
    });

    test('the second with the 7th active day, never on the first ask\'s '
        'day', () {
      final yesterday = DateTime(2026, 11, 25);
      expect(due(asks: 1, lastAsk: yesterday, activeDays: 6), isFalse);
      expect(due(asks: 1, lastAsk: yesterday, activeDays: 7), isTrue);
      expect(due(asks: 1, lastAsk: today, activeDays: 7), isFalse);
    });

    test('then every 30 days after the last ask', () {
      final last = DateTime(2026, 10, 28);
      expect(due(asks: 2, lastAsk: last, on: DateTime(2026, 11, 26)), isFalse);
      expect(due(asks: 2, lastAsk: last, on: DateTime(2026, 11, 27)), isTrue);
      expect(due(asks: 3, lastAsk: last, on: DateTime(2026, 11, 27)), isTrue);
    });

    test('30 days count as calendar days, across a DST change', () {
      // Vienna leaves summer time on 2026-10-25.
      final last = DateTime(2026, 10, 1);
      expect(due(asks: 2, lastAsk: last, on: DateTime(2026, 10, 30)), isFalse);
      expect(due(asks: 2, lastAsk: last, on: DateTime(2026, 10, 31)), isTrue);
    });

    test('never after the 4th ask, never twice a day', () {
      final longAgo = DateTime(2025, 1, 1);
      expect(due(asks: 4, lastAsk: longAgo, activeDays: 30), isFalse);
      expect(due(asks: 0, lastAsk: today, activeDays: 30), isFalse);
      expect(due(asks: 2, lastAsk: today), isFalse);
    });
  });

  group('asking again', () {
    late FakeNotificationRepository os;
    late FakeProfileRepository profiles;
    late WidgetRef widgetRef;
    late ProviderContainer container;

    UserProfile? profile() => container.read(profileProvider).value;

    /// Pumps a widget whose ref the helpers take, with [profile] loaded,
    /// [activeDays] in the insights and the prefs in [prefs].
    Future<void> pump(
      WidgetTester tester, {
      UserProfile? withProfile,
      bool remindersOn = false,
      int activeDays = 2,
      Map<String, Object> prefs = const {
        AppConstants.keyNotificationModalShown: true,
      },
    }) async {
      SharedPreferences.setMockInitialValues(prefs);
      final seeded =
          withProfile ?? testUserProfile().withNotifications(remindersOn);
      profiles = FakeProfileRepository()..seedProfile(seeded);
      container = ProviderContainer.test(
        overrides: [
          currentUserIdProvider.overrideWithValue('u1'),
          buddyClockProvider.overrideWithValue(() => DateTime(2026, 11, 26, 9)),
          notificationRepositoryProvider.overrideWithValue(os),
          profileRepositoryProvider.overrideWithValue(profiles),
          profileProviderSeededWith(seeded),
          insightsProviderSeededWith(lockedInsights(activeDays: activeDays)),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (_, ref, _) {
              widgetRef = ref;
              return const SizedBox();
            },
          ),
        ),
      );
    }

    Future<bool> off() => container.read(remindersOffProvider.future);

    Future<bool> due() async {
      final sub = container.listen(reminderAskDueProvider, (_, _) {});
      addTearDown(sub.close);
      return container.read(reminderAskDueProvider.future);
    }

    setUp(() => os = FakeNotificationRepository());

    group('remindersOffProvider', () {
      testWidgets('off while every notification is off in the profile', (
        tester,
      ) async {
        await pump(tester);
        expect(await off(), isTrue);
      });

      testWidgets('off while the OS does not allow them, even with the '
          'profile on', (tester) async {
        for (final permission in [
          NotificationPermission.notDetermined,
          NotificationPermission.denied,
        ]) {
          os.permission = permission;
          await pump(tester, remindersOn: true);
          expect(await off(), isTrue, reason: '$permission');
        }
      });

      testWidgets('on with the profile on and the OS allowing them', (
        tester,
      ) async {
        await pump(tester, remindersOn: true);
        expect(await off(), isFalse);
      });

      testWidgets('one flag on is on', (tester) async {
        await pump(
          tester,
          withProfile: testUserProfile(
            remindersEnabled: false,
            dailySummaryEnabled: false,
            pushEnabled: true,
          ),
        );
        expect(await off(), isFalse);
      });

      testWidgets('no profile loaded: nothing to offer', (tester) async {
        await pump(tester);
        container.read(profileProvider.notifier).reset();
        expect(await off(), isFalse);
      });

      testWidgets('read again when the app is back from the background (the '
          'Settings app)', (tester) async {
        os.permission = NotificationPermission.denied;
        await pump(tester, remindersOn: true);
        final sub = container.listen(remindersOffProvider, (_, _) {});
        addTearDown(sub.close);
        expect(await off(), isTrue);

        os.permission = NotificationPermission.granted;
        returnFromBackground();
        await tester.pump();
        expect(await off(), isFalse);
      });
    });

    group('reminderAskDueProvider', () {
      testWidgets('due while off, from the 2nd active day', (tester) async {
        await pump(tester, activeDays: 2);
        expect(await due(), isTrue);
      });

      testWidgets('not before the 2nd active day', (tester) async {
        await pump(tester, activeDays: 1);
        expect(await due(), isFalse);
      });

      testWidgets('never while reminders are on', (tester) async {
        await pump(tester, remindersOn: true, activeDays: 30);
        expect(await due(), isFalse);
      });

      testWidgets('not before the first offer (the onboarding step or the '
          'one-time dialog) was made', (tester) async {
        await pump(tester, prefs: const {});
        expect(await due(), isFalse);
      });

      testWidgets('an ask counts (in the prefs): not again the same day', (
        tester,
      ) async {
        await pump(tester, activeDays: 7);
        expect(await due(), isTrue);

        await recordReminderAsk(widgetRef);
        expect(await due(), isFalse);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getInt('${AppConstants.keyReminderAsksPrefix}u1'), 1);
        expect(
          prefs.getString('${AppConstants.keyReminderAskedOnPrefix}u1'),
          '2026-11-26',
        );
      });

      testWidgets('after the 4th ask, never again', (tester) async {
        await pump(
          tester,
          activeDays: 30,
          prefs: {
            AppConstants.keyNotificationModalShown: true,
            '${AppConstants.keyReminderAsksPrefix}u1': 4,
            '${AppConstants.keyReminderAskedOnPrefix}u1': '2025-01-01',
          },
        );
        expect(await due(), isFalse);
      });

      testWidgets('the asks are counted per user', (tester) async {
        await pump(
          tester,
          prefs: {
            AppConstants.keyNotificationModalShown: true,
            '${AppConstants.keyReminderAsksPrefix}other': 4,
            '${AppConstants.keyReminderAskedOnPrefix}other': '2026-11-26',
          },
        );
        expect(await due(), isTrue);
      });
    });

    group('turnOnReminders', () {
      testWidgets('never asked: the OS dialog, allowed → every notification '
          'on', (tester) async {
        os.permission = NotificationPermission.notDetermined;
        await pump(tester);

        expect(await turnOnReminders(widgetRef), RemindersTurnOn.on);
        expect(os.requests, 1);
        expect(os.settingsOpened, 0);
        expect(profile()!.anyNotificationOn, isTrue);
      });

      testWidgets('the OS allows them, the profile has them off: on without '
          'a dialog', (tester) async {
        await pump(tester);
        expect(await turnOnReminders(widgetRef), RemindersTurnOn.on);
        expect(profile()!.remindersEnabled, isTrue);
      });

      testWidgets('the dialog declined: stays off, no settings', (
        tester,
      ) async {
        os
          ..permission = NotificationPermission.notDetermined
          ..grantOnRequest = false;
        await pump(tester);

        expect(await turnOnReminders(widgetRef), RemindersTurnOn.declined);
        expect(os.settingsOpened, 0);
        expect(profile()!.anyNotificationOn, isFalse);
      });

      testWidgets('denied for good: opens the system settings instead of '
          'asking', (tester) async {
        os.permission = NotificationPermission.denied;
        await pump(tester);

        expect(
          await turnOnReminders(widgetRef),
          RemindersTurnOn.settingsOpened,
        );
        expect(os.requests, 0);
        expect(os.settingsOpened, 1);
      });

      testWidgets('Android, denied for good but reported as never asked: '
          'the request shows nothing, so the settings open', (tester) async {
        os = _AndroidDeniedForGood();
        await pump(tester);

        expect(
          await turnOnReminders(widgetRef),
          RemindersTurnOn.settingsOpened,
        );
        expect(os.requests, 1);
        expect(os.settingsOpened, 1);
      });

      testWidgets('the settings do not open: failed', (tester) async {
        os
          ..permission = NotificationPermission.denied
          ..settingsOpen = false;
        await pump(tester);
        expect(await turnOnReminders(widgetRef), RemindersTurnOn.failed);
      });

      testWidgets('no profile loaded: failed, nothing asked', (tester) async {
        await pump(tester);
        container.read(profileProvider.notifier).reset();
        expect(await turnOnReminders(widgetRef), RemindersTurnOn.failed);
        expect(os.requests, 0);
      });

      testWidgets('allowed in the settings: back in the app, every '
          'notification turns on', (tester) async {
        os.permission = NotificationPermission.denied;
        await pump(tester);
        await turnOnReminders(widgetRef);

        os.permission = NotificationPermission.granted;
        returnFromBackground();
        await tester.pump();
        await tester.pump();
        expect(profile()!.anyNotificationOn, isTrue);
      });

      testWidgets('not allowed there: they stay off', (tester) async {
        os.permission = NotificationPermission.denied;
        await pump(tester);
        await turnOnReminders(widgetRef);

        returnFromBackground();
        await tester.pump();
        expect(profile()!.anyNotificationOn, isFalse);
      });

      testWidgets('a later return without the settings changes nothing', (
        tester,
      ) async {
        os.permission = NotificationPermission.denied;
        await pump(tester);
        await turnOnReminders(widgetRef);
        returnFromBackground();
        await tester.pump();

        // Allowed later, by other means: the profile stays as the user set it.
        os.permission = NotificationPermission.granted;
        returnFromBackground();
        await tester.pump();
        expect(profile()!.anyNotificationOn, isFalse);
      });
    });
  });
}
