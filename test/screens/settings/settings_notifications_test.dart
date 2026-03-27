// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/src/internals.dart' show Override;
import 'package:belly_buddy/models/user_profile.dart';
import 'package:belly_buddy/screens/settings/widgets/settings_notifications_screen.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/profile_provider.dart';
import 'package:belly_buddy/repositories/notification_repository.dart';
import 'package:belly_buddy/repositories/profile_repository.dart';

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

void main() {
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

    testWidgets('renders Empfehlungen & Tipps section', (tester) async {
      await tester.pumpWithProviders(
        const SettingsNotificationsScreen(),
        overrides: _overrides(),
      );
      await tester.pump();

      expect(find.text('Empfehlungen & Tipps'), findsAtLeast(1));
    });

    testWidgets('renders SwitchListTiles for all toggles', (tester) async {
      await tester.pumpWithProviders(
        const SettingsNotificationsScreen(),
        overrides: _overrides(),
      );
      await tester.pump();

      // Master toggle + 3 notification toggles = 4
      expect(find.byType(SwitchListTile), findsNWidgets(4));
    });
  });
}
