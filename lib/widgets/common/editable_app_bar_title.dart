import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';

/// AppBar title that flips between a tappable label and an inline TextField.
///
/// Owns its own controller, focus node, and edit-mode flag. Parents pass
/// the current title and receive a trimmed string via [onChanged] when the
/// user commits (submit or blur).
class EditableAppBarTitle extends StatefulWidget {
  final String initialTitle;
  final String placeholder;
  final bool autofocusOnMount;
  final ValueChanged<String> onChanged;

  const EditableAppBarTitle({
    super.key,
    required this.initialTitle,
    required this.placeholder,
    required this.onChanged,
    this.autofocusOnMount = false,
  });

  @override
  State<EditableAppBarTitle> createState() => _EditableAppBarTitleState();
}

class _EditableAppBarTitleState extends State<EditableAppBarTitle> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late bool _isEditing;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialTitle);
    _focusNode = FocusNode();
    _isEditing = widget.autofocusOnMount;

    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _isEditing) {
        _commit();
      }
    });

    if (widget.autofocusOnMount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _focusNode.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(covariant EditableAppBarTitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    // External writes (e.g. recipe edit-mode prefill that happens after first
    // build) should reflect in the displayed text without disturbing the
    // user mid-edit.
    if (!_isEditing && widget.initialTitle != _controller.text) {
      _controller.text = widget.initialTitle;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _commit() {
    final value = _controller.text.trim();
    widget.onChanged(value);
    if (mounted) setState(() => _isEditing = false);
  }

  void _enterEdit() {
    setState(() => _isEditing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing) {
      return TextField(
        controller: _controller,
        focusNode: _focusNode,
        autofocus: true,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: AppTheme.fontSizeTitle,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          hintText: widget.placeholder,
        ),
        onSubmitted: (_) => _commit(),
      );
    }

    final text = _controller.text.trim();
    final isEmpty = text.isEmpty;
    return GestureDetector(
      onTap: _enterEdit,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              isEmpty ? widget.placeholder : text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: AppTheme.fontSizeTitle,
                fontWeight: FontWeight.w600,
                color: isEmpty ? AppTheme.mutedForeground : null,
              ),
            ),
          ),
          const SizedBox(width: AppConstants.spacingXs),
          const Icon(Icons.edit, size: 16),
        ],
      ),
    );
  }
}
