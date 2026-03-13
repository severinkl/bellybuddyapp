import 'package:flutter/material.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    }
    return false;
  }
}
