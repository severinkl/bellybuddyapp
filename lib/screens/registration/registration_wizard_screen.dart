import 'dart:async';
import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_theme.dart';
import '../../config/buddy_reactions.dart';
import '../../config/constants.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/buddy_provider.dart';
import '../../providers/profile_provider.dart';
import '../../repositories/auth_repository.dart';
import '../../router/route_names.dart';
import '../../services/haptic_service.dart';
import '../../utils/logger.dart';
import '../../widgets/buddy/buddy.dart';
import '../../widgets/common/bb_button.dart';
import '../buddy/buddy_onboarding_screen.dart' show BuddyOnboardingEntry;
import 'steps/auth_step.dart';
import 'steps/buddy_name_step.dart';
import 'steps/email_capture_step.dart';
import 'steps/birth_year_step.dart';
import 'steps/gender_step.dart';
import 'steps/health_consent_step.dart';
import 'steps/height_weight_step.dart';
import 'steps/diet_step.dart';
import 'steps/symptoms_step.dart';
import 'steps/intolerances_step.dart';
import 'widgets/buddy_step_host.dart';

/// The registration wizard, hosted by the Buddy: the user names him first,
/// gives the health consent, answers the profile questions (he reacts to
/// every answer) and signs up. Afterwards the profile and his name are
/// saved and the Buddy onboarding (`/buddy-onboarding`) takes over.
class RegistrationWizardScreen extends ConsumerStatefulWidget {
  const RegistrationWizardScreen({super.key});

  static const nextButtonKey = Key('registration_next_button');

  /// After a reaction to leaving a step (the name, „no symptoms", „no
  /// intolerances"), the next step's intro line waits this long.
  static const buddyFollowUpDelay = Duration(seconds: 3);

  /// The Buddy reacts to a scroll picker (birth year, height/weight) once it
  /// has rested this long, not on every item scrolled past.
  static const buddyPickerSettle = AppConstants.debounceDuration;

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

  // Wizard page indices. The Buddy's name comes first; the health consent
  // follows right after it, so no health data is collected before the user
  // has explicitly consented (GDPR Art. 9).
  static const _nameStep = 0;
  static const _consentStep = 1;
  static const _birthYearStep = 2;
  static const _genderStep = 3;
  static const _heightWeightStep = 4;
  static const _dietStep = 5;
  static const _symptomsStep = 6;
  static const _intolerancesStep = 7;
  static const _authStep = 8;
  static const _emailCaptureStep = 9;

  /// The Buddy's line when a step appears (catalog keys).
  static const _introKeys = {
    _consentStep: 'consent:intro',
    _birthYearStep: 'step:birthYear',
    _genderStep: 'step:gender',
    _heightWeightStep: 'step:heightWeight',
    _dietStep: 'step:diet',
    _symptomsStep: 'step:symptoms',
    _intolerancesStep: 'step:intolerances',
    _authStep: 'auth:intro',
  };

  /// How long the Buddy's lines stay; every step also has its own title.
  static const _introHold = Duration(seconds: 6);
  static const _reactionHold = Duration(seconds: 4);

  // The Buddy, his name (saved after sign-up) and his pending lines.
  String _buddyName = 'Buddy';
  late final BuddyController _buddy;
  final _rnd = Random();
  Timer? _followUp;
  Timer? _pickerSettle;

  // Form state
  bool _healthConsentChecked = false;
  // Set when the user advances past the consent step with the box ticked;
  // written to the profile together with the policy version.
  DateTime? _healthConsentAt;
  int _birthYear = 1985;
  String? _gender;
  int _height = 170;
  int _weight = 70;
  String? _diet;
  List<String> _symptoms = [];
  List<String> _intolerances = [];
  Map<String, List<String>> _triggers = {};

  // Dynamic: the email-capture step is only present for OAuth sign-ins that
  // didn't return a usable real email (Apple Hide-My-Email or empty).
  int get _totalSteps => _showEmailCapture ? 10 : 9;

