// ignore_for_file: invalid_use_of_internal_member
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/src/internals.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:belly_buddy/providers/buddy_events_provider.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/meal_tracker_provider.dart';
import 'package:belly_buddy/repositories/buddy_repository.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';
import 'package:belly_buddy/repositories/ingredient_repository.dart';
import 'package:belly_buddy/repositories/meal_media_repository.dart';
import 'package:belly_buddy/screens/trackers/meal/meal_tracker_screen.dart';
import 'package:belly_buddy/services/buddy/buddy_mood_logic.dart';
import 'package:belly_buddy/widgets/buddy/buddy_reaction_view.dart';
import 'package:belly_buddy/widgets/common/mascot_image.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/riverpod_helpers.dart';

List<Override> _overrides() => [
  entryRepositoryProvider.overrideWithValue(FakeEntryRepository()),
  ingredientRepositoryProvider.overrideWithValue(FakeIngredientRepository()),
  mealMediaRepositoryProvider.overrideWithValue(FakeMealMediaRepository()),
  buddyRepositoryProvider.overrideWithValue(FakeBuddyRepository()),
  currentUserIdProvider.overrideWithValue('test-user'),
];

/// A valid 1×1 transparent PNG.
const _onePixelPng = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
];

void main() {
  group('MealTrackerScreen', () {
    testWidgets('renders Neue Mahlzeit title text', (tester) async {
      await tester.pumpWithProviders(
        const MealTrackerScreen(),
        overrides: _overrides(),
      );
      await tester.pump();

      expect(find.text('Neue Mahlzeit'), findsOneWidget);
    });

    testWidgets('renders Speichern button', (tester) async {
      await tester.pumpWithProviders(
        const MealTrackerScreen(),
        overrides: _overrides(),
      );
      await tester.pump();

      expect(find.text('Speichern'), findsOneWidget);
    });

    testWidgets('renders Getränk tracken button', (tester) async {
      await tester.pumpWithProviders(
        const MealTrackerScreen(),
        overrides: _overrides(),
      );
      await tester.pump();

      expect(find.text('Getränk tracken'), findsOneWidget);
    });

    testWidgets('renders edit icon next to title', (tester) async {
      await tester.pumpWithProviders(
        const MealTrackerScreen(),
        overrides: _overrides(),
      );
      await tester.pump();

      expect(find.byIcon(Icons.edit), findsOneWidget);
    });

    testWidgets('tapping save with the default title opens the naming sheet', (
      tester,
    ) async {
      await tester.pumpWithProviders(
        const MealTrackerScreen(),
        overrides: _overrides(),
      );
      // Two pumps: one for the first build, one for the post-frame callback
      // in MealTrackerScreen.initState that calls notifier.reset(). Seeding
      // the ingredient before that callback fires would be wiped.
      await tester.pump();
      await tester.pump();

      // _canSave requires at least one ingredient — seed via provider to
      // avoid driving the whole ingredient search UI.
      final element = tester.element(find.byType(MealTrackerScreen));
      ProviderScope.containerOf(
        element,
      ).read(mealTrackerProvider.notifier).addIngredient('Tomate');
      await tester.pump();

      await tester.ensureVisible(find.byKey(MealTrackerScreen.mealEditSaveKey));
      await tester.tap(find.byKey(MealTrackerScreen.mealEditSaveKey));
      // Sheet slide-in (~250ms). Fixed-duration pumps avoid the
      // autofocus-cursor-blink hang that breaks pumpAndSettle.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Gib deiner Mahlzeit einen Namen'), findsOneWidget);
    });

    testWidgets(
      'successful save emits a Buddy event and shows the eating Buddy above '
      'the success actions',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        await tester.pumpWithProviders(
          const MealTrackerScreen(),
          overrides: _overrides(),
        );
        // First build + the post-frame reset() in initState.
        await tester.pump();
        await tester.pump();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(MealTrackerScreen)),
        );
        final photo = Uint8List.fromList(_onePixelPng);
        container.read(mealTrackerProvider.notifier)
          ..addIngredient('Tomate')
          ..setTitle('Tomatensalat')
          ..setImage(photo, 'salat.jpg');
        await tester.pump();

        await tester.ensureVisible(
          find.byKey(MealTrackerScreen.mealEditSaveKey),
        );
        await tester.tap(find.byKey(MealTrackerScreen.mealEditSaveKey));
        await tester.pump();
        // The Buddy animates forever: pump past the overlay intro only.
        await tester.pump(const Duration(milliseconds: 700));

        final event = container.read(buddyEventsProvider);
        expect(event?.kind, EntryKind.meal);
        expect(event?.sentiment, LogSentiment.good);
        expect(find.text('Mahlzeit gespeichert!'), findsOneWidget);
        final view = tester.widget<BuddyReactionView>(
          find.byType(BuddyReactionView),
        );
        expect(view.kind, EntryKind.meal);
        expect(view.foodImageBytes, same(photo));
        expect(find.byType(MascotImage), findsNothing);
        expect(find.text('Getränk hinzufügen'), findsOneWidget);
        expect(find.text('Als Rezept speichern'), findsOneWidget);
      },
    );
  });
}
