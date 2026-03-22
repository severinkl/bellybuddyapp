import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../utils/logger.dart';
import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../models/user_profile.dart';
import '../../../providers/profile_provider.dart';
import '../../../utils/intolerance_helpers.dart';
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

  final _birthYearController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  bool _controllersInitialized = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(profileProvider.notifier).fetchProfile());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _birthYearController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
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
      await ref.read(profileProvider.notifier).updateProfile(profile);
      if (mounted) {
        setState(() => _saved = true);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _saved = false);
        });
      }
    } catch (e) {
      _log.error('failed to save profile', e);
    }
  }

  void _debounceSave(UserProfile profile) {
    _debounce?.cancel();
    _debounce = Timer(AppConstants.debounceDuration, () async {
      try {
        await ref.read(profileProvider.notifier).updateProfile(profile);
        if (mounted) {
          setState(() => _saved = true);
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) setState(() => _saved = false);
          });
        }
      } catch (e) {
        _log.error('failed to save profile', e);
      }
    });
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
                    color: AppTheme.success,
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
          return SingleChildScrollView(
            padding: AppConstants.paddingLg,
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
                      TextField(
                        controller: _birthYearController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Geburtsjahr',
                          hintText: '1990',
                          prefixIcon: Icon(Icons.cake_outlined),
                        ),
                        onChanged: (v) {
                          final year = int.tryParse(v);
                          if (year != null && v.length == 4) {
                            _debounceSave(profile.copyWith(birthYear: year));
                          }
                        },
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
                            child: TextField(
                              controller: _heightController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(3),
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Größe (cm)',
                              ),
                              onChanged: (v) {
                                final height = int.tryParse(v);
                                _debounceSave(profile.copyWith(height: height));
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _weightController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(3),
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Gewicht (kg)',
                              ),
                              onChanged: (v) {
                                final weight = int.tryParse(v);
                                _debounceSave(profile.copyWith(weight: weight));
                              },
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
                    options: AppConstants.symptomOptions,
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
