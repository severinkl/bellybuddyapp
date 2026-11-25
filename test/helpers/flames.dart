import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/widgets/buddy/streak_flame.dart';

/// The painter of the [StreakFlame] [flame] finds (by default the only
/// one).
FlamePainter flamePainter(WidgetTester tester, [Finder? flame]) =>
    tester
            .widget<CustomPaint>(
              find.descendant(
                of: flame ?? find.byType(StreakFlame),
                matching: find.byType(CustomPaint),
              ),
            )
            .painter!
        as FlamePainter;
