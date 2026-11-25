import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../services/buddy/buddy_mood_logic.dart';
import '../../services/buddy/daily_care.dart';
import '../../services/buddy/log_moment.dart';
import 'buddy_reaction_view.dart';
import 'need_icon.dart';
import 'need_meter.dart';
import 'streak_flame.dart';

/// A need's circle charging from [from] to [to] in about
/// [AppConstants.careChargeDuration] (about 2 s), easing out
/// ([AppConstants.careChargeCurve]); under reduced motion it shows [to] at
/// once. It adds no semantics.
class ChargingMeter extends StatelessWidget {
  const ChargingMeter({
    super.key,
    required this.need,
    required this.from,
    required this.to,
    required this.size,
  });

  final CareNeed need;
  final double from;
  final double to;
  final double size;

  @override
  Widget build(BuildContext context) {
    final calm = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: calm ? to : from, end: to),
      duration: calm ? Duration.zero : AppConstants.careChargeDuration,
      curve: AppConstants.careChargeCurve,
      builder: (_, level, child) =>
          NeedMeter(need: need, level: level, size: size, child: child!),
      child: NeedIcon(need, size: size * AppConstants.careMeterIconShare),
    );
  }
}

/// The tracker success page's hero: the logged need's circle charging in
/// about 2 s (none for Klo), the flame next to „Tag n" when the entry is
/// today's first, and the Buddy reacting ([BuddyReactionView]), who gets
/// the height left over.
///
/// The flame glows as an ember while the circle charges and ignites once
/// the circle is full, „Tag n" fading in with it. Without a circle (Klo) it
/// ignites at once; under reduced motion all of it shows at once.
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

  /// Sets [_charged] once the circle is full.
  Timer? _charge;

  LogMoment get _moment => widget.moment;

  /// The streak day the ignite row shows; null without one.
  int? get _day =>
      _moment.sentiment == LogSentiment.bad ? null : _moment.ignitesDay;

  bool get _hasMeter => _moment.from != null && _moment.to != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Decided once, on the first build.
    if (_charged || _charge != null) return;
    if (!_hasMeter || _day == null || MediaQuery.disableAnimationsOf(context)) {
      _charged = true;
    } else {
      _charge = Timer(
        AppConstants.careChargeDuration,
        () => setState(() => _charged = true),
      );
    }
  }

  @override
  void dispose() {
    _charge?.cancel();
    super.dispose();
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
