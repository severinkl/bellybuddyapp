import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/diary_provider.dart';
import '../../../../providers/entries_provider.dart';
import '../../../../utils/save_helper.dart';
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
  late DateTime _trackedAt;

  @override
  void initState() {
    super.initState();
    _resetEditState();
  }

  void _resetEditState() {
    _stoolType = widget.data.toilet.stoolType;
    _trackedAt = widget.data.toilet.trackedAt;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final movedTo = _trackedAt == widget.data.toilet.trackedAt
        ? null
        : _trackedAt;
    final ok = await saveWithFeedback(context, () async {
      await widget.parentRef
          .read(entriesProvider.notifier)
          .updateToiletById(
            widget.entry.id,
            stoolType: _stoolType,
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
      content: ToiletDetail(
        toilet: widget.data.toilet,
        isEditing: _isEditing,
        editStoolType: _stoolType,
        onStoolTypeChanged: (v) => setState(() => _stoolType = v),
      ),
    );
  }
}
