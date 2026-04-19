import 'package:flutter/material.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';

/// Wizard step that asks the user for a real email when OAuth didn't give
/// us one (Apple second-sign-in) or gave us an Apple relay address. Pure
/// presentation: the parent wizard owns the captured value and the submit
/// behavior.
class EmailCaptureStep extends StatefulWidget {
  final String? value;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;

  static const emailFieldKey = Key('email_capture_email_field');
  static const submitButtonKey = Key('email_capture_submit_button');

  const EmailCaptureStep({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onSubmit,
  });

  @override
  State<EmailCaptureStep> createState() => _EmailCaptureStepState();
}

class _EmailCaptureStepState extends State<EmailCaptureStep> {
  late final TextEditingController _controller;
  static final RegExp _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isValid {
    final text = _controller.text.trim();
    if (text.isEmpty) return false;
    if (!_emailRegex.hasMatch(text)) return false;
    if (text.endsWith('@privaterelay.appleid.com')) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppConstants.gap24,
          const Text(
            'Deine E-Mail-Adresse',
            style: TextStyle(
              fontSize: AppTheme.fontSizeHeading,
              fontWeight: FontWeight.w600,
              color: AppTheme.foreground,
            ),
          ),
          AppConstants.gap16,
          const Text(
            'Damit wir dir Empfehlungen, Erinnerungen und die tägliche '
            'Zusammenfassung schicken können, brauchen wir deine echte '
            'E-Mail-Adresse.',
            style: TextStyle(
              fontSize: AppTheme.fontSizeBody,
              color: AppTheme.mutedForeground,
            ),
          ),
          AppConstants.gap24,
          TextFormField(
            key: EmailCaptureStep.emailFieldKey,
            controller: _controller,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'E-Mail-Adresse',
              hintText: 'du@beispiel.de',
            ),
            onChanged: (v) {
              widget.onChanged(v.trim());
              setState(() {}); // rebuild so button enabled state updates
            },
            onFieldSubmitted: (_) {
              if (_isValid) widget.onSubmit();
            },
          ),
          const Spacer(),
          ElevatedButton(
            key: EmailCaptureStep.submitButtonKey,
            onPressed: _isValid ? widget.onSubmit : null,
            child: const Text('Weiter'),
          ),
          AppConstants.gap16,
        ],
      ),
    );
  }
}
