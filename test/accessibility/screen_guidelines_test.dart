import 'package:flutter_test/flutter_test.dart';

import '../helpers/layout_checks.dart';
import 'a11y_screens.dart';

/// Every main screen against Flutter's accessibility guidelines (spec §4.4):
/// Android's 48 and iOS's 44 tap targets, a label on every tap target and
/// text contrast. A check still pending on a screen is skipped, with the task
/// that clears it in [A11yScreen.pending]. Any other Flutter error while the
/// screen opens fails it too; overflows are left to `text_scale_test.dart`
/// (sideways ones are test-font noise, see [verticalOverflows]).
void main() {
  setUpA11yScreens();

  for (final s in a11yScreens) {
    for (final (check, guideline) in [
      (A11yCheck.androidTapTarget, androidTapTargetGuideline),
      (A11yCheck.iosTapTarget, iOSTapTargetGuideline),
      (A11yCheck.labeledTapTarget, labeledTapTargetGuideline),
      (A11yCheck.textContrast, textContrastGuideline),
    ]) {
      final owner = s.pending[check];
      testWidgets(
        '${s.name}: ${check.name}${owner == null ? '' : ' (pending $owner)'}',
        skip: owner != null,
        (tester) async {
          final handle = tester.ensureSemantics();
          try {
            final errors = await collectFlutterErrors(
              () => pumpA11yScreen(tester, s),
            );
            expect(errors.where((e) => !e.contains('overflowed')), isEmpty);
            await expectLater(tester, meetsGuideline(guideline));
          } finally {
            handle.dispose();
          }
        },
      );
    }
  }
}
