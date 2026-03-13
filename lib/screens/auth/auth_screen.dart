import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';
import '../../providers/profile_provider.dart';
import '../../router/route_names.dart';
import '../../services/auth_service.dart';
import '../../widgets/common/bb_button.dart';

enum _AuthView { login, register, forgotPassword }

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

  bool get _isPasswordValid {
    final p = _passwordController.text;
    return p.length >= 8 &&
        p.contains(RegExp(r'[A-Z]')) &&
        p.contains(RegExp(r'[a-z]')) &&
        p.contains(RegExp(r'[0-9]'));
  }

  /// After login, fetch profile and navigate to the right screen.
  Future<void> _navigateAfterAuth({bool isNewUser = false}) async {
    if (!mounted) return;
    if (isNewUser) {
      context.go(RoutePaths.registration);
      return;
    }
    // Fetch profile to determine if registration is complete
    await ref.read(profileProvider.notifier).fetchProfile();
    if (!mounted) return;
    final hasProfile = ref.read(hasCompletedRegistrationProvider);
    context.go(hasProfile ? RoutePaths.dashboard : RoutePaths.registration);
  }

  Future<void> _handleEmailAuth() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      if (_view == _AuthView.register) {
        if (!_isPasswordValid) return;
        await AuthService.signUpWithEmail(
          _emailController.text.trim(),
          _passwordController.text,
        );
        await _navigateAfterAuth(isNewUser: true);
      } else {
        await AuthService.signInWithEmail(
          _emailController.text.trim(),
          _passwordController.text,
        );
        await _navigateAfterAuth();
      }
    } catch (e) {
      setState(() {
        if (_view == _AuthView.register) {
          _error = 'Diese E-Mail ist bereits registriert.';
        } else {
          _error = 'E-Mail oder Passwort ist falsch.';
        }
      });
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
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 48),
                Text(
                  _view == _AuthView.forgotPassword
                      ? 'Passwort vergessen?'
                      : _view == _AuthView.register
                          ? 'Konto erstellen'
                          : 'Willkommen zurück',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.foreground,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _view == _AuthView.forgotPassword
                      ? 'Gib deine E-Mail ein, um dein Passwort zurückzusetzen.'
                      : _view == _AuthView.register
                          ? 'Erstelle dein Belly Buddy Konto'
                          : 'Melde dich bei Belly Buddy an',
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppTheme.mutedForeground,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                if (_error != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.destructive.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: AppTheme.destructive, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),

                if (_resetSent && _view == _AuthView.forgotPassword)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'E-Mail zum Zurücksetzen wurde gesendet!',
                      style: TextStyle(color: AppTheme.success, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
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
                const SizedBox(height: 16),

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
                  const SizedBox(height: 8),

                  // Password validation hints (register only)
                  if (_view == _AuthView.register) ...[
                    _PasswordHint(
                      text: 'Mindestens 8 Zeichen',
                      isValid: _passwordController.text.length >= 8,
                    ),
                    _PasswordHint(
                      text: 'Mindestens ein Großbuchstabe',
                      isValid: _passwordController.text.contains(RegExp(r'[A-Z]')),
                    ),
                    _PasswordHint(
                      text: 'Mindestens ein Kleinbuchstabe',
                      isValid: _passwordController.text.contains(RegExp(r'[a-z]')),
                    ),
                    _PasswordHint(
                      text: 'Mindestens eine Zahl',
                      isValid: _passwordController.text.contains(RegExp(r'[0-9]')),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Forgot password link (login only)
                  if (_view == _AuthView.login)
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

                const SizedBox(height: 16),

                // Submit button
                BbButton(
                  label: _view == _AuthView.forgotPassword
                      ? 'Zurücksetzen'
                      : _view == _AuthView.register
                          ? 'Registrieren'
                          : 'Anmelden',
                  isLoading: _isLoading,
                  onPressed: _view == _AuthView.forgotPassword
                      ? _handleResetPassword
                      : _handleEmailAuth,
                ),

                if (_view != _AuthView.forgotPassword) ...[
                  const SizedBox(height: 24),
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
                  const SizedBox(height: 24),

                  // Google sign in
                  BbButton(
                    label: 'Mit Google fortfahren',
                    isOutlined: true,
                    onPressed: _isLoading ? null : _handleGoogleSignIn,
                  ),

                  // Apple sign in (iOS only)
                  if (Platform.isIOS) ...[
                    const SizedBox(height: 12),
                    BbButton(
                      label: 'Mit Apple fortfahren',
                      isOutlined: true,
                      onPressed: _isLoading ? null : _handleAppleSignIn,
                    ),
                  ],
                ],

                const SizedBox(height: 24),

                // Toggle login/register or back
                TextButton(
                  onPressed: () => setState(() {
                    _error = null;
                    _resetSent = false;
                    if (_view == _AuthView.forgotPassword) {
                      _view = _AuthView.login;
                    } else if (_view == _AuthView.login) {
                      _view = _AuthView.register;
                    } else {
                      _view = _AuthView.login;
                    }
                  }),
                  child: Text(
                    _view == _AuthView.forgotPassword
                        ? 'Zurück zur Anmeldung'
                        : _view == _AuthView.login
                            ? 'Noch kein Konto? Registrieren'
                            : 'Bereits registriert? Anmelden',
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

class _PasswordHint extends StatelessWidget {
  final String text;
  final bool isValid;

  const _PasswordHint({required this.text, required this.isValid});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle : Icons.circle_outlined,
            size: 16,
            color: isValid ? AppTheme.success : AppTheme.mutedForeground,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: isValid ? AppTheme.success : AppTheme.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}
