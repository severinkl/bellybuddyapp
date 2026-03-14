import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../widgets/common/bb_chip_selector.dart';
import '../../../widgets/common/mascot_image.dart';

class IntolerancesStep extends StatelessWidget {
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;
  final List<String> fructoseTriggers;
  final ValueChanged<List<String>> onFructoseTriggersChanged;
  final List<String> lactoseTriggers;
  final ValueChanged<List<String>> onLactoseTriggersChanged;
  final List<String> histaminTriggers;
  final ValueChanged<List<String>> onHistaminTriggersChanged;

  const IntolerancesStep({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.fructoseTriggers,
    required this.onFructoseTriggersChanged,
    required this.lactoseTriggers,
    required this.onLactoseTriggersChanged,
    required this.histaminTriggers,
    required this.onHistaminTriggersChanged,
  });

  void _showTriggerModal(BuildContext context, String intolerance) {
    List<String> triggers;
    List<String> options;
    ValueChanged<List<String>> onTriggersChanged;

    switch (intolerance) {
      case 'Fruktose':
        triggers = fructoseTriggers;
        options = const [
          'Nach einem Glas Fruchtsaft',
          'Nach einer Apfelscheibe',
        ];
        onTriggersChanged = onFructoseTriggersChanged;
        break;
      case 'Laktose':
        triggers = lactoseTriggers;
        options = const [
          'Nach einem Glas Milch',
          'Wenn Milch in Teig vorhanden ist',
        ];
        onTriggersChanged = onLactoseTriggersChanged;
        break;
      case 'Histamin':
        triggers = histaminTriggers;
        options = const [
          'Nach Rotwein',
          'Nach gereiftem Käse',
          'Nach fermentierten Lebensmitteln',
          'Nach Schokolade',
        ];
        onTriggersChanged = onHistaminTriggersChanged;
        break;
      default:
        return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => _TriggerModal(
        intolerance: intolerance,
        triggers: triggers,
        options: options,
        onChanged: onTriggersChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          const MascotImage(assetPath: AppConstants.mascotNervous, width: 120, height: 120),
          const SizedBox(height: 16),
          const Text(
            'Wurden dir Unverträglichkeiten diagnostiziert?',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppTheme.foreground,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Gib hier ärztlich diagnostizierte Unverträglichkeiten an. Diese Angaben helfen uns bei der personalisierten Analyse deiner Mahlzeiten.',
            style: TextStyle(fontSize: 15, color: AppTheme.mutedForeground),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          BbChipSelector(
            options: AppConstants.intoleranceOptions,
            selected: selected,
            onChanged: (newSelected) {
              // Check if a trigger-eligible intolerance was just added
              final added = newSelected.where((s) => !selected.contains(s));
              onChanged(newSelected);
              for (final item in added) {
                if (['Fruktose', 'Laktose', 'Histamin'].contains(item)) {
                  Future.microtask(() => _showTriggerModal(context, item));
                }
              }
            },
          ),
        ],
      ),
    );
  }
}

class _TriggerModal extends StatefulWidget {
  final String intolerance;
  final List<String> triggers;
  final List<String> options;
  final ValueChanged<List<String>> onChanged;

  const _TriggerModal({
    required this.intolerance,
    required this.triggers,
    required this.options,
    required this.onChanged,
  });

  @override
  State<_TriggerModal> createState() => _TriggerModalState();
}

class _TriggerModalState extends State<_TriggerModal> {
  late List<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.triggers);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Wann bemerkst du ${widget.intolerance}?',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppTheme.foreground,
            ),
          ),
          const SizedBox(height: 16),
          ...widget.options.map((option) {
            final isSelected = _selected.contains(option);
            return CheckboxListTile(
              value: isSelected,
              title: Text(option),
              activeColor: AppTheme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _selected.add(option);
                  } else {
                    _selected.remove(option);
                  }
                });
                widget.onChanged(_selected);
              },
            );
          }),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fertig'),
          ),
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
        ],
      ),
    );
  }
}
