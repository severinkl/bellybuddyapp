import 'package:flutter/material.dart';

import '../../../../config/app_theme.dart';
import '../../../../config/constants.dart';

/// Result of [showMealTitleSheet].
///
/// `null` from the future means the user dismissed the sheet — the caller
/// should cancel the save. [MealTitleEntered] carries the typed title.
/// [MealTitleSkipped] means the user explicitly chose to save without a
/// title and the caller should proceed with the current (default) title.
sealed class MealTitleSheetOutcome {
  const MealTitleSheetOutcome();
}

final class MealTitleEntered extends MealTitleSheetOutcome {
  final String title;
  const MealTitleEntered(this.title);
}

final class MealTitleSkipped extends MealTitleSheetOutcome {
  const MealTitleSkipped();
}

/// Prompts the user to give their meal a name before saving. Shown when the
/// title is still the pristine default, so the saved meal is identifiable
/// in the diary list.
Future<MealTitleSheetOutcome?> showMealTitleSheet(BuildContext context) {
  return showModalBottomSheet<MealTitleSheetOutcome>(
    context: context,
    isScrollControlled: true, // makes room for the keyboard
    backgroundColor: AppTheme.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppConstants.radiusLg),
      ),
    ),
    builder: (_) => const _MealTitleSheet(),
  );
}

class _MealTitleSheet extends StatefulWidget {
  const _MealTitleSheet();

  static const titleFieldKey = Key('meal_title_sheet_field');
  static const submitKey = Key('meal_title_sheet_submit');
  static const skipKey = Key('meal_title_sheet_skip');

  @override
  State<_MealTitleSheet> createState() => _MealTitleSheetState();
}

class _MealTitleSheetState extends State<_MealTitleSheet> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChange);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChange);
    _controller.dispose();
    super.dispose();
  }

  void _onChange() => setState(() {});

  bool get _canSubmit => _controller.text.trim().isNotEmpty;

  void _submit() {
    if (!_canSubmit) return;
    Navigator.of(context).pop(MealTitleEntered(_controller.text.trim()));
  }

  void _skip() {
    Navigator.of(context).pop(const MealTitleSkipped());
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(
        left: AppConstants.spacingLg,
        right: AppConstants.spacingLg,
        top: AppConstants.spacingLg,
        // Float above the keyboard while keeping our own breathing room.
        bottom: bottomInset + AppConstants.spacingLg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Gib deiner Mahlzeit einen Namen',
            style: TextStyle(
              fontSize: AppTheme.fontSizeHeading,
              fontWeight: FontWeight.w600,
              color: AppTheme.foreground,
            ),
          ),
          AppConstants.gap8,
          const Text(
            'So findest du sie später schnell im Tagebuch wieder.',
            style: TextStyle(
              fontSize: AppTheme.fontSizeBody,
              color: AppTheme.mutedForeground,
            ),
          ),
          AppConstants.gap16,
          TextField(
            key: _MealTitleSheet.titleFieldKey,
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(
              hintText: 'z.B. Pasta mit Tomaten',
            ),
          ),
          AppConstants.gap16,
          FilledButton(
            key: _MealTitleSheet.submitKey,
            onPressed: _canSubmit ? _submit : null,
            child: const Text('Speichern'),
          ),
          AppConstants.gap8,
          TextButton(
            key: _MealTitleSheet.skipKey,
            onPressed: _skip,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.mutedForeground,
            ),
            child: const Text('Ohne Name speichern'),
          ),
        ],
      ),
    );
  }
}
