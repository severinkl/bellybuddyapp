import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../config/app_theme.dart';
import '../../../models/toilet_entry.dart';
import '../../../providers/entries_provider.dart';
import '../../../router/route_names.dart';
import '../../../widgets/common/bb_button.dart';
import '../../../widgets/common/bb_slider.dart';
import '../../../widgets/common/bb_success_overlay.dart';

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

  static const _descriptions = {
    1: 'Sehr hart',
    2: 'Hart',
    3: 'Normal',
    4: 'Weich',
    5: 'Flüssig',
  };

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final entry = ToiletEntry(
        id: const Uuid().v4(),
        trackedAt: _trackedAt,
        stoolType: _stoolType,
      );
      await ref.read(entriesProvider.notifier).addToiletEntry(entry);
      setState(() => _showSuccess = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fehler beim Speichern.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showSuccess) {
      return BbSuccessOverlay(
        message: 'Toilettengang gespeichert!',
        onDismissed: () {
          if (mounted) context.go(RoutePaths.dashboard);
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        title: const Text('Am Klo gewesen?'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            const Text(
              'Konsistenz?',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppTheme.foreground,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _descriptions[_stoolType] ?? 'Normal',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.stoolColor(_stoolType),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
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
            const SizedBox(height: 32),

            // Date/Time
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.access_time),
              title: Text(
                '${_trackedAt.day}.${_trackedAt.month}.${_trackedAt.year} '
                '${_trackedAt.hour.toString().padLeft(2, '0')}:'
                '${_trackedAt.minute.toString().padLeft(2, '0')} Uhr',
              ),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _trackedAt,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  locale: const Locale('de'),
                );
                if (date != null && mounted) {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(_trackedAt),
                  );
                  if (time != null) {
                    setState(() {
                      _trackedAt = DateTime(
                        date.year, date.month, date.day,
                        time.hour, time.minute,
                      );
                    });
                  }
                }
              },
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
