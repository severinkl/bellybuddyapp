import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/screens/splash/splash_screen.dart';

import '../../helpers/riverpod_helpers.dart';

void main() {
  // „Belly Buddy" under it says the same: the logo is decorative (§2.2).
  testWidgets('the splash logo is left out of semantics', (tester) async {
    await tester.pumpWithProviders(
      SplashScreen(
        onComplete: () {},
        minDelay: Duration.zero,
        animationDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        preloadImages: false,
      ),
    );

    expect(
      tester.widget<SvgPicture>(find.byType(SvgPicture)).excludeFromSemantics,
      isTrue,
    );
    await tester.pumpAndSettle();
  });
}
