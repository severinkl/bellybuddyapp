import 'package:flutter/foundation.dart';
import '../../../../models/gut_feeling_entry.dart';

/// Bundles gut-feeling edit values and callbacks to reduce parameter count
/// on [GutFeelingDetail].
class GutFeelingEditState {
  final int bloating;
  final int gas;
  final int cramps;
  final int fullness;
  final int? stress;
  final int? happiness;
  final int? energy;
  final int? focus;
  final int? bodyFeel;

  final ValueChanged<int> onBloatingChanged;
  final ValueChanged<int> onGasChanged;
  final ValueChanged<int> onCrampsChanged;
  final ValueChanged<int> onFullnessChanged;
  final ValueChanged<int> onStressChanged;
  final ValueChanged<int> onHappinessChanged;
  final ValueChanged<int> onEnergyChanged;
  final ValueChanged<int> onFocusChanged;
  final ValueChanged<int> onBodyFeelChanged;

  const GutFeelingEditState({
    required this.bloating,
    required this.gas,
    required this.cramps,
    required this.fullness,
    this.stress,
    this.happiness,
    this.energy,
    this.focus,
    this.bodyFeel,
    required this.onBloatingChanged,
    required this.onGasChanged,
    required this.onCrampsChanged,
    required this.onFullnessChanged,
    required this.onStressChanged,
    required this.onHappinessChanged,
    required this.onEnergyChanged,
    required this.onFocusChanged,
    required this.onBodyFeelChanged,
  });

  factory GutFeelingEditState.fromEntry(
    GutFeelingEntry entry, {
    required ValueChanged<int> onBloatingChanged,
    required ValueChanged<int> onGasChanged,
    required ValueChanged<int> onCrampsChanged,
    required ValueChanged<int> onFullnessChanged,
    required ValueChanged<int> onStressChanged,
    required ValueChanged<int> onHappinessChanged,
    required ValueChanged<int> onEnergyChanged,
    required ValueChanged<int> onFocusChanged,
    required ValueChanged<int> onBodyFeelChanged,
  }) {
    return GutFeelingEditState(
      bloating: entry.bloating,
      gas: entry.gas,
      cramps: entry.cramps,
      fullness: entry.fullness,
      stress: entry.stress,
      happiness: entry.happiness,
      energy: entry.energy,
      focus: entry.focus,
      bodyFeel: entry.bodyFeel,
      onBloatingChanged: onBloatingChanged,
      onGasChanged: onGasChanged,
      onCrampsChanged: onCrampsChanged,
      onFullnessChanged: onFullnessChanged,
      onStressChanged: onStressChanged,
      onHappinessChanged: onHappinessChanged,
      onEnergyChanged: onEnergyChanged,
      onFocusChanged: onFocusChanged,
      onBodyFeelChanged: onBodyFeelChanged,
    );
  }
}
