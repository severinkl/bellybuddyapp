import 'dart:io' show Platform;
import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../router/route_names.dart';
import '../../../widgets/common/bb_auth_banner.dart';
import '../../../utils/password_validator.dart';
import '../../../widgets/common/bb_button.dart';
import '../../../widgets/common/bb_password_field.dart';
import '../../../widgets/common/bb_password_hint.dart';
import '../../../widgets/common/bb_social_button.dart';

class AuthStep extends StatefulWidget {
  final bool isLoading;
  final String? error;
  final Future<void> Function(String email, String password) onEmailSignUp;
  final Future<void> Function() onGoogleSignUp;
  final Future<void> Function() onAppleSignUp;
  static const emailFieldKey = Key('auth_email_field');
  static const submitButtonKey = Key('auth_submit_button');

  const AuthStep({
    super.key,
    required this.isLoading,
    required this.error,
    required this.onEmailSignUp,
    required this.onGoogleSignUp,
    required this.onAppleSignUp,
  });

  @override
  State<AuthStep> createState() => _AuthStepState();
}

class _AuthStepState extends State<AuthStep> with WidgetsBindingObserver {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _submitKey = GlobalKey();
  bool _passwordFocused = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // While the password field has focus, keep „Registrieren" in view: the
  // keyboard (opening, or resizing) would otherwise cover it.
  @override
  void didChangeMetrics() {
    if (_passwordFocused) _revealSubmit();
  }

  void _onPasswordFocus(bool focused) {
    _passwordFocused = focused;
    if (focused) _revealSubmit();
  }

  void _revealSubmit() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _submitKey.currentContext;
      if (!mounted || !_passwordFocused || target == null) return;
      Scrollable.ensureVisible(
        target,
        duration: AppConstants.animFast,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  PasswordValidation get _validation =>
      PasswordValidator.validate(_passwordController.text);

  bool get _isPasswordValid => _validation.allMet;

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (!_isPasswordValid) return;
    widget.onEmailSignUp(
      _emailController.text.trim(),
      _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    // The Buddy's bubble above asks for the account, so no headline here.
    return SingleChildScrollView(
      padding: AppConstants.wizardStepPadding,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppConstants.gap8,
            if (widget.error != null)
              BbAuthBanner(text: widget.error!, isError: true),

            TextFormField(
              key: AuthStep.emailFieldKey,
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              // Once „Registrieren" showed an error, it goes away as soon as
              // the address is fixed.
              autovalidateMode: AutovalidateMode.onUserInteractionIfError,
              decoration: const InputDecoration(
                labelText: 'E-Mail',
                hintText: 'deine@email.de',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'E-Mail ist erforderlich';
                }
                if (!v.contains('@')) return 'Ungültige E-Mail';
                return null;
              },
            ),
            AppConstants.gap16,

            Focus(
              canRequestFocus: false,
              skipTraversal: true,
              onFocusChange: _onPasswordFocus,
              child: BbPasswordField(
                controller: _passwordController,
                onChanged: (_) {
                  setState(() {});
                  // The hints above the button grow while typing.
                  if (_passwordFocused) _revealSubmit();
                },
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Passwort ist erforderlich';
                  }
                  return null;
                },
              ),
            ),
            // Once all are met they make room: with the keyboard open the
            // address, the password and „Registrieren" then fit together.
            if (_passwordController.text.isNotEmpty && !_isPasswordValid) ...[
              AppConstants.gap8,
              BbPasswordHint(
                text: 'Mindestens 8 Zeichen',
                isValid: _validation.hasMinLength,
              ),
              BbPasswordHint(
                text: 'Mindestens ein Großbuchstabe',
                isValid: _validation.hasUppercase,
              ),
              BbPasswordHint(
                text: 'Mindestens ein Kleinbuchstabe',
                isValid: _validation.hasLowercase,
              ),
              BbPasswordHint(
                text: 'Mindestens eine Zahl',
                isValid: _validation.hasNumber,
              ),
            ],
            AppConstants.gap24,

            KeyedSubtree(
              key: _submitKey,
              child: BbButton(
                tapKey: AuthStep.submitButtonKey,
                label: 'Registrieren',
                isLoading: widget.isLoading,
                onPressed: _isPasswordValid ? _submit : null,
              ),
            ),

            AppConstants.gap24,
            const Row(
              children: [
                Expanded(child: Divider(color: AppTheme.border)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'oder',
                    style: TextStyle(color: AppTheme.mutedForeground),
                  ),
                ),
                Expanded(child: Divider(color: AppTheme.border)),
              ],
            ),
            AppConstants.gap24,

            BbSocialButton.google(
              onPressed: widget.isLoading ? null : widget.onGoogleSignUp,
            ),

            if (Platform.isIOS) ...[
              AppConstants.gap12,
              BbSocialButton.apple(
                onPressed: widget.isLoading ? null : widget.onAppleSignUp,
              ),
            ],

            AppConstants.gap24,
            TextButton(
              onPressed: () => context.go(RoutePaths.auth),
              child: const Text('Bereits registriert? Anmelden'),
            ),
          ],
        ),
      ),
    );
  }
}
