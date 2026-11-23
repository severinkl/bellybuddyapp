import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../config/constants.dart';
import '../../../widgets/buddy/buddy.dart';

/// How the Buddy makes room while the keyboard is open.
enum BuddyKeyboardStage {
  /// A small Buddy without his bubble
  /// ([AppConstants.buddyWizardCompactSize]).
  compact,

  /// No Buddy, so a form and its actions fit above the keyboard.
  hidden,
}

/// Hosts the registration steps under the Buddy: a [BuddyStage] above
/// [child] (the wizard's pages), [AppConstants.buddyWizardHeightFactor] of
/// the screen height, clamped to [AppConstants.buddyWizardSize] ..
/// [AppConstants.buddyWizardMaxSize].
///
/// While [keyboardOpen], the stage shrinks as [keyboardStage] says (animated,
/// instant under reduced motion). [child] gets the rest of the height, but
/// at least [AppConstants.buddyWizardMinStepHeight]; with less room the
/// Buddy and the step scroll together, so a focused field can still be
/// scrolled into view.
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

  final BuddyController controller;

  /// The Buddy's name (semantics label).
  final String name;

  final Widget child;

  /// Whether the soft keyboard is showing.
  final bool keyboardOpen;

  /// What the Buddy does while [keyboardOpen].
  final BuddyKeyboardStage keyboardStage;

  double _stageHeight(BuildContext context) => switch (keyboardStage) {
    _ when !keyboardOpen =>
      (MediaQuery.sizeOf(context).height * AppConstants.buddyWizardHeightFactor)
          .clamp(AppConstants.buddyWizardSize, AppConstants.buddyWizardMaxSize),
    BuddyKeyboardStage.compact => AppConstants.buddyWizardCompactSize,
    BuddyKeyboardStage.hidden => 0,
  };

  Widget _stage(double height) {
    if (height == 0) return const SizedBox(width: double.infinity);
    return SizedBox(
      height: height,
      // The compact Buddy has no bubble slot.
      child: BuddyStage(
        controller: controller,
        name: name,
        bubbleHeight: keyboardOpen ? 0 : AppConstants.buddyBubbleHeight,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stage = _stageHeight(context);
    final calm = MediaQuery.disableAnimationsOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final minHeight = stage + AppConstants.buddyWizardMinStepHeight;
        final height = constraints.hasBoundedHeight
            ? math.max(constraints.maxHeight, minHeight)
            : minHeight;
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: SizedBox(
            height: height,
            child: Column(
              children: [
                // Under reduced motion the stage resizes instantly. (Not an
                // AnimatedSize with a zero duration: that one re-dirties
                // itself during layout once it relayouts.)
                if (calm)
                  _stage(stage)
                else
                  AnimatedSize(
                    duration: AppConstants.animMedium,
                    curve: Curves.easeInOut,
                    alignment: Alignment.topCenter,
                    child: _stage(stage),
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
