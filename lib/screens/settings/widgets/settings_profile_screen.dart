import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../utils/logger.dart';
import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../config/symptom_options.dart';
import '../../../models/user_profile.dart';
import '../../../providers/profile_provider.dart';
import '../../../utils/intolerance_helpers.dart';
import '../../../utils/profile_limits.dart';
import '../../../widgets/common/bb_async_state.dart';
import '../../../widgets/common/bb_chip_selector.dart';
import '../../../widgets/common/settings_section_card.dart';
import 'diet_selector.dart';
import 'intolerance_section.dart';

class SettingsProfileScreen extends ConsumerStatefulWidget {
  const SettingsProfileScreen({super.key});

  @override
  ConsumerState<SettingsProfileScreen> createState() =>
      _SettingsProfileScreenState();
}

class _SettingsProfileScreenState extends ConsumerState<SettingsProfileScreen> {
  static const _log = AppLogger('SettingsProfile');
  Timer? _debounce;
  bool _saved = false;

  /// Hides „Gespeichert" again.
  Timer? _savedTimer;

  final _birthYearController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  bool _controllersInitialized = false;

  /// Typed body data is saved once typing rests ([_bodyDebounce]) or the
  /// field is left, and only the values in the registration's ranges.
  Timer? _bodyDebounce;
  String? _birthYearError;
  String? _heightError;
  String? _weightError;

