import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../utils/logger.dart';
import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../models/user_profile.dart';
import '../../../providers/profile_provider.dart';
import '../../../widgets/common/bb_chip_selector.dart';
import '../../../widgets/common/bb_scroll_picker.dart';
import '../../../widgets/common/intolerance_trigger_modal.dart';

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

  static const _symptoms = [
    'Blähungen', 'Bauchschmerzen', 'Durchfall', 'Verstopfung',
    'Übelkeit', 'Sodbrennen', 'Krämpfe', 'Völlegefühl',
  ];

  static const _intolerances = [
    'Laktose', 'Gluten', 'Fruktose', 'Histamin', 'Sorbit',
    'Nüsse', 'Eier', 'Soja', 'Weizen',
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(profileProvider.notifier).fetchProfile());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
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
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Birth year
                const Text('Geburtsjahr', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                BbScrollPicker(
                  items: List.generate(100, (i) => DateTime.now().year - 10 - i),
                  selectedValue: profile.birthYear,
                  onChanged: (v) => _debounceSave(profile.copyWith(birthYear: v)),
                ),
                const SizedBox(height: 24),

                // Gender
                const Text('Geschlecht', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'weiblich', label: Text('Weiblich')),
                    ButtonSegment(value: 'männlich', label: Text('Männlich')),
                    ButtonSegment(value: 'andere', label: Text('Andere')),
                  ],
                  selected: {profile.gender ?? 'andere'},
                  onSelectionChanged: (v) =>
                      _debounceSave(profile.copyWith(gender: v.first)),
                ),
                const SizedBox(height: 24),

                // Diet
                const Text('Ernährung', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'alles', label: Text('Alles')),
                    ButtonSegment(value: 'vegetarisch', label: Text('Vegetarisch')),
                    ButtonSegment(value: 'vegan', label: Text('Vegan')),
                  ],
                  selected: {profile.diet ?? 'alles'},
                  onSelectionChanged: (v) =>
                      _debounceSave(profile.copyWith(diet: v.first)),
                ),
                const SizedBox(height: 24),

                // Symptoms
                const Text('Symptome', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                BbChipSelector(
                  options: _symptoms,
                  selected: profile.symptoms,
                  onChanged: (v) => _debounceSave(profile.copyWith(symptoms: v)),
                ),
                const SizedBox(height: 24),

                // Intolerances
                const Text('Unverträglichkeiten', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                BbChipSelector(
                  options: _intolerances,
                  selected: profile.intolerances,
                  chipColorBuilder: AppTheme.chipColorForIntolerance,
                  onChanged: (v) {
                    final added = v.where((s) => !profile.intolerances.contains(s));
                    _debounceSave(profile.copyWith(intolerances: v));
                    for (final item in added) {
                      if (triggerIntolerances.contains(item)) {
                        Future.microtask(() {
                          if (!mounted) return;
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

                // Show trigger management buttons for active trigger intolerances
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
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }
}
