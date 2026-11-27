import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/utils/share_origin.dart';

void main() {
  testWidgets('shareOriginOf is the render box rect on screen', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          children: [
            Positioned(
              left: 20,
              top: 300,
              child: SizedBox(key: key, width: 100, height: 40),
            ),
          ],
        ),
      ),
    );

    expect(
      shareOriginOf(key.currentContext),
      const Rect.fromLTWH(20, 300, 100, 40),
    );
  });

  test('shareOriginOf without a context is Rect.zero', () {
    expect(shareOriginOf(null), Rect.zero);
  });
}