  /// The profile as last built, and the notifier: a pending save still
  /// runs when the screen is left before typing rested.
  UserProfile? _latest;
  late final ProfileNotifier _profileNotifier = ref.read(
    profileProvider.notifier,
  );

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _profileNotifier.fetchProfile());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _savedTimer?.cancel();
    if (_bodyDebounce?.isActive ?? false) _saveBodyData(leaving: true);
    _bodyDebounce?.cancel();
    _birthYearController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  ({int? value, String? error}) _birthYear() => ProfileLimits.birthYear(
    _birthYearController.text,
    currentYear: DateTime.now().year,
  );

  ({int? value, String? error}) _height() =>
      ProfileLimits.height(_heightController.text);

  ({int? value, String? error}) _weight() =>
      ProfileLimits.weight(_weightController.text);

  /// A keystroke in a body data field: an error shown for it goes away as
  /// soon as the value is valid; the save waits until typing rests.
  void _onBodyDataChanged() {
    final clear = (
      birthYear: _birthYearError != null && _birthYear().error == null,
      height: _heightError != null && _height().error == null,
      weight: _weightError != null && _weight().error == null,
    );
    if (clear.birthYear || clear.height || clear.weight) {
      setState(() {
        if (clear.birthYear) _birthYearError = null;
        if (clear.height) _heightError = null;
        if (clear.weight) _weightError = null;
      });
    }
    _bodyDebounce?.cancel();
    _bodyDebounce = Timer(AppConstants.debounceDuration, _saveBodyData);
  }

  /// Shows the errors of the body data fields (unless [leaving] the
  /// screen) and saves their valid values that changed.
  void _saveBodyData({bool leaving = false}) {
    _bodyDebounce?.cancel();
    final birthYear = _birthYear();
    final height = _height();
    final weight = _weight();
    if (!leaving && mounted) {
      setState(() {
        _birthYearError = birthYear.error;
        _heightError = height.error;
        _weightError = weight.error;
      });
    }
    final latest = _latest;
    if (latest == null) return;
    final next = latest.copyWith(
      birthYear: birthYear.value ?? latest.birthYear,
      height: height.value ?? latest.height,
      weight: weight.value ?? latest.weight,
    );
    if (next == latest) return;
    _latest = next;
    unawaited(_saveImmediately(next));
  }

  void _initControllers(UserProfile profile) {
    if (_controllersInitialized) return;
    _controllersInitialized = true;
    _birthYearController.text = profile.birthYear?.toString() ?? '';
    _heightController.text = profile.height?.toString() ?? '';
    _weightController.text = profile.weight?.toString() ?? '';
  }

  Future<void> _saveImmediately(UserProfile profile) async {
    try {
      await _profileNotifier.updateProfile(profile);
      if (mounted) {
        setState(() => _saved = true);
        _savedTimer?.cancel();
        _savedTimer = Timer(const Duration(seconds: 2), () {
          if (mounted) setState(() => _saved = false);
        });
      }
    } catch (e) {
      _log.error('failed to save profile', e);
    }
  }

  void _debounceSave(UserProfile profile) {
    _debounce?.cancel();
    _debounce = Timer(
      AppConstants.debounceDuration,
      () => _saveImmediately(profile),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: AppTheme.screenBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.screenBackground,
        title: const Text('Mein Profil'),
        actions: [
          if (_saved)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  'Gespeichert',
                  style: TextStyle(
                    color: AppTheme.successText,
                    fontSize: AppTheme.fontSizeBody,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: profileState.when(
        loading: () => const BbLoadingState(message: 'Profil laden...'),
        error: (e, _) => BbErrorState(
          message: 'Fehler beim Laden des Profils.',
          onRetry: () => ref.read(profileProvider.notifier).fetchProfile(),
        ),
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Kein Profil gefunden.'));
          }
          _initControllers(profile);
          _latest = profile;
          return SingleChildScrollView(
            padding: AppConstants.paddingLg,
            // The number keypad has no „Fertig": dragging the page or
            // tapping outside a field closes it.
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Personal data section
                SettingsSectionCard(
                  icon: Icons.calendar_today_outlined,
                  title: 'Persönliche Daten',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _BodyDataField(
                        controller: _birthYearController,
                        maxLength: 4,
                        decoration: InputDecoration(
                          labelText: 'Geburtsjahr',
                          hintText: '1990',
                          prefixIcon: const Icon(Icons.cake_outlined),
                          errorText: _birthYearError,
                          errorMaxLines: 2,
                        ),
                        onChanged: _onBodyDataChanged,
                        onDone: _saveBodyData,
                      ),
                      AppConstants.gap16,
                      DropdownButtonFormField<String>(
                        initialValue: profile.gender,
                        decoration: const InputDecoration(
                          labelText: 'Geschlecht',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: null,
                            child: Text('Auswählen'),
                          ),
                          DropdownMenuItem(
                            value: 'weiblich',
                            child: Text('Weiblich'),
                          ),
                          DropdownMenuItem(
                            value: 'männlich',
                            child: Text('Männlich'),
                          ),
                          DropdownMenuItem(
                            value: 'andere',
                            child: Text('Andere'),
                          ),
                        ],
                        onChanged: (v) =>
                            _debounceSave(profile.copyWith(gender: v)),
                      ),
                      AppConstants.gap16,
                      Row(
                        children: [
                          Expanded(
                            child: _BodyDataField(
                              controller: _heightController,
                              maxLength: 3,
                              decoration: InputDecoration(
                                labelText: 'Größe (cm)',
                                errorText: _heightError,
                                errorMaxLines: 3,
                              ),
                              onChanged: _onBodyDataChanged,
                              onDone: _saveBodyData,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _BodyDataField(
                              controller: _weightController,
                              maxLength: 3,
                              decoration: InputDecoration(
                                labelText: 'Gewicht (kg)',
                                errorText: _weightError,
                                errorMaxLines: 3,
                              ),
                              onChanged: _onBodyDataChanged,
                              onDone: _saveBodyData,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                AppConstants.gap16,

                // Diet section
                SettingsSectionCard(
                  icon: Icons.restaurant_outlined,
                  title: 'Ernährung',
                  child: DietSelector(
                    currentDiet: profile.diet,
                    onChanged: (diet) =>
                        _debounceSave(profile.copyWith(diet: diet)),
                  ),
                ),
                AppConstants.gap16,

                // Symptoms section
                SettingsSectionCard(
                  icon: Icons.monitor_heart_outlined,
                  title: 'Symptome',
                  child: BbChipSelector(
                    options: [for (final s in kSymptomOptions) s.value],
                    labelOf: symptomLabel,
                    selected: profile.symptoms,
                    onChanged: (v) =>
                        _saveImmediately(profile.copyWith(symptoms: v)),
                  ),
                ),
                AppConstants.gap16,

                // Intolerances section
                SettingsSectionCard(
                  icon: Icons.warning_amber_outlined,
                  title: 'Unverträglichkeiten',
                  child: IntoleranceSection(
                    profile: profile,
                    onIntolerancesChanged: (v) =>
                        _saveImmediately(profile.copyWith(intolerances: v)),
                    onTriggersChanged: (intolerance, triggers) {
                      final updated = IntoleranceHelpers.updateTriggers(
                        intolerance,
                        profile,
                        triggers,
                      );
                      _saveImmediately(updated);
                    },
                  ),
                ),
                AppConstants.gap32,
              ],
            ),
          );
        },
      ),
    );
  }
}

/// A number field of the body data. Tapping outside it closes the number
/// keypad (it has no „Fertig"); leaving it ([onDone]) saves right away.
class _BodyDataField extends StatelessWidget {
  const _BodyDataField({
    required this.controller,
    required this.maxLength,
    required this.decoration,
    required this.onChanged,
    required this.onDone,
  });

  final TextEditingController controller;
  final int maxLength;
  final InputDecoration decoration;
  final VoidCallback onChanged;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (focused) {
        if (!focused) onDone();
      },
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(maxLength),
        ],
        decoration: decoration,
        onChanged: (_) => onChanged(),
        onSubmitted: (_) => onDone(),
        onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      ),
    );
  }
}
