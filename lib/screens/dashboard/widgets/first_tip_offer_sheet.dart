import 'package:material_ui/material_ui.dart';

import '../../../widgets/buddy/buddy_ask_sheet.dart';
import '../../../widgets/common/weekly_tips_switch.dart';

/// The answer to the day-3 offer of a first tip.
enum FirstTipAnswer { yes, no }

/// The Buddy's day-3 offer of a first tip ([FirstTipOfferSheet]), over the
/// bottom bar: the answer, or null when dismissed.
Future<FirstTipAnswer?> showFirstTipOfferSheet(BuildContext context) =>
    showBuddySheet<FirstTipAnswer>(
      context,
      builder: (_) => const FirstTipOfferSheet(),
    );

/// The Buddy offers to make a first tip ([line]); the body says that „Ja,
/// gern" switches the weekly tips on, what that sends, and where to switch
/// them off. Nothing is sent from here: the answer is the caller's.
class FirstTipOfferSheet extends StatelessWidget {
  const FirstTipOfferSheet({super.key});

  static const yesKey = Key('first_tip_yes'), noKey = Key('first_tip_no');

  static const line =
      'Ich hab genug für deinen ersten Tipp! Soll ich ihn dir machen? ✨';
  static const body =
      'Dann schalte ich die wöchentlichen Tipps ein: jeden Montag 2–3 Tipps. '
      '${WeeklyTipsSwitch.sentence} Ausschalten kannst du sie jederzeit unter '
      'Entdecken oder in den Einstellungen.';
  static const yes = 'Ja, gern', no = 'Nein, danke';

  @override
  Widget build(BuildContext context) {
    return BuddyAskSheet(
      line: line,
      actions: BuddySheetActions(
        primaryKey: yesKey,
        primary: yes,
        onPrimary: () => Navigator.pop(context, FirstTipAnswer.yes),
        secondaryKey: noKey,
        secondary: no,
        onSecondary: () => Navigator.pop(context, FirstTipAnswer.no),
      ),
      child: const BuddySheetText(body),
    );
  }
}
