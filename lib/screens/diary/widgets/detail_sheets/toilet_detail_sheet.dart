import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/diary_provider.dart';
import '../../../../providers/entries_provider.dart';
import 'detail_sheet_scaffold.dart';
import 'toilet_detail.dart';

class ToiletDetailSheet extends StatefulWidget {
  final DiaryEntry entry;
  final ToiletDiaryData data;
  final WidgetRef parentRef;
  final ScrollController scrollController;

  const ToiletDetailSheet({
    super.key,
    required this.entry,
    required this.data,
    required this.parentRef,
    required this.scrollController,
  });

  @override
  State<ToiletDetailSheet> createState() => _ToiletDetailSheetState();
}

class _ToiletDetailSheetState extends State<ToiletDetailSheet> {
  bool _isEditing = false;
  bool _saving = false;
  late int _stoolType;

  @override
  void initState() {
    super.initState();
    _stoolType = widget.data.toilet.stoolType;
  }

  void _resetEditState() {
    _stoolType = widget.data.toilet.stoolType;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.parentRef
          .read(entriesProvider.notifier)
          .updateToiletById(widget.entry.id, stoolType: _stoolType);
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
      content: ToiletDetail(
        toilet: widget.data.toilet,
        isEditing: _isEditing,
        editStoolType: _stoolType,
        onStoolTypeChanged: (v) => setState(() => _stoolType = v),
      ),
    );
  }
}
