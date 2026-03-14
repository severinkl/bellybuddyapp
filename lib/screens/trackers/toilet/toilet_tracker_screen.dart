import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../models/toilet_entry.dart';
import '../../../providers/entries_provider.dart';
import '../../../utils/save_helper.dart';
import '../../../widgets/common/bb_button.dart';
import '../../../widgets/common/bb_slider.dart';
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

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _trackedAt,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('de'),
    );
    if (date != null && mounted) {
      setState(() {
        _trackedAt = DateTime(
          date.year, date.month, date.day,
          _trackedAt.hour, _trackedAt.minute,
        );
      });
    }
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_trackedAt),
    );
    if (time != null && mounted) {
      setState(() {
        _trackedAt = DateTime(
          _trackedAt.year, _trackedAt.month, _trackedAt.day,
          time.hour, time.minute,
        );
      });
    }
  }

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
      successSubMessage: 'Dein Eintrag wurde erfolgreich erfasst.',
      successMascotAsset: AppConstants.mascotWink,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date & Time chips
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _DateTimeChip(
                    label: DateFormat('dd.MM.yyyy').format(_trackedAt),
                    icon: Icons.calendar_today_outlined,
                    onTap: _pickDate,
                  ),
                  const SizedBox(width: 8),
                  _DateTimeChip(
                    label: DateFormat('HH:mm').format(_trackedAt),
                    icon: Icons.access_time_outlined,
                    onTap: _pickTime,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Konsistenz label
            const Text(
              'Konsistenz?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.foreground,
              ),
            ),
            const SizedBox(height: 24),
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

class _DateTimeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _DateTimeChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppTheme.foreground,
              ),
            ),
            const SizedBox(width: 8),
            Icon(icon, size: 18, color: AppTheme.mutedForeground),
          ],
        ),
      ),
    );
  }
}
