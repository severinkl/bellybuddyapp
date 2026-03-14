import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../utils/logger.dart';
import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../models/user_profile.dart';
import '../../../providers/profile_provider.dart';
import '../../../services/haptic_service.dart';
import '../../../widgets/common/bb_chip_selector.dart';
import '../../../widgets/common/intolerance_trigger_modal.dart';
import '../../../widgets/common/settings_section_card.dart';

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

  List<String> _triggersFor(String intolerance, UserProfile profile) {
    return switch (intolerance) {
      'Fruktose' => profile.fructoseTriggers,
      'Laktose' => profile.lactoseTriggers,
      'Histamin' => profile.histaminTriggers,
      _ => [],
    };
  }

  UserProfile _updateTriggers(
      String intolerance, UserProfile profile, List<String> triggers) {
    return switch (intolerance) {
      'Fruktose' => profile.copyWith(fructoseTriggers: triggers),
      'Laktose' => profile.copyWith(lactoseTriggers: triggers),
      'Histamin' => profile.copyWith(histaminTriggers: triggers),
      _ => profile,
    };
  }

  static const _dietOptions = ['alles', 'vegetarisch', 'vegan'];
  static const _dietLabels = {'alles': 'Alles', 'vegetarisch': 'Vegetarisch', 'vegan': 'Vegan'};

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mein Profil'),
        actions: [
          if (_saved)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  'Gespeichert',
                  style: TextStyle(color: AppTheme.success, fontSize: 14),
                ),
              ),
            ),
        ],
      ),
      body: profileState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Kein Profil gefunden.'));
          }
          _initControllers(profile);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
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
                      // Birth year
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
                      const SizedBox(height: 16),

                      // Gender dropdown
                      DropdownButtonFormField<String>(
                        initialValue: profile.gender,
                        decoration: const InputDecoration(
                          labelText: 'Geschlecht',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('Auswählen')),
                          DropdownMenuItem(value: 'weiblich', child: Text('Weiblich')),
                          DropdownMenuItem(value: 'männlich', child: Text('Männlich')),
                          DropdownMenuItem(value: 'andere', child: Text('Andere')),
                        ],
                        onChanged: (v) => _debounceSave(profile.copyWith(gender: v)),
                      ),
                      const SizedBox(height: 16),

                      // Height and weight row
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
                                prefixIcon: Icon(Icons.straighten),
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
                                prefixIcon: Icon(Icons.monitor_weight_outlined),
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
                const SizedBox(height: 16),

                // Diet section
                SettingsSectionCard(
                  icon: Icons.restaurant_outlined,
                  title: 'Ernährung',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _dietOptions.map((diet) {
                      final isSelected = (profile.diet ?? 'alles') == diet;
                      return GestureDetector(
                        onTap: () {
                          HapticService.selection();
                          _debounceSave(profile.copyWith(diet: diet));
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.primary : AppTheme.secondary,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            _dietLabels[diet]!,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: isSelected
                                  ? AppTheme.primaryForeground
                                  : AppTheme.foreground,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                // Symptoms section
                SettingsSectionCard(
                  icon: Icons.monitor_heart_outlined,
                  title: 'Symptome',
                  child: BbChipSelector(
                    options: AppConstants.symptomOptions,
                    selected: profile.symptoms,
                    onChanged: (v) => _debounceSave(profile.copyWith(symptoms: v)),
                  ),
                ),
                const SizedBox(height: 16),

                // Intolerances section
                SettingsSectionCard(
                  icon: Icons.warning_amber_outlined,
                  title: 'Unverträglichkeiten',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BbChipSelector(
                        options: AppConstants.intoleranceOptions,
                        selected: profile.intolerances,
                        chipColorBuilder: AppTheme.chipColorForIntolerance,
                        onChanged: (v) {
                          final added = v.where((s) => !profile.intolerances.contains(s));
                          _debounceSave(profile.copyWith(intolerances: v));
                          for (final item in added) {
                            if (triggerIntolerances.contains(item)) {
                              Future.microtask(() {
                                if (!context.mounted) return;
                                showIntoleranceTriggerModal(
                                  context: context,
                                  intolerance: item,
                                  currentTriggers: _triggersFor(item, profile),
                                  onChanged: (triggers) {
                                    final updated = _updateTriggers(item, profile, triggers);
                                    _debounceSave(updated);
                                  },
                                );
                              });
                            }
                          }
                        },
                      ),
                      if (profile.intolerances.any((i) => triggerIntolerances.contains(i))) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: profile.intolerances
                              .where((i) => triggerIntolerances.contains(i))
                              .map((i) => ActionChip(
                                    label: Text('$i Trigger bearbeiten'),
                                    onPressed: () {
                                      showIntoleranceTriggerModal(
                                        context: context,
                                        intolerance: i,
                                        currentTriggers: _triggersFor(i, profile),
                                        onChanged: (triggers) {
                                          final updated = _updateTriggers(i, profile, triggers);
                                          _debounceSave(updated);
                                        },
                                      );
                                    },
                                  ))
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }
}
