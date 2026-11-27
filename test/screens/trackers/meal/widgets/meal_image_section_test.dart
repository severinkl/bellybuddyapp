import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:belly_buddy/repositories/meal_media_repository.dart';
import 'package:belly_buddy/screens/trackers/meal/widgets/meal_image_section.dart';

import '../../../../helpers/fakes.dart';
import '../../../../helpers/reduce_motion.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  group('MealImageSection empty state', () {
    testWidgets('omits the Rezept button when onPickRecipe is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          MealImageSection(
            imageBytes: null,
            isAnalyzing: false,
            onImagePicked: (_, _) async {},
            onClearImage: () {},
          ),
        ),
      );

      expect(find.text('Kamera'), findsOneWidget);
      expect(find.text('Galerie'), findsOneWidget);
      expect(find.text('Rezept'), findsNothing);
    });

    testWidgets(
      'renders the Rezept button when onPickRecipe is provided and fires it on tap',
      (tester) async {
        var tapped = 0;
        await tester.pumpWidget(
          _wrap(
            MealImageSection(
              imageBytes: null,
              isAnalyzing: false,
              onImagePicked: (_, _) async {},
              onClearImage: () {},
              onPickRecipe: () => tapped++,
            ),
          ),
        );

        expect(find.text('Rezept'), findsOneWidget);
        await tester.tap(find.text('Rezept'));
        await tester.pump();
        expect(tapped, 1);
      },
    );
  });

  group('MealImageSection without photo access', () {
    late List<Uri> opened;

    Future<bool> recordOpen(
      Uri url, {
      LaunchMode mode = LaunchMode.platformDefault,
    }) async {
      opened.add(url);
      return true;
    }

    setUp(() => opened = []);

    Future<void> pumpDenied(WidgetTester tester, String code) =>
        tester.pumpWidget(
          _wrap(
            MealImageSection(
              imageBytes: null,
              isAnalyzing: false,
              onImagePicked: (_, _) async => fail('nothing was picked'),
              onClearImage: () {},
              pickImage: (_) async => throw PlatformException(code: code),
              openUrl: recordOpen,
            ),
          ),
        );

    testWidgets('camera denied explains it and opens the Settings app', (
      tester,
    ) async {
      await pumpDenied(tester, 'camera_access_denied');

      await tester.tap(find.text('Kamera'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Kein Zugriff auf die Kamera'), findsOneWidget);

      await tester.tap(find.text('Einstellungen öffnen'));
      await tester.pumpAndSettle();

      expect(opened, [Uri.parse('app-settings:')]);
      expect(find.text('Kein Zugriff auf die Kamera'), findsNothing);
    });

    testWidgets('on a 393 pt phone the two buttons stack evenly: centered, '
        '„Einstellungen öffnen" on top', (tester) async {
      tester.view
        ..physicalSize = const Size(393, 852)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpDenied(tester, 'camera_access_denied');
      await tester.tap(find.text('Kamera'));
      await tester.pumpAndSettle();

      final dialog = tester.getRect(find.byType(AlertDialog));
      final settings = tester.getRect(find.text('Einstellungen öffnen'));
      final cancel = tester.getRect(find.text('Abbrechen'));
      if (settings.top != cancel.top) {
        expect(settings.bottom, lessThanOrEqualTo(cancel.top));
        expect(settings.center.dx, closeTo(dialog.center.dx, 1));
        expect(cancel.center.dx, closeTo(dialog.center.dx, 1));
      } else {
        expect(cancel.right, lessThan(settings.left));
      }
    });

    testWidgets('gallery denied explains it too', (tester) async {
      await pumpDenied(tester, 'photo_access_denied');

      await tester.tap(find.text('Galerie'));
      await tester.pumpAndSettle();

      expect(find.text('Kein Zugriff auf deine Fotos'), findsOneWidget);
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();
      expect(opened, isEmpty);
      expect(find.text('Kein Zugriff auf deine Fotos'), findsNothing);
    });

    testWidgets('another picker error shows a hint, no dialog', (tester) async {
      await pumpDenied(tester, 'no_available_camera');

      await tester.tap(find.text('Kamera'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.text('Das Bild konnte nicht geladen werden.'),
        findsOneWidget,
      );
    });
  });

  group('MealImageSection for assistive tech', () {
    const onePixelPng = <int>[
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
      0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
      0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
      0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
      0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
    ];

    Future<void> pumpPreview(
      WidgetTester tester, {
      required bool saved,
      required VoidCallback onClear,
    }) => tester.pumpWidget(
      ProviderScope(
        overrides: [
          mealMediaRepositoryProvider.overrideWithValue(
            FakeMealMediaRepository(),
          ),
        ],
        child: _wrap(
          MealImageSection(
            imageBytes: saved ? null : Uint8List.fromList(onePixelPng),
            initialImageUrl: saved ? 'user/meal.jpg' : null,
            isAnalyzing: false,
            onImagePicked: (_, _) async {},
            onClearImage: onClear,
          ),
        ),
      ),
    );

    for (final saved in [false, true]) {
      testWidgets('the photo\'s ✕ is „Foto entfernen", 48 × 48, and removes '
          'the photo (${saved ? 'saved' : 'picked'})', (tester) async {
        final handle = tester.ensureSemantics();
        var cleared = 0;
        await pumpPreview(tester, saved: saved, onClear: () => cleared++);

        final close = find.bySemanticsLabel('Foto entfernen');
        expect(close, findsOneWidget);
        expect(
          tester.getSemantics(close),
          isSemantics(
            label: 'Foto entfernen',
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true,
          ),
        );
        expect(tester.getSize(close), const Size(48, 48));

        tester.semantics.tap(find.semantics.byLabel('Foto entfernen'));
        expect(cleared, 1);
        handle.dispose();
      });
    }

    testWidgets('with reduced motion the saved photo\'s placeholder does not '
        'shimmer', (tester) async {
      reduceMotion(tester);
      await pumpPreview(tester, saved: true, onClear: () {});

      expect(find.byType(Shimmer), findsNothing);
    });
  });
}
