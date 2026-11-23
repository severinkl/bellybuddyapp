import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:belly_buddy/screens/trackers/meal/widgets/meal_image_section.dart';

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
}
