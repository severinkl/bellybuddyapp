import 'package:flutter/material.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../widgets/common/bb_auth_banner.dart';
import '../../../widgets/common/bb_button.dart';
import '../../../widgets/common/mascot_image.dart';

/// Wizard step that asks the user for a real email when OAuth didn't give
/// us one (Apple second-sign-in) or gave us an Apple relay address. Pure
/// presentation: the parent wizard owns the captured value and the submit
/// behavior.
class EmailCaptureStep extends StatefulWidget {
  /// Initial value only — read once in [State.initState]. Later updates
  /// from the parent are NOT reflected in the field; the parent should
  /// treat this widget as the source of truth for the typed value and
  /// drive the parent state from [onChanged].
  final String? value;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;

  /// Called when the user taps the "Überspringen" link. The parent should
  /// persist the profile with a `null` email. Sharing a real address on
  /// this step is optional — Apple's Sign in with Apple policy prohibits
  /// requiring it.
  final VoidCallback onSkip;

  /// Disables the submit button and shows a progress indicator while the
  /// parent is saving. Prevents double-submit during the async createProfile.
  final bool isLoading;

  /// Error message surfaced below the input (e.g. "save failed"). `null`
  /// hides the banner.
  final String? error;

  static const emailFieldKey = Key('email_capture_email_field');
  static const submitButtonKey = Key('email_capture_submit_button');
  static const skipButtonKey = Key('email_capture_skip_button');

  const EmailCaptureStep({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onSubmit,
    required this.onSkip,
    this.isLoading = false,
    this.error,
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
    if (text.toLowerCase().endsWith(AppConstants.appleRelayEmailSuffix)) {
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppConstants.paddingLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppConstants.gap24,
          const Center(
            child: MascotImage(
              assetPath: AppConstants.mascotZen,
              width: 120,
              height: 120,
            ),
          ),
          AppConstants.gap16,
          const Text(
            'Deine E-Mail-Adresse',
            style: TextStyle(
              fontSize: AppTheme.fontSizeHeadingLG,
              fontWeight: FontWeight.w700,
              color: AppTheme.foreground,
            ),
            textAlign: TextAlign.center,
          ),
          AppConstants.gap8,
          const Text(
            'Falls du möchtest, kannst du uns hier deine echte '
            'E-Mail-Adresse geben. So können wir dich bei wichtigen '
            'Mitteilungen erreichen. Dieser Schritt ist optional.',
            style: TextStyle(
              fontSize: AppTheme.fontSizeBodyLG,
              color: AppTheme.mutedForeground,
            ),
            textAlign: TextAlign.center,
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
              if (_isValid && !widget.isLoading) widget.onSubmit();
            },
          ),
          if (widget.error != null) ...[
            AppConstants.gap12,
            BbAuthBanner(text: widget.error!),
          ],
          const Spacer(),
          BbButton(
            tapKey: EmailCaptureStep.submitButtonKey,
            label: 'Weiter',
            isLoading: widget.isLoading,
            onPressed: _isValid ? widget.onSubmit : null,
          ),
          TextButton(
            key: EmailCaptureStep.skipButtonKey,
            onPressed: widget.isLoading ? null : widget.onSkip,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.mutedForeground,
            ),
            child: const Text('Überspringen'),
          ),
          AppConstants.gap16,
        ],
      ),
    );
  }
}
