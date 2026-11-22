import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../config/constants.dart';
import '../../../widgets/buddy/buddy.dart';

/// Hosts the registration steps under the Buddy: a [BuddyStage] of
/// [AppConstants.buddyWizardSize] above [child] (the wizard's pages).
///
/// [child] gets the rest of the height, but at least
/// [AppConstants.buddyWizardMinStepHeight]. When there is less room (the
/// keyboard is open on a small phone), the Buddy and the step scroll
/// together, so a focused text field can still be scrolled into view.
///
/// There is one host per wizard, so its controller drives exactly one
/// [AnimatedBuddy] while the pages change below it.
class BuddyStepHost extends StatelessWidget {
  const BuddyStepHost({
    super.key,
    required this.controller,
    required this.name,
    required this.child,
  });

  final BuddyController controller;

  /// The Buddy's name (semantics label).
  final String name;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const minHeight =
            AppConstants.buddyWizardSize +
            AppConstants.buddyWizardMinStepHeight;
        final height = constraints.hasBoundedHeight
            ? math.max(constraints.maxHeight, minHeight)
            : minHeight;
        return SingleChildScrollView(
          child: SizedBox(
            height: height,
            child: Column(
              children: [
                SizedBox(
                  height: AppConstants.buddyWizardSize,
                  child: BuddyStage(controller: controller, name: name),
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
