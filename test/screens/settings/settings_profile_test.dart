// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:riverpod/src/internals.dart' show Override;
import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/models/user_profile.dart';
import 'package:belly_buddy/screens/settings/widgets/settings_profile_screen.dart';
import 'package:belly_buddy/utils/profile_limits.dart';
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

  group('SettingsProfileScreen body data', () {
    late _RecordingProfileRepository repo;

    Future<void> pump(WidgetTester tester) async {
      repo = _RecordingProfileRepository()
        ..seedProfile(
          testUserProfile(
            birthYear: 1990,
            gender: 'weiblich',
            height: 168,
            weight: 64,
          ),
        );
      await tester.pumpWithProviders(
        const SettingsProfileScreen(),
        overrides: [
          profileRepositoryProvider.overrideWithValue(repo),
          currentUserIdProvider.overrideWithValue('test-user'),
        ],
      );
      await tester.pumpAndSettle();
    }

    Finder field(String label) => find.widgetWithText(TextField, label);

    /// Types [text] one keystroke at a time, [gap] apart.
    Future<void> typeSlowly(
      WidgetTester tester,
      Finder finder,
      String text, {
      Duration gap = const Duration(milliseconds: 150),
    }) async {
      for (var i = 1; i <= text.length; i++) {
        await tester.enterText(finder, text.substring(0, i));
        await tester.pump(gap);
      }
    }

    final year = DateTime.now().year;
    final birthYearError =
        'Bitte gib ein Geburtsjahr zwischen '
        '${ProfileLimits.minBirthYear(year)} und '
        '${ProfileLimits.maxBirthYear(year)} ein.';

    testWidgets('a valid birth year is saved once, after typing settles', (
      tester,
    ) async {
      await pump(tester);

      await typeSlowly(tester, field('Geburtsjahr'), '1991');
      expect(repo.updates, isEmpty);

      await tester.pump(AppConstants.debounceDuration);
      await tester.pumpAndSettle();

      expect(repo.updates, hasLength(1));
      expect(repo.updates.single.birthYear, 1991);
      expect(find.text(birthYearError), findsNothing);
    });

    testWidgets('a birth year outside the registration range is not saved '
        'and says why', (tester) async {
      await pump(tester);

      await tester.enterText(field('Geburtsjahr'), '2024');
      await tester.pump(AppConstants.debounceDuration);
      await tester.pumpAndSettle();

      expect(repo.updates, isEmpty);
      expect(repo.storedProfile!.birthYear, 1990);
      expect(find.text(birthYearError), findsOneWidget);

      // Fixing it clears the error right away and saves.
      await tester.enterText(field('Geburtsjahr'), '1985');
      await tester.pump();
      expect(find.text(birthYearError), findsNothing);
      await tester.pump(AppConstants.debounceDuration);
      await tester.pumpAndSettle();
      expect(repo.updates.single.birthYear, 1985);
    });

    testWidgets('only the valid one of height and weight is saved', (
      tester,
    ) async {
      await pump(tester);

      await tester.enterText(field('Größe (cm)'), '300');
      await tester.enterText(field('Gewicht (kg)'), '65');
      await tester.pump(AppConstants.debounceDuration);
      await tester.pumpAndSettle();

      expect(
        find.text('Bitte gib eine Größe zwischen 120 und 219 cm ein.'),
        findsOneWidget,
      );
      expect(repo.updates, hasLength(1));
      expect(repo.updates.single.height, 168);
      expect(repo.updates.single.weight, 65);
    });

    testWidgets('an empty field is not saved as „no value"', (tester) async {
      await pump(tester);

      await tester.enterText(field('Gewicht (kg)'), '');
      await tester.pump(AppConstants.debounceDuration);
      await tester.pumpAndSettle();

      expect(repo.updates, isEmpty);
      expect(repo.storedProfile!.weight, 64);
      expect(
        find.text('Bitte gib ein Gewicht zwischen 30 und 179 kg ein.'),
        findsOneWidget,
      );
    });

    testWidgets('tapping outside closes the number keypad and saves at once', (
      tester,
    ) async {
      await pump(tester);

      await tester.showKeyboard(field('Gewicht (kg)'));
      await tester.enterText(field('Gewicht (kg)'), '66');
      await tester.pump();
      final editable = tester.widget<EditableText>(
        find.descendant(
          of: field('Gewicht (kg)'),
          matching: find.byType(EditableText),
        ),
      );
      expect(editable.focusNode.hasFocus, isTrue);

      await tester.tap(find.text('Persönliche Daten'));
      await tester.pumpAndSettle();

      expect(editable.focusNode.hasFocus, isFalse);
      expect(repo.updates, hasLength(1));
      expect(repo.updates.single.weight, 66);
    });
  });
}

class _RecordingProfileRepository extends FakeProfileRepository {
  final updates = <UserProfile>[];

  @override
  Future<void> updateProfile(String userId, UserProfile profile) async {
    updates.add(profile);
    await super.updateProfile(userId, profile);
  }
}