  bool _showEmailCapture = false;
  String? _capturedEmail;

  @override
  void initState() {
    super.initState();
    _buddy = BuddyController();
  }

  /// The typed name as it will be saved (trimmed).
  String get _name => _buddyName.trim();

  /// Same rule as [BuddyNotifier.setName]: 1–20 characters after trimming.
  bool get _nameValid {
    final length = _name.runes.length;
    return length > 0 && length <= AppConstants.buddyNameMaxLength;
  }

  /// Shows [step]; the Buddy introduces it. A [farewell] reaction to the
  /// step being left goes first, and the intro follows after
  /// [RegistrationWizardScreen.buddyFollowUpDelay].
  void _goToStep(int step, {BuddyLine? farewell}) {
    _pageController.animateToPage(
      step,
      duration: AppConstants.animMedium,
      curve: Curves.easeInOut,
    );
    setState(() => _currentStep = step);

    final introKey = _introKeys[step];
    final intro = introKey == null ? null : wizardReaction(introKey);
    if (farewell == null) {
      _cancelPendingLines();
      if (intro != null) _react(intro, hold: _introHold);
      return;
    }
    _react(farewell);
    if (intro != null) {
      _followUp = Timer(
        RegistrationWizardScreen.buddyFollowUpDelay,
        () => _react(intro, hold: _introHold),
      );
    }
  }

  void _cancelPendingLines() {
    _followUp?.cancel();
    _followUp = null;
    _pickerSettle?.cancel();
    _pickerSettle = null;
  }

  /// Plays [line]: its mood and action, and one of its texts with `{name}`
  /// filled in. Replaces any line still waiting.
  void _react(BuddyLine line, {Duration hold = _reactionHold}) {
    _cancelPendingLines();
    final mood = line.mood;
    final action = line.action;
    if (mood != null) _buddy.mood = mood;
    if (action != null) _buddy.play(action);
    _buddy.say(line.pick(_rnd).replaceAll('{name}', _name), duration: hold);
  }

  void _reactTo(String key) {
    final line = wizardReaction(key);
    if (line != null) _react(line);
  }

  /// Reacts to [step]'s scroll picker once it rests.
  void _reactWhenSettled(String step) {
    _pickerSettle?.cancel();
    _pickerSettle = Timer(
      RegistrationWizardScreen.buddyPickerSettle,
      () => _reactTo(wizardKey(step)),
    );
  }

  /// The newest of [selected] that isn't in [previous], if any.
  static String? _newest(List<String> selected, List<String> previous) {
    final added = selected.where((s) => !previous.contains(s));
    return added.isEmpty ? null : added.last;
  }

  void _onSymptomsChanged(List<String> symptoms) {
    final added = _newest(symptoms, _symptoms);
    setState(() => _symptoms = symptoms);
    if (added != null) _reactTo(wizardKey('symptom', added));
  }

  void _onIntolerancesChanged(List<String> intolerances) {
    final added = _newest(intolerances, _intolerances);
    setState(() => _intolerances = intolerances);
    if (added != null) _reactTo(wizardKey('intolerance', added));
  }

  bool get _canAdvance {
    return switch (_currentStep) {
      _nameStep => _nameValid, // The Buddy needs a name
      _consentStep => _healthConsentChecked, // Explicit consent is mandatory
      _genderStep => _gender != null, // Gender is mandatory
      _dietStep => _diet != null, // Diet is mandatory
      _ => true,
    };
  }

  /// The Buddy's reaction to leaving the current step, if any.
  BuddyLine? get _farewell => switch (_currentStep) {
    _nameStep => wizardReaction('name:confirmed'),
    _symptomsStep when _symptoms.isEmpty => wizardReaction(
      wizardKey('symptom', 'none'),
    ),
    _intolerancesStep when _intolerances.isEmpty => wizardReaction(
      wizardKey('intolerance', 'none'),
    ),
    _ => null,
  };

