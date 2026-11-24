import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../models/toilet_entry.dart';
import '../../../providers/diary_provider.dart';
import '../../../providers/entries_provider.dart';
import '../../../services/buddy/buddy_mood_logic.dart';
import '../../../utils/date_format_utils.dart';
import '../../../widgets/buddy/log_success_hero.dart';
import '../../../widgets/common/bb_button.dart';
import '../../../widgets/common/bb_slider.dart';
import '../../../widgets/common/date_time_chips.dart';
import '../../../widgets/common/tracker_screen_scaffold.dart';
import '../entry_logger.dart';

class ToiletTrackerScreen extends ConsumerStatefulWidget {
  const ToiletTrackerScreen({super.key, this.initialDate});

  final DateTime? initialDate;

  @override
  ConsumerState<ToiletTrackerScreen> createState() =>
      _ToiletTrackerScreenState();
}

class _ToiletTrackerScreenState extends ConsumerState<ToiletTrackerScreen>
    with EntryLogger {
  int _stoolType = 3;
  late DateTime _trackedAt = buildTrackedAt(widget.initialDate);
  bool _isSaving = false;

  /// Set once the entry is saved; shows the success screen.
  bool _saved = false;

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final entry = ToiletEntry(
      id: const Uuid().v4(),
      trackedAt: _trackedAt,
      stoolType: _stoolType,
    );
    final logged = await logEntry(
      kind: EntryKind.toilet,
      trackedAt: entry.trackedAt,
      sentiment: sentimentForToilet(entry),
      save: () => ref.read(entriesProvider.notifier).addToiletEntry(entry),
    );
    if (!mounted) return;
    if (!logged) return setState(() => _isSaving = false);
    ref.invalidate(diaryEntriesProvider(startOfDay(_trackedAt)));
    setState(() => _saved = true);
  }

  @override
  Widget build(BuildContext context) {
    final moment = _saved ? logMoment : null;
    // After a hard moment no celebration: calm, without the „!".
    final calm = moment?.sentiment == LogSentiment.bad;
    return TrackerScreenScaffold(
      title: 'Am Klo \u{1F4A9} gewesen?',
      showSuccess: moment != null,
      successMessage: calm
          ? 'Klo-Eintrag gespeichert.'
          : 'Klo-Eintrag gespeichert!',
      successCalm: calm,
      successIllustration: moment == null
          ? null
          : LogSuccessHero(moment: moment),
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
