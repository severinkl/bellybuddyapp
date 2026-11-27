import 'dart:ui' show SemanticsFlag;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/repositories/meal_media_repository.dart';
import 'package:belly_buddy/widgets/common/signed_path_image.dart';

import '../../helpers/fakes.dart';
import '../../helpers/riverpod_helpers.dart';

void main() {
  // Decorative at every use (next to its title, spec §2.2): no „Bild" stop.
  testWidgets('a signed image is left out of semantics', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWithProviders(
      const SignedPathImage(
        pathOrUrl: 'https://x.test/meal.jpg',
        width: 100,
        height: 100,
      ),
      overrides: [
        mealMediaRepositoryProvider.overrideWithValue(
          FakeMealMediaRepository(),
        ),
      ],
    );
    await tester.pump();

    final image = find.byType(CachedNetworkImage);
    expect(image, findsOneWidget);
    expect(
      find.ancestor(of: image, matching: find.byType(ExcludeSemantics)),
      findsWidgets,
    );
    expect(find.semantics.byFlag(SemanticsFlag.isImage), findsNothing);
    handle.dispose();
  });
}
