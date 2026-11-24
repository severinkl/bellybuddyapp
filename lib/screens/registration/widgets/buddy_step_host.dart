import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../config/constants.dart';
import '../../../widgets/buddy/buddy.dart';
import '../../../widgets/buddy/buddy_side_header.dart';

/// Hosts the registration steps under the Buddy. A header runs across the
/// top: the Buddy on the left ([AppConstants.buddyWizardBuddyWidth] wide)
/// and his speech bubble on the right, its tail pointing at his face. The
/// bubble asks each step's question, so the steps carry no headline of
/// their own. [child] (the wizard's pages) fills the rest.
///
/// While [keyboardOpen], or always when [compact], the header is compact: a
/// smaller Buddy ([AppConstants.buddyWizardCompactSize] tall) with his bubble
/// in a [AppConstants.buddyWizardCompactHeaderHeight] header (the change is
/// animated, instant under reduced motion). [child] gets the rest of the
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
    this.compact = false,
  });

  static const headerKey = Key('buddy_step_host_header');

  final BuddyController controller;

  /// The Buddy's name (semantics label).
  final String name;

  final Widget child;

  /// Whether the soft keyboard is showing.
  final bool keyboardOpen;

  /// Whether the header stays compact with the keyboard closed too (steps
  /// whose fields open it right away).
  final bool compact;

  /// The Buddy's size in the header and the header's height.
  ({Size buddy, double height}) get _header => keyboardOpen || compact
      ? (
          buddy: const Size(
            AppConstants.buddyWizardCompactSize * kBuddyStageAspect,
            AppConstants.buddyWizardCompactSize,
          ),
          height: AppConstants.buddyWizardCompactHeaderHeight,
        )
      : (
          buddy: BuddySideHeader.defaultBuddySize,
          height: BuddySideHeader.defaultBuddySize.height,
        );

  @override
  Widget build(BuildContext context) {
    final (:buddy, height: headerHeight) = _header;
    final header = BuddySideHeader(
      key: headerKey,
      controller: controller,
      name: name,
      buddySize: buddy,
      height: headerHeight,
    );
    final calm = MediaQuery.disableAnimationsOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final minHeight = headerHeight + AppConstants.buddyWizardMinStepHeight;
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
                  header
                else
                  AnimatedSize(
                    duration: AppConstants.animMedium,
                    curve: Curves.easeInOut,
                    alignment: Alignment.topCenter,
                    child: header,
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
