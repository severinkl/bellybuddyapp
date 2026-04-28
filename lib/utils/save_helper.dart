import 'package:flutter/material.dart';

/// Drops keyboard focus and yields one microtask so any focus-loss
/// listener (notably EditableAppBarTitle) commits its pending value
/// before the caller reads state.
Future<void> flushFocusBeforeSave() async {
  FocusManager.instance.primaryFocus?.unfocus();
  await Future<void>.microtask(() {});
}

/// Executes [action] and shows a SnackBar on failure.
/// Returns `true` if the action succeeded, `false` otherwise.
Future<bool> saveWithFeedback(
  BuildContext context,
  Future<void> Function() action, {
  String errorMessage = 'Fehler beim Speichern.',
}) async {
  try {
    await action();
    return true;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage)));
    }
    return false;
  }
}
