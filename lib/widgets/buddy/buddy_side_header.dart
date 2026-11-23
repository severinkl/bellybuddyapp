import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';
import 'animated_buddy.dart';
import 'buddy_controller.dart';
import 'buddy_geometry.dart';
import 'buddy_speech_bubble.dart';

/// A header row with the Buddy on the left ([buddySize]) and his speech
/// bubble on the right, its tail pointing at his face. Used where the
/// bubble asks a question above a form or a list ("Layout 1"): the screen
/// needs no headline of its own.
class BuddySideHeader extends StatelessWidget {
  const BuddySideHeader({
    super.key,
    required this.controller,
    required this.buddySize,
    this.name = 'Buddy',
    this.height,
  });

  /// The default size: [AppConstants.buddyWizardBuddyWidth] wide.
  static const Size defaultBuddySize = Size(
    AppConstants.buddyWizardBuddyWidth,
    AppConstants.buddyWizardBuddyWidth / kBuddyStageAspect,
  );

  final BuddyController controller;
  final Size buddySize;

  /// The Buddy's name (semantics label).
  final String name;

  /// The header's height; defaults to the Buddy's.
  final double? height;

  @override
  Widget build(BuildContext context) {
    // The bubble starts so its tail meets his face.
    final face = BuddyLayout(buddySize).toLocal(kBuddyFaceCenter).dy;
    final bubbleTop = math.max(0.0, face - AppConstants.buddyBubbleSideTailTop);
    return SizedBox(
      height: height ?? buddySize.height,
      child: Padding(
        padding: const EdgeInsets.only(
          left: AppConstants.spacingSm,
          right: AppConstants.spacingMd,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox.fromSize(
              size: buddySize,
              child: AnimatedBuddy(controller: controller, name: name),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: bubbleTop),
                child: LayoutBuilder(
                  // A taller bubble (large text scale) is scaled down to fit.
                  builder: (context, constraints) => FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topLeft,
                    child: BuddySpeechBubble(
                      controller: controller,
                      maxWidth: constraints.maxWidth,
                      tail: const BuddyBubbleTail.left(),
                      fontSize: AppTheme.fontSizeSubtitleLG,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
