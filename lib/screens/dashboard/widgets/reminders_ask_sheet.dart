import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../providers/notification_provider.dart';
import '../../../services/buddy/buddy_copy.dart';
import '../../../utils/logger.dart';
import '../../../widgets/buddy/buddy_ask_sheet.dart';

/// The Buddy asks again for reminders while they are off
/// ([RemindersAskSheet]), over the bottom bar. True for „Einschalten";
/// false for „Später" or when dismissed.
Future<bool> showRemindersAskSheet(BuildContext context) async =>
    await showBuddySheet<bool>(
      context,
      builder: (_) => const RemindersAskSheet(),
    ) ??
    false;

/// The Buddy's ask ([BuddyCopy.remindersAsk]) with what reminders do
/// ([BuddyCopy.remindersAskBody]); „Einschalten" pops true, „Später"
/// false.
class RemindersAskSheet extends StatelessWidget {
  const RemindersAskSheet({super.key});

  static const turnOnKey = Key('reminders_ask_turn_on');
  static const laterKey = Key('reminders_ask_later');

  @override
  Widget build(BuildContext context) {
    return BuddyAskSheet(
      line: BuddyCopy.remindersAsk,
      actions: BuddySheetActions(
        primaryKey: turnOnKey,
        primary: remindersTurnOnLabel,
        onPrimary: () => Navigator.pop(context, true),
        secondaryKey: laterKey,
        secondary: 'Später',
        onSecondary: () => Navigator.pop(context, false),
      ),
      child: const BuddySheetText(BuddyCopy.remindersAskBody),
    );
  }
}

/// The label of the action that turns reminders on (the Buddy's ask,
/// Ich's row).
const remindersTurnOnLabel = 'Einschalten';

/// What a SnackBar says when „Einschalten" got nowhere.
const remindersTurnOnFailure =
    'Das hat gerade nicht geklappt. Versuch es später nochmal.';

const _log = AppLogger('RemindersTurnOn');

/// „Einschalten" ([turnOnReminders]): when nothing happened (no profile
/// yet, the settings didn't open, saving failed) a SnackBar on [context]'s
/// messenger says so. Never throws.
Future<RemindersTurnOn> turnOnRemindersOrSay(
  BuildContext context,
  WidgetRef ref,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  var outcome = RemindersTurnOn.failed;
  try {
    outcome = await turnOnReminders(ref);
  } catch (e, st) {
    _log.error('turning the reminders on failed', e, st);
  }
  if (outcome == RemindersTurnOn.failed) {
    messenger?.showSnackBar(
      const SnackBar(content: Text(remindersTurnOnFailure)),
    );
  }
  return outcome;
}
