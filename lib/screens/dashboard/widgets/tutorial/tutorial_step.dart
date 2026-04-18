import 'package:flutter/widgets.dart';

import '../../../../config/constants.dart';

/// Whether the tooltip bubble for a step should be anchored above or below
/// its target. The overlay may override this at measure-time if the chosen
/// side has insufficient vertical space.
enum TooltipAnchor { above, below }

/// One step in the dashboard onboarding tour.
class TutorialStep {
  /// Key attached to the element this step highlights.
  final GlobalKey targetKey;

  /// Styled text spans shown in the tooltip bubble. Bold emphasis is baked
  /// into the span list (via TextSpan with FontWeight.w700).
  final List<InlineSpan> richText;

  /// Corner radius used for the spotlight cutout around the target.
  final double targetRadius;

  /// Preferred side to anchor the tooltip bubble on.
  final TooltipAnchor preferredAnchor;

  const TutorialStep({
    required this.targetKey,
    required this.richText,
    this.targetRadius = AppConstants.radiusMd,
    this.preferredAnchor = TooltipAnchor.below,
  });
}
