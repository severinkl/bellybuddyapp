import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../models/toilet_entry.dart';
import '../../../providers/buddy_events_provider.dart';
import '../../../providers/buddy_provider.dart';
import '../../../providers/diary_provider.dart';
import '../../../providers/entries_provider.dart';
import '../../../providers/log_moment.dart';
import '../../../services/buddy/buddy_mood_logic.dart';
import '../../../services/buddy/log_moment.dart';
import '../../../utils/date_format_utils.dart';
import '../../../utils/save_helper.dart';
import '../../../widgets/buddy/log_success_hero.dart';
import '../../../widgets/common/bb_button.dart';
import '../../../widgets/common/bb_slider.dart';
import '../../../widgets/common/date_time_chips.dart';
import '../../../widgets/common/tracker_screen_scaffold.dart';

class ToiletTrackerScreen extends ConsumerStatefulWidget {
  const ToiletTrackerScreen({super.key, this.initialDate});

  final DateTime? initialDate;

  @override
  ConsumerState<ToiletTrackerScreen> createState() =>
      _ToiletTrackerScreenState();
}

class _ToiletTrackerScreenState extends ConsumerState<ToiletTrackerScreen> {
  int _stoolType = 3;
  late DateTime _trackedAt = buildTrackedAt(widget.initialDate);
  bool _isSaving = false;

  /// Set once the entry is saved; shows the success screen.
  LogSentiment? _savedSentiment;

  /// What the entry does, as it is saved; the success page shows it.
  LogMoment? _moment;

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final entry = ToiletEntry(
      id: const Uuid().v4(),
      trackedAt: _trackedAt,
      stoolType: _stoolType,
    );
    _moment = captureLogMoment(
      ref,
      kind: EntryKind.toilet,
      trackedAt: entry.trackedAt,
    );
    final success = await saveWithFeedback(
      context,
      () => ref.read(entriesProvider.notifier).addToiletEntry(entry),
    );
    if (mounted) {
      if (success) {
        ref.invalidate(diaryEntriesProvider(startOfDay(_trackedAt)));
        final sentiment = sentimentForToilet(entry);
        ref
            .read(buddyEventsProvider.notifier)
            .emit(
              BuddyLogEvent(
                EntryKind.toilet,
                sentiment,
                at: ref.read(buddyClockProvider)(),
                trackedAt: entry.trackedAt,
              ),
            );
        setState(() => _savedSentiment = sentiment);
      } else {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final savedSentiment = _savedSentiment;
    final moment = _moment;
    return TrackerScreenScaffold(
      title: 'Am Klo \u{1F4A9} gewesen?',
      showSuccess: savedSentiment != null,
      // After a hard moment no celebration: calm, without the „!".
      successMessage: savedSentiment == LogSentiment.bad
          ? 'Klo-Eintrag gespeichert.'
          : 'Klo-Eintrag gespeichert!',
      successCalm: savedSentiment == LogSentiment.bad,
      successIllustration: savedSentiment == null || moment == null
          ? null
          : LogSuccessHero(
              moment: moment,
              kind: EntryKind.toilet,
              sentiment: savedSentiment,
            ),
      body: Padding(
        padding: AppConstants.paddingLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date & Time chips
            DateTimeChips(
              value: _trackedAt,
              onChanged: (dt) => setState(() => _trackedAt = dt),
            ),
            AppConstants.gap32,

            // Konsistenz label
            const Text(
              'Konsistenz?',
              style: TextStyle(
                fontSize: AppTheme.fontSizeTitle,
                fontWeight: FontWeight.w700,
                color: AppTheme.foreground,
              ),
            ),
            AppConstants.gap24,
            BbSlider(
              value: _stoolType,
              min: 1,
              max: 5,
              variant: SliderVariant.stool,
              onChanged: (v) => setState(() => _stoolType = v),
              leftLabel: 'sehr hart',
              centerLabel: 'normal',
              rightLabel: 'flüssig',
              semanticLabel: 'Konsistenz',
              semanticValue: (v) =>
                  '${AppConstants.stoolTypeDescriptions[v]}, $v von 5',
            ),

            const Spacer(),
            BbButton(
              label: 'Speichern',
              isLoading: _isSaving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
