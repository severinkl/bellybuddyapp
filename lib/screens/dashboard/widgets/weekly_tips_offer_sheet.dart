import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../widgets/buddy/buddy_ask_sheet.dart';
import '../../../widgets/common/bb_button.dart';
import '../../../widgets/common/weekly_tips_switch.dart';

/// The Buddy's one-time offer of the weekly tips ([WeeklyTipsOfferSheet]),
/// over the bottom bar. True for „Zu den Tipps"; false for „Später" or when
/// dismissed.
Future<bool> showWeeklyTipsOfferSheet(BuildContext context) async =>
    await showBuddySheet<bool>(
      context,
      builder: (_) => const WeeklyTipsOfferSheet(),
    ) ??
    false;

/// The Buddy asks whether he may send tips every Monday ([line]); the body
/// says where they are switched on and what that sends; „Zu den Tipps"
/// pops true, „Später" false.
class WeeklyTipsOfferSheet extends StatelessWidget {
  const WeeklyTipsOfferSheet({super.key});

  static const openKey = Key('weekly_tips_offer_open');
  static const laterKey = Key('weekly_tips_offer_later');

  static const line =
      'Ich seh schon erste Muster! Magst du jeden Montag Tipps von mir? ✨';
  static const body =
      'Unter Entdecken kannst du sie einschalten. ${WeeklyTipsSwitch.sentence}';

  @override
  Widget build(BuildContext context) {
    return BuddyAskSheet(
      line: line,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppTheme.fontSizeBody,
              height: AppTheme.lineHeightBody,
              color: AppTheme.mutedForeground,
            ),
          ),
          AppConstants.gap16,
          BbButton(
            tapKey: openKey,
            label: 'Zu den Tipps',
            onPressed: () => Navigator.pop(context, true),
          ),
          AppConstants.gap8,
          TextButton(
            key: laterKey,
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.mutedForeground,
            ),
            child: const Text('Später'),
          ),
        ],
      ),
    );
  }
}
