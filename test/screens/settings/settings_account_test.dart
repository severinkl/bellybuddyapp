// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/src/internals.dart' show Override;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:belly_buddy/screens/settings/widgets/settings_account_screen.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/repositories/auth_repository.dart';
import 'package:belly_buddy/repositories/profile_repository.dart';

import '../../helpers/fakes.dart';
import '../../helpers/mocks.dart';
import '../../helpers/riverpod_helpers.dart';

class _FakeGoTrueClient extends Mock implements GoTrueClient {
  @override
  User? get currentUser => null;
}

List<Override> _buildOverrides() {
  final mockClient = MockSupabaseClient();
  final mockAuth = _FakeGoTrueClient();
  when(() => mockClient.auth).thenReturn(mockAuth);

  return [
    supabaseClientProvider.overrideWithValue(mockClient),
    authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
    profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
    currentUserIdProvider.overrideWithValue(null),
  ];
}

void main() {
  group('SettingsAccountScreen', () {
    testWidgets('renders Konto & Sicherheit app bar title', (tester) async {
      await tester.pumpWithProviders(
        const SettingsAccountScreen(),
        overrides: _buildOverrides(),
      );
      await tester.pump();

      expect(find.text('Konto & Sicherheit'), findsOneWidget);
    });

    testWidgets('renders Kontoinformationen section', (tester) async {
      await tester.pumpWithProviders(
        const SettingsAccountScreen(),
        overrides: _buildOverrides(),
      );
      await tester.pump();

      expect(find.text('Kontoinformationen'), findsOneWidget);
    });

    testWidgets('renders Abmelden button', (tester) async {
      await tester.pumpWithProviders(
        const SettingsAccountScreen(),
        overrides: _buildOverrides(),
      );
      await tester.pump();

      expect(find.text('Abmelden'), findsOneWidget);
    });

    testWidgets('renders Gefahrenzone section', (tester) async {
      await tester.pumpWithProviders(
        const SettingsAccountScreen(),
        overrides: _buildOverrides(),
      );
      await tester.pump();

      expect(find.text('Gefahrenzone'), findsOneWidget);
    });
  });
}
