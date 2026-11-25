import 'dart:math' as math;
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../services/buddy/buddy_mood_logic.dart';
import '../../services/buddy/daily_care.dart';
import '../../services/buddy/log_moment.dart';
import '../../utils/gut_feeling_rating.dart';
import 'buddy_reaction_view.dart';
import 'need_icon.dart';
import 'need_meter.dart';
import 'streak_flame.dart';

/// A need's circle charging from [from] to [to] in about
/// [AppConstants.careChargeDuration] (about 2 s), easing out
/// ([AppConstants.careChargeCurve]), then calling [onCharged]. Under
/// reduced motion (also when it turns on mid-charge) it shows [to] at once;
/// then, and with nothing to charge ([from] == [to]), [onCharged] is never
/// called. Its icon is [need]'s (for Bauchgefühl, the belly with
/// [gutFeeling]'s mouth, [NeedIcon.gutFeeling]). It adds no semantics.
class ChargingMeter extends StatelessWidget {
  const ChargingMeter({
    super.key,
    required this.need,
    required this.from,
    required this.to,
    required this.size,
    this.gutFeeling,
    this.onCharged,
  });

  final CareNeed need;
  final double from;
  final double to;
  final double size;
  final GutFeelingRatingLevel? gutFeeling;
  final VoidCallback? onCharged;

  @override
  Widget build(BuildContext context) {
    final calm = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      // A charge reduced motion cuts short starts over, full at once.
      key: ValueKey(calm),
      tween: Tween(begin: calm ? to : from, end: to),
      duration: calm ? Duration.zero : AppConstants.careChargeDuration,
      curve: AppConstants.careChargeCurve,
      onEnd: onCharged,
      builder: (_, level, child) =>
          NeedMeter(need: need, level: level, size: size, child: child!),
      child: NeedIcon(need, gutFeeling: gutFeeling),
    );
  }
}

/// The tracker success page's hero: the logged need's circle charging in
/// about 2 s (none for Klo), the flame next to „Tag n" when the entry is
/// today's first, and the Buddy reacting ([BuddyReactionView]), who gets
/// the height left over.
///
/// The flame glows as an ember while the circle charges and ignites once
/// the circle is full ([ChargingMeter.onCharged]), „Tag n" fading in with
/// it. With nothing to charge (no circle, as for Klo, or the same level
/// again) it ignites at once; under reduced motion (also when it turns on
/// mid-charge) all of it shows at once.
///
/// The calm page after a hard moment ([LogSentiment.bad]) cheers no
/// progress: it shows no ignite row. Nothing is scaled: the circle takes a
/// share of the slot, and in a slot shorter than
/// [AppConstants.logSuccessHeroStackedMinHeight] it stands beside „Tag n"
/// instead of above it, so the Buddy keeps a body.
class LogSuccessHero extends StatefulWidget {
  const LogSuccessHero({super.key, required this.moment, this.foodImageBytes});

  static const igniteKey = Key('log_success_ignite');

  /// What was logged and what it did.
  final LogMoment moment;

  /// The meal photo the Buddy eats ([BuddyReactionView.foodImageBytes]).
  final Uint8List? foodImageBytes;

  @override
  State<LogSuccessHero> createState() => _LogSuccessHeroState();
}

class _LogSuccessHeroState extends State<LogSuccessHero> {
  /// Whether the circle is full (or there is none to wait for): the flame
  /// is lit and „Tag n" shows.
  bool _charged = false;

  LogMoment get _moment => widget.moment;

  /// The streak day the ignite row shows; null without one.
  int? get _day =>
      _moment.sentiment == LogSentiment.bad ? null : _moment.ignitesDay;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Nothing to wait for: no circle or nothing it charges, no flame, or
    // animations off (also once they turn off mid-charge).
    final from = _moment.from;
    if (from == null ||
        from == _moment.to ||
        _day == null ||
        MediaQuery.disableAnimationsOf(context)) {
      _charged = true;
    }
  }

  void _onCharged() {
    if (!_charged) setState(() => _charged = true);
  }

  @override
  Widget build(BuildContext context) {
    final from = _moment.from;
    final to = _moment.to;
    final day = _day;
    final calm = MediaQuery.disableAnimationsOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final meter = from == null || to == null
            ? null
            : ChargingMeter(
                need: _moment.need,
                from: from,
                to: to,
                size: math.min(
                  AppConstants.careChargeSize,
                  height * AppConstants.careChargeHeightShare,
                ),
                gutFeeling: _moment.gutFeeling,
                onCharged: _onCharged,
              );
        final ignite = day == null
            ? null
            : Row(
                key: LogSuccessHero.igniteKey,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Lit from the start it ignites on mount; lit later, as
                  // the circle fills, it ignites then.
                  StreakFlame(
                    streak: day,
                    lit: _charged,
                    height: AppConstants.streakFlameIgniteHeight,
                    igniteOnMount: _charged,
                    onPrimary: true,
                  ),
                  const SizedBox(width: AppConstants.spacingSm),
                  // Laid out while hidden: nothing jumps as it fades in.
                  AnimatedOpacity(
                    opacity: _charged ? 1 : 0,
                    duration: calm ? Duration.zero : AppConstants.animNormal,
                    child: Text(
                      'Tag $day',
                      style: const TextStyle(
                        fontSize: AppTheme.fontSizeTitleLG,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryForeground,
                      ),
                    ),
                  ),
                ],
              );
        final sideBySide = height < AppConstants.logSuccessHeroStackedMinHeight;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (sideBySide && meter != null && ignite != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  meter,
                  const SizedBox(width: AppConstants.spacingMd),
                  ignite,
                ],
              )
            else ...[
              ?meter,
              // Also the room the flame's ignite burst draws into above it.
              if (ignite != null) ...[AppConstants.gap8, ignite],
            ],
            AppConstants.gap8,
            Flexible(
              child: BuddyReactionView(
                kind: _moment.kind,
                sentiment: _moment.sentiment,
                foodImageBytes: widget.foodImageBytes,
                line: _moment.buddyLine,
              ),
            ),
          ],
        );
      },
    );
  }
}
