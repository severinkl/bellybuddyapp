import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../widgets/buddy/buddy.dart';
import '../../../widgets/common/bb_button.dart';
import '../../../widgets/common/bb_drag_handle.dart';
import '../../../widgets/common/weekly_tips_switch.dart';

/// The Buddy's one-time offer of the weekly tips ([WeeklyTipsOfferSheet]),
/// over the bottom bar. True for „Zu den Tipps"; false for „Später" or when
/// dismissed.
Future<bool> showWeeklyTipsOfferSheet(BuildContext context) async {
  final open = await showModalBottomSheet<bool>(
    context: context,
    // Over the bottom bar too (it opens from Home's tab).
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: false,
    builder: (_) => const WeeklyTipsOfferSheet(),
  );
  return open ?? false;
}

/// The Buddy asks whether he may send tips every Monday ([line]); the body
/// says where they are switched on and what that sends; „Zu den Tipps"
/// pops true, „Später" false.
class WeeklyTipsOfferSheet extends StatefulWidget {
  const WeeklyTipsOfferSheet({super.key});

  static const openKey = Key('weekly_tips_offer_open');
  static const laterKey = Key('weekly_tips_offer_later');

  static const line =
      'Ich seh schon erste Muster! Magst du jeden Montag Tipps von mir? ✨';
  static const body =
      'Unter Entdecken kannst du sie einschalten. ${WeeklyTipsSwitch.sentence}';

  @override
  State<WeeklyTipsOfferSheet> createState() => _WeeklyTipsOfferSheetState();
}

class _WeeklyTipsOfferSheetState extends State<WeeklyTipsOfferSheet> {
  final BuddyController _buddy = BuddyController(mood: BuddyMood.happy);

  @override
  void initState() {
    super.initState();
    // The Buddy asks; the sheet has no title of its own.
    _buddy.say(WeeklyTipsOfferSheet.line, duration: null);
  }

  @override
  void dispose() {
    _buddy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: AppConstants.paddingLg,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const BbDragHandle(color: AppTheme.border),
            AppConstants.gap16,
            SizedBox(
              height: AppConstants.streakSheetBuddyHeight,
              child: BuddyStage(controller: _buddy),
            ),
            AppConstants.gap16,
            const Text(
              WeeklyTipsOfferSheet.body,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppTheme.fontSizeBody,
                height: AppTheme.lineHeightBody,
                color: AppTheme.mutedForeground,
              ),
            ),
            AppConstants.gap16,
            BbButton(
              tapKey: WeeklyTipsOfferSheet.openKey,
              label: 'Zu den Tipps',
              onPressed: () => Navigator.pop(context, true),
            ),
            AppConstants.gap8,
            TextButton(
              key: WeeklyTipsOfferSheet.laterKey,
              onPressed: () => Navigator.pop(context, false),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.mutedForeground,
              ),
              child: const Text('Später'),
            ),
          ],
        ),
      ),
    );
  }
}
