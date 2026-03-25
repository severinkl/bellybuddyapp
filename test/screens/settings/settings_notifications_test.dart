// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/src/internals.dart' show Override;
import 'package:belly_buddy/models/user_profile.dart';
import 'package:belly_buddy/screens/settings/widgets/settings_notifications_screen.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/profile_provider.dart';
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

      expect(find.text('Benachrichtigungen'), findsOneWidget);
    });

    testWidgets('renders Erinnerungen section', (tester) async {
      await tester.pumpWithProviders(
        const SettingsNotificationsScreen(),
        overrides: _overrides(),
      );
      await tester.pump();

      expect(find.text('Erinnerungen'), findsAtLeast(1));
    });

    testWidgets('renders Push-Benachrichtigungen section', (tester) async {
      await tester.pumpWithProviders(
        const SettingsNotificationsScreen(),
        overrides: _overrides(),
      );
      await tester.pump();

      expect(find.text('Push-Benachrichtigungen'), findsAtLeast(1));
    });

    testWidgets('renders SwitchListTile for reminders', (tester) async {
      await tester.pumpWithProviders(
        const SettingsNotificationsScreen(),
        overrides: _overrides(),
      );
      await tester.pump();

      expect(find.byType(SwitchListTile), findsAtLeast(1));
    });
  });
}
