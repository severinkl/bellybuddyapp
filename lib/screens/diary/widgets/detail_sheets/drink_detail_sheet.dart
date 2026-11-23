import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/diary_provider.dart';
import '../../../../providers/entries_provider.dart';
import '../../../../utils/save_helper.dart';
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
  late final TextEditingController _amountController;
  late DateTime _trackedAt;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _resetEditState();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _resetEditState() {
    _amountController.text = widget.data.drink.amountMl.toString();
    _trackedAt = widget.data.drink.trackedAt;
  }

  Future<void> _save() async {
    final drink = widget.data.drink;
    setState(() => _saving = true);
    final movedTo = _trackedAt == drink.trackedAt ? null : _trackedAt;
    final ok = await saveWithFeedback(context, () async {
      await widget.parentRef
          .read(entriesProvider.notifier)
          .updateDrinkById(
            widget.entry.id,
            amountMl: int.tryParse(_amountController.text) ?? drink.amountMl,
            notes: drink.notes,
            trackedAt: movedTo,
          );
      refreshDiaryDays(widget.parentRef, movedTo: movedTo);
    });
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DetailSheetScaffold(
      title: widget.entry.title,
      trackedAt: _trackedAt,
      scrollController: widget.scrollController,
      canEdit: true,
      isEditing: _isEditing,
      saving: _saving,
      onEditPressed: () => setState(() => _isEditing = true),
      onCancelPressed: () => setState(() {
        _resetEditState();
        _isEditing = false;
      }),
      onSavePressed: _save,
      onTrackedAtChanged: (dt) => setState(() => _trackedAt = dt),
      onDelete: () async {
        await widget.parentRef
            .read(entriesProvider.notifier)
            .deleteByType(widget.entry.type.name, widget.entry.id);
        refreshDiaryDays(widget.parentRef);
      },
      content: DrinkDetail(
        drink: widget.data.drink,
        isEditing: _isEditing,
        amountController: _amountController,
      ),
    );
  }
}
