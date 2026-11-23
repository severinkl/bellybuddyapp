import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../models/user_profile.dart';
import '../../../services/reminder_copy.dart';
import '../../../utils/date_format_utils.dart';
import '../../registration/widgets/step_field_label.dart';

/// The reminder step's explanation before the system dialog: how the Buddy
/// will get in touch (previews of his real reminders at the profile's
/// times), when by default, and an example week showing what reminders are
/// for. Makes no claim about outcomes.
class ReminderPreview extends StatelessWidget {
  const ReminderPreview({
    super.key,
    required this.buddyName,
    required this.profile,
  });

  final String buddyName;

  /// Reminder times and switches; the model defaults when unknown.
  final UserProfile? profile;

  static int _hour(String time) => int.tryParse(time.split(':').first) ?? 18;

  @override
  Widget build(BuildContext context) {
    final p = profile ?? const UserProfile();
    final meal = p.remindersEnabled && p.mealReminderTimes.isNotEmpty
        ? p.mealReminderTimes.first
        : null;
    final mood = p.dailySummaryEnabled && p.moodReminderTimes.isNotEmpty
        ? p.moodReminderTimes.first
        : null;
    // The previews show the times; the note says where to change them.
    final note = meal == null && mood == null
        ? 'Wann ich mich melde, stellst du in den Einstellungen ein.'
        : 'Die Zeiten änderst du jederzeit in den Einstellungen.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const StepFieldLabel('So melde ich mich'),
        AppConstants.gap8,
        if (meal != null) ...[
          NotificationPreview(
            time: meal,
            body: ReminderCopy.previewMealBody(_hour(meal), buddyName),
          ),
          AppConstants.gap8,
        ],
        if (mood != null) ...[
          NotificationPreview(
            time: mood,
            body: ReminderCopy.previewMoodBody(_hour(mood), buddyName),
          ),
          AppConstants.gap8,
        ],
        Text(
          note,
          style: const TextStyle(
            fontSize: AppTheme.fontSizeBody,
            height: 1.4,
            color: AppTheme.mutedForeground,
          ),
        ),
        AppConstants.gap16,
        const ReminderExampleWeek(),
      ],
    );
  }
}

/// An iOS-style banner: app icon, „Belly Buddy", [time], and [body].
class NotificationPreview extends StatelessWidget {
  const NotificationPreview({
    super.key,
    required this.time,
    required this.body,
  });

  final String time;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Beispiel-Mitteilung um $time: $body',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            AppConstants.spacing14,
            AppConstants.spacing10,
            AppConstants.spacing14,
            AppConstants.spacing12,
          ),
          decoration: BoxDecoration(
            color: AppTheme.notificationCard,
            borderRadius: BorderRadius.circular(
              AppConstants.notificationPreviewRadius,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppConstants.radiusXs),
                    child: Image.asset(
                      AppConstants.appIconPath,
                      width: AppConstants.notificationPreviewIconSize,
                      height: AppConstants.notificationPreviewIconSize,
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingSm),
                  const Expanded(
                    child: Text(
                      'Belly Buddy',
                      style: TextStyle(
                        fontSize: AppTheme.fontSizeCaptionLG,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.notificationForeground,
                      ),
                    ),
                  ),
                  Text(
                    time,
                    style: const TextStyle(
                      fontSize: AppTheme.fontSizeCaptionLG,
                      color: AppTheme.notificationMuted,
                    ),
                  ),
                ],
              ),
              AppConstants.gap4,
              Text(
                body,
                style: const TextStyle(
                  fontSize: AppTheme.fontSizeBody,
                  height: 1.35,
                  color: AppTheme.notificationForeground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A clearly labelled example of one week's entries without and with
/// reminders: dots only, no numbers, no outcome claim.
class ReminderExampleWeek extends StatelessWidget {
  const ReminderExampleWeek({super.key});

  static const _without = [true, false, false, true, false, false, true];
  static const _with = [true, true, true, true, true, true, true];

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Beispielwoche: ohne Erinnerung mit Lücken, mit Erinnerung jeden '
          'Tag eingetragen. Weniger Lücken, und Zusammenhänge zwischen Essen '
          'und Bauch sind leichter zu sehen.',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            AppConstants.spacing14,
            AppConstants.spacing10,
            AppConstants.spacing14,
            AppConstants.spacing12,
          ),
          decoration: BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.circular(AppConstants.radiusLg),
            border: Border.all(
              color: AppTheme.border,
              width: AppConstants.borderWidthMd,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Eine Woche Einträge',
                      style: TextStyle(
                        fontSize: AppTheme.fontSizeCaptionLG,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.foreground,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.spacing6,
                      vertical: AppConstants.spacing2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.secondary,
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusXs,
                      ),
                    ),
                    child: const Text(
                      'BEISPIEL',
                      style: TextStyle(
                        fontSize: AppTheme.fontSizeXS,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.7,
                        color: AppTheme.mutedForeground,
                      ),
                    ),
                  ),
                ],
              ),
              AppConstants.gap8,
              _row(const SizedBox.shrink(), [
                for (final d in kWeekdayShortNames)
                  Text(
                    d,
                    style: const TextStyle(
                      fontSize: AppTheme.fontSizeSM,
                      color: AppTheme.mutedForeground,
                    ),
                  ),
              ]),
              AppConstants.gap6,
              _row(_label('ohne Erinnerung'), [
                for (final on in _without) _Dot(on),
              ]),
              AppConstants.gap6,
              _row(_label('mit Erinnerung'), [
                for (final on in _with) _Dot(on),
              ]),
              AppConstants.gap8,
              const Text(
                'Weniger Lücken, und Zusammenhänge zwischen Essen und Bauch '
                'sind leichter zu sehen.',
                style: TextStyle(
                  fontSize: AppTheme.fontSizeCaption,
                  height: 1.35,
                  color: AppTheme.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _label(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: AppTheme.fontSizeCaption,
      color: AppTheme.mutedForeground,
    ),
  );

  static Widget _row(Widget label, List<Widget> cells) => Row(
    children: [
      SizedBox(width: AppConstants.reminderExampleLabelWidth, child: label),
      for (final cell in cells) Expanded(child: Center(child: cell)),
    ],
  );
}

class _Dot extends StatelessWidget {
  const _Dot(this.on);

  final bool on;

  @override
  Widget build(BuildContext context) => Container(
    width: AppConstants.reminderExampleDotSize,
    height: AppConstants.reminderExampleDotSize,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: on ? AppTheme.primary : AppTheme.background,
      border: Border.all(
        color: on ? AppTheme.primary : AppTheme.border,
        width: AppConstants.borderWidthMd,
      ),
    ),
  );
}
