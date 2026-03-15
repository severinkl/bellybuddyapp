import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';
import '../../providers/profile_provider.dart';
import '../../router/route_names.dart';
import '../../services/auth_service.dart';
import '../../widgets/common/bb_button.dart';
import '../../widgets/common/bb_auth_banner.dart';
import '../../config/constants.dart';

enum _AuthView { login, forgotPassword }

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  _AuthView _view = _AuthView.login;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _error;
  bool _resetSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _navigateAfterAuth() async {
    if (!mounted) return;
    await ref.read(profileProvider.notifier).fetchProfile();
    if (!mounted) return;
    context.go(RoutePaths.dashboard);
  }

  Future<void> _handleEmailAuth() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await AuthService.signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );
      await _navigateAfterAuth();
    } catch (e) {
      setState(() => _error = 'E-Mail oder Passwort ist falsch.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await AuthService.signInWithGoogle();
      await _navigateAfterAuth();
    } catch (e) {
      setState(() => _error = 'Google-Anmeldung fehlgeschlagen.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAppleSignIn() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await AuthService.signInWithApple();
      await _navigateAfterAuth();
    } catch (e) {
      setState(() => _error = 'Apple-Anmeldung fehlgeschlagen.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleResetPassword() async {
    if (_emailController.text.trim().isEmpty) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await AuthService.resetPassword(_emailController.text.trim());
      setState(() => _resetSent = true);
    } catch (e) {
      setState(() => _error = 'Fehler beim Zurücksetzen.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppConstants.paddingLg,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 48),
                Text(
                  _view == _AuthView.forgotPassword
                      ? 'Passwort vergessen?'
                      : 'Willkommen zurück',
                  style: const TextStyle(
                    fontSize: AppTheme.fontSizeDisplay,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.foreground,
                  ),
                  textAlign: TextAlign.center,
                ),
                AppConstants.gap8,
                Text(
                  _view == _AuthView.forgotPassword
                      ? 'Gib deine E-Mail ein, um dein Passwort zurückzusetzen.'
                      : 'Melde dich bei Belly Buddy an',
                  style: const TextStyle(
                    fontSize: AppTheme.fontSizeBodyLG,
                    color: AppTheme.mutedForeground,
                  ),
                  textAlign: TextAlign.center,
                ),
                AppConstants.gap32,

                if (_error != null)
                  BbAuthBanner(text: _error!, isError: true),

                if (_resetSent && _view == _AuthView.forgotPassword)
                  const BbAuthBanner(
                    text: 'E-Mail zum Zurücksetzen wurde gesendet!',
                    isError: false,
                  ),

                // Email field
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

                // Password field (not for forgot password)
                if (_view != _AuthView.forgotPassword) ...[
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Passwort',
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Passwort ist erforderlich';
                      return null;
                    },
                  ),
                  AppConstants.gap8,

                  // Forgot password link
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => setState(() {
                        _view = _AuthView.forgotPassword;
                        _error = null;
                      }),
                      child: const Text('Passwort vergessen?'),
                    ),
                  ),
                ],

                AppConstants.gap16,

                // Submit button
                BbButton(
                  label: _view == _AuthView.forgotPassword
                      ? 'Zurücksetzen'
                      : 'Anmelden',
                  isLoading: _isLoading,
                  onPressed: _view == _AuthView.forgotPassword
                      ? _handleResetPassword
                      : _handleEmailAuth,
                ),

                if (_view != _AuthView.forgotPassword) ...[
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

                  // Google sign in
                  BbButton(
                    label: 'Mit Google fortfahren',
                    isOutlined: true,
                    onPressed: _isLoading ? null : _handleGoogleSignIn,
                  ),

                  // Apple sign in (iOS only)
                  if (Platform.isIOS) ...[
                    AppConstants.gap12,
                    BbButton(
                      label: 'Mit Apple fortfahren',
                      isOutlined: true,
                      onPressed: _isLoading ? null : _handleAppleSignIn,
                    ),
                  ],
                ],

                AppConstants.gap24,

                // Toggle or back
                TextButton(
                  onPressed: () {
                    if (_view == _AuthView.forgotPassword) {
                      setState(() {
                        _error = null;
                        _resetSent = false;
                        _view = _AuthView.login;
                      });
                    } else {
                      context.go(RoutePaths.registration);
                    }
                  },
                  child: Text(
                    _view == _AuthView.forgotPassword
                        ? 'Zurück zur Anmeldung'
                        : 'Noch kein Konto? Registrieren',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
