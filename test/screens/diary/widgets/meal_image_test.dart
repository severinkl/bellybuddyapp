import 'dart:async';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/models/meal_entry.dart';
import 'package:belly_buddy/repositories/meal_media_repository.dart';
import 'package:belly_buddy/screens/diary/widgets/detail_sheets/meal_detail.dart';
import 'package:belly_buddy/screens/diary/widgets/meal_image.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/riverpod_helpers.dart';

/// A 1×1 transparent PNG.
final _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

class _UrlRepo extends FakeMealMediaRepository {
  _UrlRepo(this._resolve);
  final Future<String?> Function() _resolve;

  @override
  Future<String?> resolveSignedUrl(String? urlOrPath) => _resolve();
}

List<String> _imageLabels() => find.semantics
    .byPredicate((n) => n.flagsCollection.isImage)
    .evaluate()
    .map((n) => n.label)
    .toList();

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  required Future<String?> Function() resolve,
}) => tester.pumpWithProviders(
  Scaffold(body: SingleChildScrollView(child: child)),
  overrides: [mealMediaRepositoryProvider.overrideWithValue(_UrlRepo(resolve))],
);

/// Renders what the image shows once loaded (the network never loads in
/// tests): the [CachedNetworkImage]'s own imageBuilder on a real image.
Future<void> _showLoaded(WidgetTester tester) async {
  final cni = tester.widget<CachedNetworkImage>(
    find.byType(CachedNetworkImage),
  );
  expect(cni.imageBuilder, isNotNull);
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => cni.imageBuilder!(context, MemoryImage(_png)),
      ),
    ),
  );
}

void main() {
  testWidgets('while the URL resolves there is no image node', (tester) async {
    final handle = tester.ensureSemantics();
    final pending = Completer<String?>();
    await _pump(
      tester,
      const MealImage(imageUrl: 'p.jpg', semanticLabel: 'Foto: Pasta'),
      resolve: () => pending.future,
    );
    await tester.pump();
    expect(_imageLabels(), isEmpty);
    expect(find.semantics.byLabel('Foto: Pasta'), findsNothing);
    handle.dispose();
  });

  testWidgets('a photo that is not available is not an image „Foto: …"', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      const MealImage(imageUrl: 'p.jpg', semanticLabel: 'Foto: Pasta'),
      resolve: () async => null,
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.image_not_supported), findsOneWidget);
    expect(_imageLabels(), isEmpty);
    expect(find.semantics.byLabel('Foto: Pasta'), findsNothing);
    handle.dispose();
  });

  testWidgets('before the photo loads there is no image node; once loaded '
      'it is the image „Foto: Pasta"', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      const MealImage(imageUrl: 'p.jpg', semanticLabel: 'Foto: Pasta'),
      resolve: () async => 'https://example.invalid/p.jpg',
    );
    await tester.pump();
    await tester.pump();
    expect(find.byType(CachedNetworkImage), findsOneWidget);
    expect(_imageLabels(), isEmpty);

    await _showLoaded(tester);
    expect(_imageLabels(), ['Foto: Pasta']);
    handle.dispose();
  });

  testWidgets('without a label the loaded photo adds no node', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      const MealImage(imageUrl: 'p.jpg'),
      resolve: () async => 'https://example.invalid/p.jpg',
    );
    await tester.pump();
    await tester.pump();
    await _showLoaded(tester);
    expect(_imageLabels(), isEmpty);
    handle.dispose();
  });

  testWidgets('the meal detail names the photo „Foto: <Titel>", or „Foto" '
      'for an empty title', (tester) async {
    for (final (title, label) in [
      ('Pasta mit Tomaten', 'Foto: Pasta mit Tomaten'),
      ('  ', 'Foto'),
    ]) {
      await _pump(
        tester,
        MealDetail(
          meal: MealEntry(
            id: 'm',
            trackedAt: DateTime(2026, 4, 10, 12, 30),
            title: title,
            imageUrl: 'p.jpg',
          ),
        ),
        resolve: () async => 'https://example.invalid/p.jpg',
      );
      await tester.pump();
      expect(
        tester.widget<MealImage>(find.byType(MealImage)).semanticLabel,
        label,
      );
    }
  });
}
