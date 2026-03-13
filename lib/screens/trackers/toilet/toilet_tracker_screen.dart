import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../models/toilet_entry.dart';
import '../../../providers/entries_provider.dart';
import '../../../router/route_names.dart';
import '../../../widgets/common/bb_button.dart';
import '../../../utils/save_helper.dart';
import '../../../widgets/common/bb_slider.dart';
import '../../../widgets/common/bb_success_overlay.dart';
import '../../../widgets/common/date_time_picker_tile.dart';

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

  static const _descriptions = AppConstants.stoolTypeDescriptions;

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
    if (_showSuccess) {
      return BbSuccessOverlay(
        message: 'Toilettengang gespeichert!',
        onDismissed: () {
          if (mounted) context.go(RoutePaths.dashboard);
        },
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.screenBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.screenBackground,
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
            DateTimePickerTile(
              value: _trackedAt,
              onChanged: (dt) => setState(() => _trackedAt = dt),
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
