import 'package:material_ui/material_ui.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';
import 'buddy_controller.dart';

/// The Buddy's speech bubble: shows [BuddyController.bubble] and pops each
/// new `say()` in with a scale + fade (instant under reduced motion).
/// Rebuilds only when the bubble changes, not on every frame.
class BuddySpeechBubble extends StatelessWidget {
  const BuddySpeechBubble({
    super.key,
    required this.controller,
    this.maxWidth = AppConstants.buddyBubbleMaxWidth,
  });

  final BuddyController controller;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final calm = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final bubble = controller.bubbleListenable;
    return ListenableBuilder(
      listenable: bubble,
      builder: (context, _) {
        final (:text, :id) = bubble.value;
        return AnimatedSwitcher(
          duration: calm || controller.reducedMotion
              ? Duration.zero
              : AppConstants.animNormal,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: animation,
              alignment: Alignment.bottomCenter,
              child: child,
            ),
          ),
          child: text == null
              ? const SizedBox.shrink()
              : _Bubble(key: ValueKey(id), text: text, maxWidth: maxWidth),
        );
      },
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({super.key, required this.text, required this.maxWidth});

  final String text;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppConstants.radiusRound),
            border: Border.all(
              color: AppTheme.buddyOutline,
              width: AppConstants.borderWidthLg,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacing12,
              vertical: AppConstants.spacingSm,
            ),
            child: Text(
              text,
              softWrap: true,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.foreground,
                fontSize: AppTheme.fontSizeBodyLG,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
