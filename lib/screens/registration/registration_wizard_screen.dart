import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';
import '../../models/user_profile.dart';
import '../../providers/profile_provider.dart';
import '../../router/route_names.dart';
import '../../services/haptic_service.dart';
import '../../widgets/common/bb_button.dart';
import 'steps/birth_year_step.dart';
import 'steps/gender_step.dart';
import 'steps/height_weight_step.dart';
import 'steps/diet_step.dart';
import 'steps/symptoms_step.dart';
import 'steps/intolerances_step.dart';
import 'steps/completion_step.dart';

class RegistrationWizardScreen extends ConsumerStatefulWidget {
  const RegistrationWizardScreen({super.key});

  @override
  ConsumerState<RegistrationWizardScreen> createState() =>
      _RegistrationWizardScreenState();
}

class _RegistrationWizardScreenState
    extends ConsumerState<RegistrationWizardScreen> {
  final _pageController = PageController();
  int _currentStep = 0;
  bool _isSaving = false;

  // Form state
  int? _birthYear;
  String? _gender;
  int? _height;
  int? _weight;
  String? _diet;
  List<String> _symptoms = [];
  List<String> _intolerances = [];
  List<String> _fructoseTriggers = [];
  List<String> _lactoseTriggers = [];
  List<String> _histaminTriggers = [];

  static const _totalSteps = 7;

  void _goToStep(int step) {
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() => _currentStep = step);
  }

  void _next() {
    if (_currentStep < _totalSteps - 1) {
      HapticService.light();
      _goToStep(_currentStep + 1);
    }
  }

  void _back() {
    if (_currentStep > 0) {
      HapticService.light();
      _goToStep(_currentStep - 1);
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      final profile = UserProfile(
        birthYear: _birthYear,
        gender: _gender,
        height: _height,
        weight: _weight,
        diet: _diet,
        symptoms: _symptoms,
        intolerances: _intolerances,
        fructoseTriggers: _fructoseTriggers,
        lactoseTriggers: _lactoseTriggers,
        histaminTriggers: _histaminTriggers,
      );
      await ref.read(profileProvider.notifier).createProfile(profile);
      if (mounted) context.go(RoutePaths.dashboard);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fehler beim Speichern des Profils.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: _back,
                    )
                  else
                    const SizedBox(width: 48),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (_currentStep + 1) / _totalSteps,
                        backgroundColor: AppTheme.muted,
                        valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
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
                    fructoseTriggers: _fructoseTriggers,
                    onFructoseTriggersChanged: (v) =>
                        setState(() => _fructoseTriggers = v),
                    lactoseTriggers: _lactoseTriggers,
                    onLactoseTriggersChanged: (v) =>
                        setState(() => _lactoseTriggers = v),
                    histaminTriggers: _histaminTriggers,
                    onHistaminTriggersChanged: (v) =>
                        setState(() => _histaminTriggers = v),
                  ),
                  CompletionStep(
                    isSaving: _isSaving,
                    onSave: _saveProfile,
                  ),
                ],
              ),
            ),
            // Next button (not on last step)
            if (_currentStep < _totalSteps - 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: BbButton(
                  label: 'Weiter',
                  onPressed: _next,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
