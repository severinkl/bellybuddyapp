import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../config/constants.dart';
import 'animated_buddy.dart';
import 'buddy_geometry.dart';
import 'buddy_shape_data.dart';
import 'buddy_controller.dart';
import 'buddy_speech_bubble.dart';

/// The Buddy with its speech bubble above it: a fixed-height
/// [BuddyBubbleSlot] over an [AnimatedBuddy] filling the rest. Needs a
/// bounded height.
class BuddyStage extends StatelessWidget {
  const BuddyStage({
    super.key,
    required this.controller,
    this.name = 'Buddy',
    this.onPoke,
    this.bubbleHeight = AppConstants.buddyBubbleHeight,
  });

  final BuddyController controller;
  final String name;
  final VoidCallback? onPoke;

  /// Height reserved for the bubble; a taller bubble (large text scale) is
  /// scaled down to fit instead of overflowing.
  final double bubbleHeight;

  /// How far right of the stage's centre the Buddy's face is when he fills
  /// [buddyArea] (negative: left; he is drawn centred).
  static double faceShift(Size buddyArea) =>
      (kBuddyFaceCenter.dx - kBuddyWidth / 2) * BuddyLayout.scaleFor(buddyArea);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final buddyArea = Size(
          width,
          math.max(0, constraints.maxHeight - bubbleHeight),
        );
        return Column(
          children: [
            BuddyBubbleSlot(
              controller: controller,
              width: width,
              buddyArea: buddyArea,
              height: bubbleHeight,
            ),
            Expanded(
              child: AnimatedBuddy(
                controller: controller,
                name: name,
                onPoke: onPoke,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The bubble slot above a Buddy who fills [buddyArea]: [height] tall and
/// [width] wide, his speech bubble on its bottom edge (at most
/// [AppConstants.buddyBubbleMaxWidth] wide) with its tail pointing at his
/// face. A taller bubble (large text scale) is scaled down to fit instead
/// of overflowing.
class BuddyBubbleSlot extends StatelessWidget {
  const BuddyBubbleSlot({
    super.key,
    required this.controller,
    required this.width,
    required this.buddyArea,
    this.height = AppConstants.buddyBubbleHeight,
  });

  final BuddyController controller;
  final double width;
  final Size buddyArea;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.bottomCenter,
        child: BuddySpeechBubble(
          controller: controller,
          maxWidth: math.min(AppConstants.buddyBubbleMaxWidth, width),
          tail: BuddyBubbleTail.down(shift: BuddyStage.faceShift(buddyArea)),
        ),
      ),
    );
  }
}
