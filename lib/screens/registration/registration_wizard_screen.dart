import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../repositories/auth_repository.dart';
import '../../router/route_names.dart';
import '../../services/haptic_service.dart';
import '../../utils/logger.dart';
import '../../widgets/common/bb_button.dart';
import 'steps/auth_step.dart';
import 'steps/email_capture_step.dart';
import 'steps/birth_year_step.dart';
import 'steps/gender_step.dart';
import 'steps/height_weight_step.dart';
import 'steps/diet_step.dart';
import 'steps/symptoms_step.dart';
import 'steps/intolerances_step.dart';

class RegistrationWizardScreen extends ConsumerStatefulWidget {
  const RegistrationWizardScreen({super.key});

  static const nextButtonKey = Key('registration_next_button');

  @override
  ConsumerState<RegistrationWizardScreen> createState() =>
      _RegistrationWizardScreenState();
}

class _RegistrationWizardScreenState
    extends ConsumerState<RegistrationWizardScreen> {
  static const _log = AppLogger('Registration');
  final _pageController = PageController();
  int _currentStep = 0;
  bool _isSaving = false;
  String? _authError;

  // Form state
  int _birthYear = 1985;
  String? _gender;
  int _height = 170;
  int _weight = 70;
  String? _diet;
  List<String> _symptoms = [];
  List<String> _intolerances = [];
  Map<String, List<String>> _triggers = {};

  // Dynamic: the 8th step is only present for OAuth sign-ins that didn't
  // return a usable real email (Apple Hide-My-Email or empty).
  int get _totalSteps => _showEmailCapture ? 8 : 7;

  bool _showEmailCapture = false;
  String? _capturedEmail;

  void _goToStep(int step) {
    _pageController.animateToPage(
      step,
      duration: AppConstants.animMedium,
      curve: Curves.easeInOut,
    );
    setState(() => _currentStep = step);
  }

  bool get _canAdvance {
    return switch (_currentStep) {
      1 => _gender != null, // Gender is mandatory
      3 => _diet != null, // Diet is mandatory
      _ => true,
    };
  }

  void _next() {
    if (_currentStep < _totalSteps - 1 && _canAdvance) {
      HapticService.light();
      _goToStep(_currentStep + 1);
    }
  }

  void _back() {
    HapticService.light();
    _goToStep(_currentStep - 1);
  }

  bool _needsEmailCapture(User? user) {
    final email = user?.email;
    if (email == null || email.isEmpty) return true;
    return email.toLowerCase().endsWith(AppConstants.appleRelayEmailSuffix);
  }

  Future<void> _createProfile() async {
    // If we've reached the capture step, the wizard already judged
    // authUser.email unusable (null/empty/Apple relay). In that case use
    // only the typed value — a null here means the user skipped, and we
    // must NOT silently persist the relay in profiles.email. Otherwise
    // (OAuth already returned a real email, or email+password) fall back
    // to the auth-provided address.
    final authUser = ref.read(authRepositoryProvider).currentUser;
    final email = _showEmailCapture ? _capturedEmail : authUser?.email;
    final profile = UserProfile(
      birthYear: _birthYear,
      gender: _gender,
      height: _height,
      weight: _weight,
      diet: _diet,
      symptoms: _symptoms,
      intolerances: _intolerances,
      fructoseTriggers: _triggers['Fruktose'] ?? [],
      lactoseTriggers: _triggers['Laktose'] ?? [],
      histaminTriggers: _triggers['Histamin'] ?? [],
      email: email,
    );
    await ref.read(profileProvider.notifier).createProfile(profile);
  }

  Future<void> _handleEmailSignUp(String email, String password) async {
    setState(() {
      _isSaving = true;
      _authError = null;
    });
    try {
      await ref
          .read(authNotifierProvider.notifier)
          .signUpWithEmail(email, password);
      await _createProfile();
      if (mounted) context.go(RoutePaths.dashboard);
    } catch (e) {
      _log.error('email sign-up failed', e);
      if (mounted) {
        setState(() => _authError = _mapSignUpError(e));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _mapSignUpError(Object e) {
    if (e is AuthWeakPasswordException) {
      // Only claim the password is in a breach when the backend explicitly
      // says so — `reasons` may also be `length` / `characters` / etc.
      if (e.reasons.contains('pwned')) {
        return 'Dieses Passwort wurde in einem Datenleck gefunden. '
            'Bitte wähle ein anderes.';
      }
      return 'Dieses Passwort ist zu unsicher. Bitte wähle ein stärkeres.';
    }
    if (e is AuthApiException && e.code == 'user_already_exists') {
      return 'Diese E-Mail ist bereits registriert. Bitte melde dich an.';
    }
    return 'Registrierung fehlgeschlagen.';
  }

  Future<void> _handleGoogleSignUp() async {
    setState(() {
      _isSaving = true;
      _authError = null;
    });
    try {
      await ref.read(authNotifierProvider.notifier).signInWithGoogle();
      await _finalizeAfterOAuthSignIn();
    } catch (e) {
      _log.error('google sign-up failed', e);
      if (mounted) {
        setState(() => _authError = 'Google-Anmeldung fehlgeschlagen.');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleAppleSignUp() async {
    setState(() {
      _isSaving = true;
      _authError = null;
    });
    try {
      await ref.read(authNotifierProvider.notifier).signInWithApple();
      await _finalizeAfterOAuthSignIn();
    } catch (e) {
      _log.error('apple sign-up failed', e);
      if (mounted) {
        setState(() => _authError = 'Apple-Anmeldung fehlgeschlagen.');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _finalizeAfterOAuthSignIn() async {
    if (!mounted) return;
    final user = ref.read(authRepositoryProvider).currentUser;
    if (_needsEmailCapture(user)) {
      setState(() => _showEmailCapture = true);
      // Defer _goToStep until after the rebuild that materialises the 8th
      // PageView child; animating to an index that doesn't exist yet is
      // undefined behaviour.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _goToStep(7);
      });
      return;
    }
    await _createProfile();
    if (mounted) context.go(RoutePaths.dashboard);
  }

  Future<void> _handleEmailCaptureSubmit() async {
    // Re-entry guard against races between tap registration and the button
    // disabling itself once isLoading flows to true in the next frame.
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
      _authError = null;
    });
    try {
      await _createProfile();
      if (mounted) context.go(RoutePaths.dashboard);
    } catch (e) {
      _log.error('profile create after email capture failed', e);
      if (mounted) {
        setState(
          () =>
              _authError = 'Speichern fehlgeschlagen. Bitte erneut versuchen.',
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleEmailCaptureSkip() async {
    // Apple's Sign in with Apple policy prohibits forcing the user to
    // share a real address; this path creates the profile with a null
    // email. _createProfile's capture-step branch already passes null
    // when _capturedEmail is null, so we just clear the field and reuse
    // the submit flow.
    if (_isSaving) return;
    setState(() => _capturedEmail = null);
    await _handleEmailCaptureSubmit();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.spacingMd,
                AppConstants.spacingMd,
                AppConstants.spacingMd,
                AppConstants.spacingSm,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppConstants.radiusXs),
                child: LinearProgressIndicator(
                  value: (_currentStep + 1) / _totalSteps,
                  backgroundColor: AppTheme.muted,
                  valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
                  minHeight: 6,
                ),
              ),
            ),
            // Steps
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  BirthYearStep(
                    value: _birthYear,
                    onChanged: (v) => setState(() => _birthYear = v),
                  ),
                  GenderStep(
                    value: _gender,
                    onChanged: (v) => setState(() => _gender = v),
                  ),
                  HeightWeightStep(
                    height: _height,
                    weight: _weight,
                    onHeightChanged: (v) => setState(() => _height = v),
                    onWeightChanged: (v) => setState(() => _weight = v),
                  ),
                  DietStep(
                    value: _diet,
                    onChanged: (v) => setState(() => _diet = v),
                  ),
                  SymptomsStep(
                    selected: _symptoms,
                    onChanged: (v) => setState(() => _symptoms = v),
                  ),
                  IntolerancesStep(
                    selected: _intolerances,
                    onChanged: (v) => setState(() => _intolerances = v),
                    triggers: _triggers,
                    onTriggersChanged: (intolerance, t) => setState(
                      () => _triggers = {..._triggers, intolerance: t},
                    ),
                  ),
                  AuthStep(
                    isLoading: _isSaving,
                    error: _authError,
                    onEmailSignUp: _handleEmailSignUp,
                    onGoogleSignUp: _handleGoogleSignUp,
                    onAppleSignUp: _handleAppleSignUp,
                  ),
                  if (_showEmailCapture)
                    EmailCaptureStep(
                      value: _capturedEmail,
                      isLoading: _isSaving,
                      error: _authError,
                      // Plain assignment: the wizard only reads _capturedEmail
                      // at submit time, so per-keystroke rebuilds of the entire
                      // wizard tree are pure waste. The step drives its own
                      // button-enabled state via its internal controller.
                      onChanged: (v) => _capturedEmail = v,
                      onSubmit: _handleEmailCaptureSubmit,
                      onSkip: _handleEmailCaptureSkip,
                    ),
                ],
              ),
            ),
            // Next button — only shown on pre-auth pages (not AuthStep, not EmailCaptureStep)
            if (_currentStep < 6)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingLg,
                ),
                child: BbButton(
                  tapKey: RegistrationWizardScreen.nextButtonKey,
                  label: 'Weiter',
                  icon: Icons.arrow_forward,
                  onPressed: _canAdvance ? _next : null,
                ),
              ),
            // Back button — shown everywhere except on EmailCaptureStep
            if (_currentStep < 7)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppConstants.spacingLg,
                  AppConstants.spacingSm,
                  AppConstants.spacingLg,
                  AppConstants.spacingLg,
                ),
                child: TextButton.icon(
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: _currentStep == 0
                      ? const Text('Zur Anmeldung')
                      : const Text('Zurück'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.mutedForeground,
                  ),
                  onPressed: () {
                    HapticService.light();
                    FocusManager.instance.primaryFocus?.unfocus();

                    if (_currentStep == 0) {
                      context.go(RoutePaths.auth);
                    } else {
                      _back();
                    }
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
