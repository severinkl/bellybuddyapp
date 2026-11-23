import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';

/// „Buddy umbenennen": a name field prefilled with [current] (selected, so
/// typing replaces it). „Speichern" is enabled only for a valid name
/// ([AppConstants.isValidBuddyName]); it returns the name trimmed.
/// „Abbrechen" or dismissing returns null.
Future<String?> showRenameBuddyDialog(
  BuildContext context, {
  required String current,
}) => showDialog<String>(
  context: context,
  builder: (_) => _RenameBuddyDialog(current: current),
);

class _RenameBuddyDialog extends StatefulWidget {
  const _RenameBuddyDialog({required this.current});

  final String current;

  @override
  State<_RenameBuddyDialog> createState() => _RenameBuddyDialogState();
}

class _RenameBuddyDialogState extends State<_RenameBuddyDialog> {
  static const _error =
      'Bitte gib einen Namen mit 1 bis ${AppConstants.buddyNameMaxLength} '
      'Zeichen ein.';

  late final TextEditingController _controller =
      TextEditingController(text: widget.current)
        ..selection = TextSelection(
          baseOffset: 0,
          extentOffset: widget.current.length,
        );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _name => _controller.text.trim();

  bool get _valid => AppConstants.isValidBuddyName(_name);

  void _save() {
    if (_valid) Navigator.pop(context, _name);
  }

  /// „n/20": the trimmed name's length in code points, as validated and
  /// stored (an emoji family is one character but five code points).
  Widget _counter(
    BuildContext context, {
    required int currentLength,
    required bool isFocused,
    required int? maxLength,
  }) => Semantics(
    container: true,
    liveRegion: isFocused,
    child: Text(
      '${_name.runes.length}/${AppConstants.buddyNameMaxLength}',
      style: const TextStyle(
        fontSize: AppTheme.fontSizeCaption,
        color: AppTheme.mutedForeground,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('Buddy umbenennen'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        // Not cut off at the limit: a too long name shows the error instead.
        maxLength: AppConstants.buddyNameMaxLength,
        maxLengthEnforcement: MaxLengthEnforcement.none,
        buildCounter: _counter,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        autocorrect: false,
        decoration: InputDecoration(
          labelText: 'Name',
          errorText: _valid ? null : _error,
          errorMaxLines: 2,
        ),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        TextButton(
          onPressed: _valid ? _save : null,
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}
