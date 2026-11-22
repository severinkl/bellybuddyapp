import 'package:material_ui/material_ui.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';

/// Compact streak indicator: "🔥 5 Tage" plus an optional "🛡 2" saver count.
///
/// Muted while today is not yet counted; pops when [streak] increases.
class StreakChip extends StatefulWidget {
  const StreakChip({
    super.key,
    required this.streak,
    required this.savers,
    required this.todayCounted,
  });

  final int streak;
  final int savers;
  final bool todayCounted;

  @override
  State<StreakChip> createState() => _StreakChipState();
}

class _StreakChipState extends State<StreakChip>
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
  void didUpdateWidget(StreakChip old) {
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
  Widget build(BuildContext context) {
    final muted = !widget.todayCounted && widget.streak > 0;
    final days = '${widget.streak} ${widget.streak == 1 ? 'Tag' : 'Tage'}';
    final label = '🔥 $days${widget.savers > 0 ? '  🛡 ${widget.savers}' : ''}';
    final semantics = [
      'Serie: $days',
      if (widget.savers > 0)
        '${widget.savers} ${widget.savers == 1 ? 'Schutz' : 'Schutzschilde'}',
      if (muted) 'Heute noch offen',
    ].join(', ');
    final color = muted ? AppTheme.mutedForeground : AppTheme.foreground;

    Widget chip = Semantics(
      label: semantics,
      excludeSemantics: true,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacing12,
            vertical: AppConstants.spacing6,
          ),
          decoration: BoxDecoration(
            color: muted ? AppTheme.muted : AppTheme.secondary,
            borderRadius: BorderRadius.circular(AppConstants.radiusFull),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: AppTheme.fontSizeBody,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ),
    );
    if (muted) {
      chip = Tooltip(message: 'Heute noch offen', child: chip);
    }
    return chip;
  }
}
