import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/app_theme.dart';
import '../../../providers/diary_provider.dart';
import '../../../providers/entries_provider.dart';
import '../../../utils/date_format_utils.dart';
import 'detail_sheets/meal_detail.dart';
import 'detail_sheets/toilet_detail.dart';
import 'detail_sheets/gut_feeling_detail.dart';
import 'detail_sheets/gut_feeling_edit_state.dart';
import 'detail_sheets/drink_detail.dart';
import '../../../config/constants.dart';

void showDiaryDetailSheet(BuildContext context, WidgetRef ref, DiaryEntry entry) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) {
      return DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return _DiaryDetailContent(
            entry: entry,
            parentRef: ref,
            scrollController: scrollController,
          );
        },
      );
    },
  );
}

class _DiaryDetailContent extends StatefulWidget {
  final DiaryEntry entry;
  final WidgetRef parentRef;
  final ScrollController scrollController;

  const _DiaryDetailContent({
    required this.entry,
    required this.parentRef,
    required this.scrollController,
  });

  @override
  State<_DiaryDetailContent> createState() => _DiaryDetailContentState();
}

class _DiaryDetailContentState extends State<_DiaryDetailContent> {
  bool _isEditing = false;
  bool _saving = false;

  // Gut feeling edit state
  late int _bloating;
  late int _gas;
  late int _cramps;
  late int _fullness;
  int? _stress;
  int? _happiness;
  int? _energy;
  int? _focus;
  int? _bodyFeel;

  // Toilet edit state
  late int _stoolType;

  // Drink edit state
  late TextEditingController _amountController;
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _notesController = TextEditingController();
    _resetEditState();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _resetEditState() {
    switch (widget.entry.data) {
      case GutFeelingDiaryData(:final gutFeeling):
        _bloating = gutFeeling.bloating;
        _gas = gutFeeling.gas;
        _cramps = gutFeeling.cramps;
        _fullness = gutFeeling.fullness;
        _stress = gutFeeling.stress;
        _happiness = gutFeeling.happiness;
        _energy = gutFeeling.energy;
        _focus = gutFeeling.focus;
        _bodyFeel = gutFeeling.bodyFeel;
      case ToiletDiaryData(:final toilet):
        _stoolType = toilet.stoolType;
      case DrinkDiaryData(:final drink):
        _amountController.text = drink.amountMl.toString();
        _notesController.text = drink.notes ?? '';
      case MealDiaryData():
        break;
    }
  }

  bool get _canEdit => widget.entry.type != DiaryEntryType.meal;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final id = widget.entry.id;
      final notifier = widget.parentRef.read(entriesProvider.notifier);
      switch (widget.entry.type) {
        case DiaryEntryType.gutFeeling:
          await notifier.updateGutFeelingById(id,
            bloating: _bloating,
            gas: _gas,
            cramps: _cramps,
            fullness: _fullness,
            stress: _stress,
            happiness: _happiness,
            energy: _energy,
            focus: _focus,
            bodyFeel: _bodyFeel,
          );
        case DiaryEntryType.toilet:
          await notifier.updateToiletById(id,
            stoolType: _stoolType,
          );
        case DiaryEntryType.drink:
          final drinkData = widget.entry.data as DrinkDiaryData;
          await notifier.updateDrinkById(id,
            amountMl: int.tryParse(_amountController.text) ??
                drinkData.drink.amountMl,
            notes:
                _notesController.text.isEmpty ? null : _notesController.text,
          );
        case DiaryEntryType.meal:
          break;
      }
      final date = widget.parentRef.read(diaryDateProvider);
      widget.parentRef.invalidate(diaryEntriesProvider(date));
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = formatDateTimeFull(widget.entry.trackedAt);

    return SingleChildScrollView(
      controller: widget.scrollController,
      padding: AppConstants.paddingLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
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
                  widget.entry.title,
                  style: const TextStyle(
                      fontSize: AppTheme.fontSizeHeading, fontWeight: FontWeight.w700),
                ),
              ),
              if (_canEdit && !_isEditing)
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () => setState(() => _isEditing = true),
                ),
            ],
          ),
          AppConstants.gap4,
          Text(
            formattedDate,
            style: const TextStyle(
                fontSize: AppTheme.fontSizeBody, color: AppTheme.mutedForeground),
          ),
          AppConstants.gap24,
          _buildTypeSpecificContent(),
          AppConstants.gap24,
          if (_isEditing) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving
                        ? null
                        : () {
                            _resetEditState();
                            setState(() => _isEditing = false);
                          },
                    child: const Text('Abbrechen'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: _saving
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
                onPressed: () async {
                  Navigator.pop(context);
                  await widget.parentRef.read(entriesProvider.notifier).deleteByType(
                    widget.entry.type.name, widget.entry.id);
                  final date = widget.parentRef.read(diaryDateProvider);
                  widget.parentRef.invalidate(diaryEntriesProvider(date));
                },
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

  Widget _buildTypeSpecificContent() {
    switch (widget.entry.data) {
      case MealDiaryData(:final meal):
        return MealDetail(meal: meal);
      case ToiletDiaryData(:final toilet):
        return ToiletDetail(
          toilet: toilet,
          isEditing: _isEditing,
          editStoolType: _stoolType,
          onStoolTypeChanged: (v) => setState(() => _stoolType = v),
        );
      case GutFeelingDiaryData(:final gutFeeling):
        return GutFeelingDetail(
          gut: gutFeeling,
          isEditing: _isEditing,
          editState: _isEditing
              ? GutFeelingEditState(
                  bloating: _bloating,
                  gas: _gas,
                  cramps: _cramps,
                  fullness: _fullness,
                  stress: _stress,
                  happiness: _happiness,
                  energy: _energy,
                  focus: _focus,
                  bodyFeel: _bodyFeel,
                  onBloatingChanged: (v) => setState(() => _bloating = v),
                  onGasChanged: (v) => setState(() => _gas = v),
                  onCrampsChanged: (v) => setState(() => _cramps = v),
                  onFullnessChanged: (v) => setState(() => _fullness = v),
                  onStressChanged: (v) => setState(() => _stress = v),
                  onHappinessChanged: (v) => setState(() => _happiness = v),
                  onEnergyChanged: (v) => setState(() => _energy = v),
                  onFocusChanged: (v) => setState(() => _focus = v),
                  onBodyFeelChanged: (v) => setState(() => _bodyFeel = v),
                )
              : null,
        );
      case DrinkDiaryData(:final drink):
        return DrinkDetail(
          drink: drink,
          isEditing: _isEditing,
          amountController: _amountController,
          notesController: _notesController,
        );
    }
  }
}
