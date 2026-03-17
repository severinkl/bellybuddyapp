import 'package:flutter/material.dart';
import '../../../../config/app_theme.dart';
import '../../../../config/constants.dart';
import '../../../../utils/date_format_utils.dart';

class DetailSheetScaffold extends StatelessWidget {
  final String title;
  final DateTime trackedAt;
  final ScrollController scrollController;
  final bool canEdit;
  final bool isEditing;
  final bool saving;
  final VoidCallback? onEditPressed;
  final VoidCallback? onCancelPressed;
  final VoidCallback? onSavePressed;
  final VoidCallback onDeletePressed;
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
    required this.onDeletePressed,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final formattedDate = formatDateTimeFull(trackedAt);

    return SingleChildScrollView(
      controller: scrollController,
      padding: AppConstants.paddingLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: AppConstants.iconBadgeSm,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.muted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          AppConstants.gap16,
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: AppTheme.fontSizeHeading,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (canEdit && !isEditing)
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: onEditPressed,
                ),
            ],
          ),
          AppConstants.gap4,
          Text(
            formattedDate,
            style: const TextStyle(
              fontSize: AppTheme.fontSizeBody,
              color: AppTheme.mutedForeground,
            ),
          ),
          AppConstants.gap24,
          content,
          AppConstants.gap24,
          if (isEditing) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: saving ? null : onCancelPressed,
                    child: const Text('Abbrechen'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: saving ? null : onSavePressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Speichern'),
                  ),
                ),
              ],
            ),
          ] else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onDeletePressed,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.destructive,
                  side: const BorderSide(color: AppTheme.destructive),
                ),
                child: const Text('Eintrag löschen'),
              ),
            ),
        ],
      ),
    );
  }
}