  void _next() {
    if (_currentStep < _totalSteps - 1 && _canAdvance) {
      HapticService.light();
      FocusManager.instance.primaryFocus?.unfocus();
      if (_currentStep == _consentStep) {
        _healthConsentAt = DateTime.now().toUtc();
      }
      _goToStep(_currentStep + 1, farewell: _farewell);
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
      // Normally always set (the consent step gates the wizard). If it ever
      // isn't, both stay null and the post-login consent gate asks instead.
      healthConsentAt: _healthConsentAt,
      privacyPolicyVersion: _healthConsentAt == null
          ? null
          : AppConstants.privacyPolicyVersion,
    );
    await ref.read(profileProvider.notifier).createProfile(profile);
  }

  /// Every sign-up path ends here once the user is authenticated: saves the
  /// profile, then the Buddy's name (a failure is logged, not shown: the
  /// onboarding goes on), then hands over to the Buddy onboarding.
  Future<void> _completeRegistration() async {
    await _createProfile();
    if (!mounted) return;
    try {
      await ref.read(buddyProvider.notifier).setName(_name);
    } catch (e, st) {
      _log.error('saving the Buddy name failed', e, st);
    }
    if (!mounted) return;
    context.go(
      RoutePaths.buddyOnboarding,
      extra: BuddyOnboardingEntry.afterRegistration,
    );
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
      await _completeRegistration();
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
      return 'Das Passwort ist zu unsicher.';
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
      // Defer _goToStep until after the rebuild that materialises the
      // email-capture PageView child; animating to an index that doesn't
      // exist yet is undefined behaviour.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _goToStep(_emailCaptureStep);
      });
      return;
    }
    await _completeRegistration();
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
      await _completeRegistration();
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
    _cancelPendingLines();
    _buddy.dispose();
    _pageController.dispose();
    super.dispose();
  }

  /// Steps laid out as a plain column scroll when they don't fit below the
  /// Buddy.
  static Widget _scrollable(Widget step) => SingleChildScrollView(child: step);

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
            // Steps, under the Buddy
            Expanded(
              child: BuddyStepHost(
                controller: _buddy,
                name: _nameValid ? _name : 'Buddy',
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    SingleChildScrollView(
                      padding: AppConstants.paddingLg,
                      child: BuddyNameStep(
                        value: _buddyName,
                        onChanged: (v) => setState(() => _buddyName = v),
                        onSubmitted: _next,
                      ),
                    ),
                    HealthConsentStep(
                      checked: _healthConsentChecked,
                      onChanged: (v) =>
                          setState(() => _healthConsentChecked = v),
                    ),
                    BirthYearStep(
                      value: _birthYear,
                      onChanged: (v) {
                        setState(() => _birthYear = v);
                        _reactWhenSettled('birthYear');
                      },
                    ),
                    _scrollable(
                      GenderStep(
                        value: _gender,
                        onChanged: (v) {
                          setState(() => _gender = v);
                          _reactTo(wizardKey('gender', v));
                        },
                      ),
                    ),
                    HeightWeightStep(
                      height: _height,
                      weight: _weight,
                      onHeightChanged: (v) {
                        setState(() => _height = v);
                        _reactWhenSettled('heightWeight');
                      },
                      onWeightChanged: (v) {
                        setState(() => _weight = v);
                        _reactWhenSettled('heightWeight');
                      },
                    ),
                    _scrollable(
                      DietStep(
                        value: _diet,
                        onChanged: (v) {
                          setState(() => _diet = v);
                          _reactTo(wizardKey('diet', v));
                        },
                      ),
                    ),
                    _scrollable(
                      SymptomsStep(
                        selected: _symptoms,
                        onChanged: _onSymptomsChanged,
                      ),
                    ),
                    IntolerancesStep(
                      selected: _intolerances,
                      onChanged: _onIntolerancesChanged,
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
            ),
            // Next button — only shown on pre-auth pages (not AuthStep, not EmailCaptureStep)
            if (_currentStep < _authStep)
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
            if (_currentStep < _emailCaptureStep)
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
