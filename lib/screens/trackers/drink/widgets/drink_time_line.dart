import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/app_theme.dart';
import '../../../../config/constants.dart';
import '../../../../providers/drink_tracker_provider.dart';
import '../../../../utils/date_format_utils.dart';
import '../../../../utils/drink_helpers.dart';
import '../../../../utils/reduced_motion.dart';
import '../../../../widgets/common/bb_tap_area.dart';
import '../../../../widgets/common/date_time_chips.dart';

/// „Heute, 14:30 · ändern": the entry's time, a disclosure that shows the
/// date and time chips under it.
class DrinkTimeLine extends ConsumerStatefulWidget {
  const DrinkTimeLine({super.key});

  static const toggleKey = Key('drink_time_line');

  @override
  ConsumerState<DrinkTimeLine> createState() => _DrinkTimeLineState();
}

class _DrinkTimeLineState extends ConsumerState<DrinkTimeLine> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    // The wall-clock time as stored: never converted (see DateTimeChips).
    final trackedAt = ref.watch(
      drinkTrackerProvider.select((s) => s.trackedAt),
    );

    final chips = _open
        ? Padding(
            padding: const EdgeInsets.only(top: AppConstants.spacingSm),
            child: DateTimeChips(
              value: trackedAt,
              onChanged: ref.read(drinkTrackerProvider.notifier).setTrackedAt,
            ),
          )
        : const SizedBox(width: double.infinity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BbTapArea(
          tapKey: DrinkTimeLine.toggleKey,
          label: 'Zeitpunkt',
          value:
              '${formatDateWeekdayLong(trackedAt)}, ${formatTime(trackedAt)}',
          expanded: _open,
          excludeChild: true,
          onTap: () => setState(() => _open = !_open),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.access_time,
                size: AppConstants.iconSizeSm,
                color: AppTheme.foreground,
              ),
              const SizedBox(width: AppConstants.spacing6),
              Flexible(
                child: Text(
                  '${DrinkHelpers.timeLabel(trackedAt, DateTime.now())} '
                  '· ändern',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: AppTheme.fontSizeBody,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.foreground,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Under reduced motion the chips appear at once (an AnimatedSize
        // with a zero duration re-dirties itself during layout).
        if (ReducedMotion.of(context))
          chips
        else
          AnimatedSize(
            duration: AppConstants.animDisclosure,
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: chips,
          ),
      ],
    );
  }
}
