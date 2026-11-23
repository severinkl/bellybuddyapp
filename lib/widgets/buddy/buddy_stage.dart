import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../config/constants.dart';
import 'animated_buddy.dart';
import 'buddy_controller.dart';
import 'buddy_speech_bubble.dart';

/// The Buddy with its speech bubble above it: a fixed-height bubble slot
/// (the bubble sits on its bottom edge) over an [AnimatedBuddy] filling the
/// rest. Needs a bounded height.
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: bubbleHeight,
          width: double.infinity,
          child: LayoutBuilder(
            builder: (context, constraints) => FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.bottomCenter,
              child: BuddySpeechBubble(
                controller: controller,
                maxWidth: math.min(
                  AppConstants.buddyBubbleMaxWidth,
                  constraints.maxWidth,
                ),
              ),
            ),
          ),
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
  }
}
