// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/src/internals.dart' show Override;
import 'package:belly_buddy/screens/settings/widgets/settings_profile_screen.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/repositories/profile_repository.dart';

import '../../helpers/fakes.dart';
import '../../helpers/fixtures.dart';
import '../../helpers/riverpod_helpers.dart';

List<Override> _overrides() {
  final fakeRepo = FakeProfileRepository()
    ..seedProfile(testUserProfile(gender: 'männlich'));
  return [
    profileRepositoryProvider.overrideWithValue(fakeRepo),
    currentUserIdProvider.overrideWithValue('test-user'),
  ];
}

void main() {
  group('SettingsProfileScreen', () {
    testWidgets('renders Mein Profil app bar title', (tester) async {
      await tester.pumpWithProviders(
        const SettingsProfileScreen(),
        overrides: _overrides(),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mein Profil'), findsOneWidget);
    });

    testWidgets('renders Persönliche Daten section', (tester) async {
      await tester.pumpWithProviders(
        const SettingsProfileScreen(),
        overrides: _overrides(),
      );
      await tester.pumpAndSettle();

      expect(find.text('Persönliche Daten'), findsOneWidget);
    });

    testWidgets('renders Geburtsjahr field', (tester) async {
      await tester.pumpWithProviders(
        const SettingsProfileScreen(),
        overrides: _overrides(),
      );
      await tester.pumpAndSettle();

      expect(find.text('Geburtsjahr'), findsOneWidget);
    });

    testWidgets('renders Ernährung section', (tester) async {
      await tester.pumpWithProviders(
        const SettingsProfileScreen(),
        overrides: _overrides(),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ernährung'), findsOneWidget);
    });

    testWidgets('renders Unverträglichkeiten section', (tester) async {
      await tester.pumpWithProviders(
        const SettingsProfileScreen(),
        overrides: _overrides(),
      );
      await tester.pumpAndSettle();

      expect(find.text('Unverträglichkeiten'), findsOneWidget);
    });
  });
}
