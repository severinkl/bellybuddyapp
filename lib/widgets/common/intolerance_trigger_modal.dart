import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../config/constants.dart';

/// Trigger options per intolerance type.
const Map<String, List<String>> intoleranceTriggerOptions = {
  'Fruktose': [
    'Nach einem Glas Fruchtsaft',
    'Nach einer Apfelscheibe',
  ],
  'Laktose': [
    'Nach einem Glas Milch',
    'Wenn Milch in Teig vorhanden ist',
  ],
  'Histamin': [
    'Nach Rotwein',
    'Nach gereiftem Käse',
    'Nach fermentierten Lebensmitteln',
    'Nach Schokolade',
  ],
};

/// Intolerances that have trigger options.
const triggerIntolerances = ['Fruktose', 'Laktose', 'Histamin'];

/// Shows a bottom-sheet modal for selecting trigger foods for a given intolerance.
void showIntoleranceTriggerModal({
  required BuildContext context,
  required String intolerance,
  required List<String> currentTriggers,
  required ValueChanged<List<String>> onChanged,
}) {
  final options = intoleranceTriggerOptions[intolerance];
  if (options == null) return;

  showModalBottomSheet(
    context: context,
    builder: (context) => _IntoleranceTriggerModal(
      intolerance: intolerance,
      triggers: currentTriggers,
      options: options,
      onChanged: onChanged,
    ),
  );
}

class _IntoleranceTriggerModal extends StatefulWidget {
  final String intolerance;
  final List<String> triggers;
  final List<String> options;
  final ValueChanged<List<String>> onChanged;

  const _IntoleranceTriggerModal({
    required this.intolerance,
    required this.triggers,
    required this.options,
    required this.onChanged,
  });

  @override
  State<_IntoleranceTriggerModal> createState() =>
      _IntoleranceTriggerModalState();
}

class _IntoleranceTriggerModalState extends State<_IntoleranceTriggerModal> {
  late List<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.triggers);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppConstants.paddingLg,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Wann bemerkst du ${widget.intolerance}?',
            style: const TextStyle(
              fontSize: AppTheme.fontSizeTitleLG,
              fontWeight: FontWeight.w600,
              color: AppTheme.foreground,
            ),
          ),
          AppConstants.gap16,
          ...widget.options.map((option) {
            final isSelected = _selected.contains(option);
            return CheckboxListTile(
              value: isSelected,
              title: Text(option),
              activeColor: AppTheme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              ),
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _selected.add(option);
                  } else {
                    _selected.remove(option);
                  }
                });
                widget.onChanged(List.from(_selected));
              },
            );
          }),
          AppConstants.gap16,
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
