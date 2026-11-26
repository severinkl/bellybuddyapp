import 'package:material_ui/material_ui.dart';

import '../../config/constants.dart';

/// Pops [child] once (up to [AppConstants.streakChipPopScale] and back)
/// whenever [streak] increases; not under reduced motion.
class StreakPop extends StatefulWidget {
  const StreakPop({super.key, required this.streak, required this.child});

  final int streak;
  final Widget child;

  @override
  State<StreakPop> createState() => _StreakPopState();
}

class _StreakPopState extends State<StreakPop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: AppConstants.animMedium,
  );
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: AppConstants.streakChipPopScale),
      weight: 1,
    ),
    TweenSequenceItem(
      tween: Tween(begin: AppConstants.streakChipPopScale, end: 1.0),
      weight: 1,
    ),
  ]).animate(CurvedAnimation(parent: _pop, curve: Curves.easeOut));

  @override
  void didUpdateWidget(StreakPop old) {
    super.didUpdateWidget(old);
    if (widget.streak > old.streak &&
        !MediaQuery.disableAnimationsOf(context)) {
      _pop.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ScaleTransition(scale: _scale, child: widget.child);
}
