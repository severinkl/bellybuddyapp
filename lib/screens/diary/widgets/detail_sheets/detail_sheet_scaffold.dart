import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/app_theme.dart';
import '../../../../config/constants.dart';
import '../../../../providers/diary_provider.dart';
import '../../../../utils/date_format_utils.dart';
import '../../../../utils/save_helper.dart';
import '../../../../widgets/common/bb_button.dart';
import '../../../../widgets/common/date_time_chips.dart';

class DetailSheetScaffold extends StatefulWidget {
  final String title;

  /// When the entry was logged; while editing, the edited value.
  final DateTime trackedAt;
  final ScrollController scrollController;
  final bool canEdit;
  final bool isEditing;
  final bool saving;
  final VoidCallback? onEditPressed;
  final VoidCallback? onCancelPressed;
  final VoidCallback? onSavePressed;

  /// While editing, changes [trackedAt] (date and time chips). Null: the
  /// sheet shows the date only.
  final ValueChanged<DateTime>? onTrackedAtChanged;

  /// Deletes the entry. The sheet asks first, keeps open while it runs and
  /// closes once it succeeded; a failure is shown and the sheet stays.
  final Future<void> Function() onDelete;
  final Widget content;

  const DetailSheetScaffold({
    super.key,
    required this.title,
    required this.trackedAt,
    required this.scrollController,
    required this.canEdit,
    required this.isEditing,
    required this.saving,
    this.onEditPressed,
    this.onCancelPressed,
    this.onSavePressed,
    this.onTrackedAtChanged,
    required this.onDelete,
    required this.content,
  });

  @override
  State<DetailSheetScaffold> createState() => _DetailSheetScaffoldState();
}

class _DetailSheetScaffoldState extends State<DetailSheetScaffold> {
  bool _deleting = false;

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eintrag löschen?'),
        content: const Text('Der Eintrag wird aus deinem Tagebuch entfernt.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.destructive),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    final ok = await saveWithFeedback(
      context,
      widget.onDelete,
      errorMessage: 'Eintrag konnte nicht gelöscht werden.',
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onTrackedAtChanged = widget.onTrackedAtChanged;

    return SingleChildScrollView(
      controller: widget.scrollController,
      padding: AppConstants.paddingLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: AppTheme.fontSizeHeading,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (widget.canEdit && !widget.isEditing)
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: widget.onEditPressed,
                ),
            ],
          ),
          AppConstants.gap4,
          if (widget.isEditing && onTrackedAtChanged != null) ...[
            AppConstants.gap8,
            DateTimeChips(
              value: widget.trackedAt,
              onChanged: onTrackedAtChanged,
              chipColor: AppTheme.secondary,
            ),
          ] else
            Text(
              formatDateTimeFull(widget.trackedAt),
              style: const TextStyle(
                fontSize: AppTheme.fontSizeBody,
                color: AppTheme.mutedForeground,
              ),
            ),
          AppConstants.gap24,
          widget.content,
          AppConstants.gap24,
          if (widget.isEditing) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.saving ? null : widget.onCancelPressed,
                    child: const Text('Abbrechen'),
                  ),
                ),
                const SizedBox(width: AppConstants.spacing12),
                Expanded(
                  child: BbButton(
                    label: 'Speichern',
                    isLoading: widget.saving,
                    onPressed: widget.onSavePressed,
                  ),
                ),
              ],
            ),
          ] else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _deleting ? null : _delete,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.destructive,
                  side: const BorderSide(color: AppTheme.destructive),
                ),
                child: _deleting
                    ? const SizedBox(
                        width: AppConstants.spacing20,
                        height: AppConstants.spacing20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.destructive,
                        ),
                      )
                    : const Text('Eintrag löschen'),
              ),
            ),
        ],
      ),
    );
  }
}

/// Reloads the diary's shown day after an edit or delete from a detail
/// sheet, and [movedTo]'s day when the entry moved there.
void refreshDiaryDays(WidgetRef ref, {DateTime? movedTo}) {
  ref.invalidate(diaryEntriesProvider(ref.read(diaryDateProvider)));
  if (movedTo != null) {
    ref.invalidate(diaryEntriesProvider(startOfDay(movedTo)));
  }
}
