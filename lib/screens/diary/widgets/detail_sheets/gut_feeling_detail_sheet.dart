import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/diary_provider.dart';
import '../../../../providers/entries_provider.dart';
import 'detail_sheet_scaffold.dart';
import 'gut_feeling_detail.dart';
import 'gut_feeling_edit_state.dart';

class GutFeelingDetailSheet extends StatefulWidget {
  final DiaryEntry entry;
  final GutFeelingDiaryData data;
  final WidgetRef parentRef;
  final ScrollController scrollController;

  const GutFeelingDetailSheet({
    super.key,
    required this.entry,
    required this.data,
    required this.parentRef,
    required this.scrollController,
  });

  @override
  State<GutFeelingDetailSheet> createState() => _GutFeelingDetailSheetState();
}

class _GutFeelingDetailSheetState extends State<GutFeelingDetailSheet> {
  bool _isEditing = false;
  bool _saving = false;

  late int _bloating;
  late int _gas;
  late int _cramps;
  late int _fullness;
  int? _stress;
  int? _happiness;
  int? _energy;
  int? _focus;
  int? _bodyFeel;

  @override
  void initState() {
    super.initState();
    _resetEditState();
  }

  void _resetEditState() {
    final gut = widget.data.gutFeeling;
    _bloating = gut.bloating;
    _gas = gut.gas;
    _cramps = gut.cramps;
    _fullness = gut.fullness;
    _stress = gut.stress;
    _happiness = gut.happiness;
    _energy = gut.energy;
    _focus = gut.focus;
    _bodyFeel = gut.bodyFeel;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.parentRef
          .read(entriesProvider.notifier)
          .updateGutFeelingById(
            widget.entry.id,
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
      final date = widget.parentRef.read(diaryDateProvider);
      widget.parentRef.invalidate(diaryEntriesProvider(date));
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DetailSheetScaffold(
      title: widget.entry.title,
      trackedAt: widget.entry.trackedAt,
      scrollController: widget.scrollController,
      canEdit: true,
      isEditing: _isEditing,
      saving: _saving,
      onEditPressed: () => setState(() => _isEditing = true),
      onCancelPressed: () {
        _resetEditState();
        setState(() => _isEditing = false);
      },
      onSavePressed: _save,
      onDeletePressed: () async {
        Navigator.pop(context);
        await widget.parentRef
            .read(entriesProvider.notifier)
            .deleteByType(widget.entry.type.name, widget.entry.id);
        final date = widget.parentRef.read(diaryDateProvider);
        widget.parentRef.invalidate(diaryEntriesProvider(date));
      },
      content: GutFeelingDetail(
        gut: widget.data.gutFeeling,
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
      ),
    );
  }
}
