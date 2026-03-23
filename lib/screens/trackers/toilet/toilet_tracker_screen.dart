import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../models/toilet_entry.dart';
import '../../../providers/entries_provider.dart';
import '../../../utils/save_helper.dart';
import '../../../widgets/common/bb_button.dart';
import '../../../widgets/common/bb_slider.dart';
import '../../../widgets/common/date_time_chips.dart';
import '../../../widgets/common/tracker_screen_scaffold.dart';

class ToiletTrackerScreen extends ConsumerStatefulWidget {
  const ToiletTrackerScreen({super.key});

  @override
  ConsumerState<ToiletTrackerScreen> createState() =>
      _ToiletTrackerScreenState();
}

class _ToiletTrackerScreenState extends ConsumerState<ToiletTrackerScreen> {
  int _stoolType = 3;
  DateTime _trackedAt = DateTime.now();
  bool _isSaving = false;
  bool _showSuccess = false;

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final entry = ToiletEntry(
      id: const Uuid().v4(),
      trackedAt: _trackedAt,
      stoolType: _stoolType,
    );
    final success = await saveWithFeedback(
      context,
      () => ref.read(entriesProvider.notifier).addToiletEntry(entry),
    );
    if (mounted) {
      if (success) {
        setState(() => _showSuccess = true);
      } else {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return TrackerScreenScaffold(
      title: 'Am Klo 💩 gewesen?',
      showSuccess: _showSuccess,
      successMessage: 'Toilettengang gespeichert!',
      successMascotAsset: AppConstants.mascotWink,
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
            ),

            const Spacer(),
            BbButton(
              label: 'speichern',
              isLoading: _isSaving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
