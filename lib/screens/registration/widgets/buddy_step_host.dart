import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../widgets/buddy/buddy.dart';

/// How the Buddy makes room while the keyboard is open.
enum BuddyKeyboardStage {
  /// A smaller Buddy ([AppConstants.buddyWizardCompactSize] tall) with his
  /// bubble in a [AppConstants.buddyWizardCompactHeaderHeight] header.
  compact,

  /// No Buddy, so a form and its actions fit above the keyboard.
  hidden,
}

/// Hosts the registration steps under the Buddy. A header runs across the
/// top: the Buddy on the left ([AppConstants.buddyWizardBuddyWidth] wide)
/// and his speech bubble on the right, its tail pointing at his face. The
/// bubble asks each step's question, so the steps carry no headline of
/// their own. [child] (the wizard's pages) fills the rest.
///
/// While [keyboardOpen], the header shrinks as [keyboardStage] says
/// (animated, instant under reduced motion). [child] gets the rest of the
/// height, but at least [AppConstants.buddyWizardMinStepHeight]; with less
/// room the header and the step scroll together, so a focused field can
/// still be scrolled into view.
///
/// The host sits in a `Scaffold` body, whose `MediaQuery` has the keyboard
/// inset removed, so the wizard passes [keyboardOpen] from above it. There
/// is one host per wizard: its controller drives exactly one
/// [AnimatedBuddy] while the pages change below it.
class BuddyStepHost extends StatelessWidget {
  const BuddyStepHost({
    super.key,
    required this.controller,
    required this.name,
    required this.child,
    this.keyboardOpen = false,
    this.keyboardStage = BuddyKeyboardStage.compact,
  });

  static const headerKey = Key('buddy_step_host_header');

  final BuddyController controller;

  /// The Buddy's name (semantics label).
  final String name;

  final Widget child;

  /// Whether the soft keyboard is showing.
  final bool keyboardOpen;

  /// What the Buddy does while [keyboardOpen].
  final BuddyKeyboardStage keyboardStage;

  /// The Buddy's size in the header; null when he is hidden.
  Size? get _buddySize {
    if (!keyboardOpen) {
      const width = AppConstants.buddyWizardBuddyWidth;
      return const Size(width, width / kBuddyStageAspect);
    }
    return switch (keyboardStage) {
      BuddyKeyboardStage.compact => const Size(
        AppConstants.buddyWizardCompactSize * kBuddyStageAspect,
        AppConstants.buddyWizardCompactSize,
      ),
      BuddyKeyboardStage.hidden => null,
    };
  }

  double get _headerHeight {
    final buddy = _buddySize;
    if (buddy == null) return 0;
    return keyboardOpen
        ? AppConstants.buddyWizardCompactHeaderHeight
        : buddy.height;
  }

  Widget _header(Size? buddy, double height) {
    if (buddy == null) return const SizedBox(width: double.infinity);
    // The bubble starts so its tail meets his face.
    final face = BuddyLayout(buddy).toLocal(kBuddyFaceCenter).dy;
    final bubbleTop = math.max(0.0, face - AppConstants.buddyBubbleSideTailTop);
    return SizedBox(
      key: headerKey,
      height: height,
      child: Padding(
        padding: const EdgeInsets.only(
          left: AppConstants.spacingSm,
          right: AppConstants.spacingMd,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox.fromSize(
              size: buddy,
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

  @override
  Widget build(BuildContext context) {
    final buddy = _buddySize;
    final header = _headerHeight;
    final calm = MediaQuery.disableAnimationsOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final minHeight = header + AppConstants.buddyWizardMinStepHeight;
        final height = constraints.hasBoundedHeight
            ? math.max(constraints.maxHeight, minHeight)
            : minHeight;
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: SizedBox(
            height: height,
            child: Column(
              children: [
                // Under reduced motion the header resizes instantly. (Not an
                // AnimatedSize with a zero duration: that one re-dirties
                // itself during layout once it relayouts.)
                if (calm)
                  _header(buddy, header)
                else
                  AnimatedSize(
                    duration: AppConstants.animMedium,
                    curve: Curves.easeInOut,
                    alignment: Alignment.topCenter,
                    child: _header(buddy, header),
                  ),
                Expanded(child: child),
              ],
            ),
          ),
        );
      },
    );
  }
}
