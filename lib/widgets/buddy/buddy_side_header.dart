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
/// needs no headline of its own. With [grow], the bubble shows its whole
/// text and the row grows with it (a note in a scrolling page).
class BuddySideHeader extends StatelessWidget {
  const BuddySideHeader({
    super.key,
    required this.controller,
    required this.buddySize,
    this.name = 'Buddy',
    this.height,
    this.grow = false,
    this.fontSize = AppTheme.fontSizeSubtitleLG,
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

  /// The header's height (at least, with [grow]); defaults to the Buddy's.
  final double? height;

  /// Whether the bubble shows its whole text, however many lines, and the
  /// header grows with it. Otherwise the bubble keeps its line limit and a
  /// taller one (large text scale) is scaled down into [height].
  final bool grow;

  /// The bubble's text size.
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    // The bubble starts so its tail meets his face.
    final face = BuddyLayout(buddySize).toLocal(kBuddyFaceCenter).dy;
    final bubbleTop = math.max(0.0, face - AppConstants.buddyBubbleSideTailTop);
    final headerHeight = height ?? buddySize.height;
    final row = Padding(
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
                builder: (context, constraints) {
                  final bubble = BuddySpeechBubble(
                    controller: controller,
                    maxWidth: constraints.maxWidth,
                    tail: const BuddyBubbleTail.left(),
                    fontSize: fontSize,
                    maxLines: grow ? null : AppConstants.buddyBubbleMaxLines,
                  );
                  if (grow) {
                    return Align(alignment: Alignment.topLeft, child: bubble);
                  }
                  // A taller bubble (large text scale) is scaled down to fit.
                  return FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topLeft,
                    child: bubble,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
    if (grow) {
      return ConstrainedBox(
        constraints: BoxConstraints(minHeight: headerHeight),
        child: row,
      );
    }
    return SizedBox(height: headerHeight, child: row);
  }
}
