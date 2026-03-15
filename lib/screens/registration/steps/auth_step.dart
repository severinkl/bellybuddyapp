import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../router/route_names.dart';
import '../../../widgets/common/bb_auth_banner.dart';
import '../../../widgets/common/bb_button.dart';
import '../../../widgets/common/bb_password_hint.dart';
import '../../../widgets/common/mascot_image.dart';

class AuthStep extends StatefulWidget {
  final bool isLoading;
  final String? error;
  final Future<void> Function(String email, String password) onEmailSignUp;
  final Future<void> Function() onGoogleSignUp;
  final Future<void> Function() onAppleSignUp;

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

class _AuthStepState extends State<AuthStep> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _isPasswordValid {
    final p = _passwordController.text;
    return p.length >= 8 &&
        p.contains(RegExp(r'[A-Z]')) &&
        p.contains(RegExp(r'[a-z]')) &&
        p.contains(RegExp(r'[0-9]'));
  }

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
    return SingleChildScrollView(
      padding: AppConstants.paddingLg,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppConstants.gap16,
            const MascotImage(assetPath: AppConstants.mascotEnergetic, width: 120, height: 120),
            AppConstants.gap16,
            const Text(
              'Konto erstellen',
              style: TextStyle(
                fontSize: AppTheme.fontSizeDisplay,
                fontWeight: FontWeight.w700,
                color: AppTheme.foreground,
              ),
              textAlign: TextAlign.center,
            ),
            AppConstants.gap8,
            const Text(
              'Erstelle dein Konto, um dein Profil zu speichern.',
              style: TextStyle(
                fontSize: AppTheme.fontSizeBodyLG,
                color: AppTheme.mutedForeground,
              ),
              textAlign: TextAlign.center,
            ),
            AppConstants.gap32,

            if (widget.error != null)
              BbAuthBanner(text: widget.error!, isError: true),

            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'E-Mail',
                hintText: 'deine@email.de',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'E-Mail ist erforderlich';
                if (!v.contains('@')) return 'Ungültige E-Mail';
                return null;
              },
            ),
            AppConstants.gap16,

            TextFormField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Passwort',
              ),
              onChanged: (_) => setState(() {}),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Passwort ist erforderlich';
                return null;
              },
            ),
            AppConstants.gap8,

            BbPasswordHint(
              text: 'Mindestens 8 Zeichen',
              isValid: _passwordController.text.length >= 8,
            ),
            BbPasswordHint(
              text: 'Mindestens ein Großbuchstabe',
              isValid: _passwordController.text.contains(RegExp(r'[A-Z]')),
            ),
            BbPasswordHint(
              text: 'Mindestens ein Kleinbuchstabe',
              isValid: _passwordController.text.contains(RegExp(r'[a-z]')),
            ),
            BbPasswordHint(
              text: 'Mindestens eine Zahl',
              isValid: _passwordController.text.contains(RegExp(r'[0-9]')),
            ),
            AppConstants.gap24,

            BbButton(
              label: 'Registrieren',
              isLoading: widget.isLoading,
              onPressed: _isPasswordValid ? _submit : null,
            ),

            AppConstants.gap24,
            const Row(
              children: [
                Expanded(child: Divider(color: AppTheme.border)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('oder', style: TextStyle(color: AppTheme.mutedForeground)),
                ),
                Expanded(child: Divider(color: AppTheme.border)),
              ],
            ),
            AppConstants.gap24,

            BbButton(
              label: 'Mit Google fortfahren',
              isOutlined: true,
              onPressed: widget.isLoading ? null : widget.onGoogleSignUp,
            ),

            if (Platform.isIOS) ...[
              AppConstants.gap12,
              BbButton(
                label: 'Mit Apple fortfahren',
                isOutlined: true,
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
