import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/diary_provider.dart';
import '../../../../providers/entries_provider.dart';
import 'detail_sheet_scaffold.dart';
import 'drink_detail.dart';

class DrinkDetailSheet extends StatefulWidget {
  final DiaryEntry entry;
  final DrinkDiaryData data;
  final WidgetRef parentRef;
  final ScrollController scrollController;

  const DrinkDetailSheet({
    super.key,
    required this.entry,
    required this.data,
    required this.parentRef,
    required this.scrollController,
  });

  @override
  State<DrinkDetailSheet> createState() => _DrinkDetailSheetState();
}

class _DrinkDetailSheetState extends State<DrinkDetailSheet> {
  bool _isEditing = false;
  bool _saving = false;
  late TextEditingController _amountController;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.data.drink.amountMl.toString(),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _resetEditState() {
    _amountController.text = widget.data.drink.amountMl.toString();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.parentRef
          .read(entriesProvider.notifier)
          .updateDrinkById(
            widget.entry.id,
            amountMl:
                int.tryParse(_amountController.text) ??
                widget.data.drink.amountMl,
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
      content: DrinkDetail(
        drink: widget.data.drink,
        isEditing: _isEditing,
        amountController: _amountController,
      ),
    );
  }
}
