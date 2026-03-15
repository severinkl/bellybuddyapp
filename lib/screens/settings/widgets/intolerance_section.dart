import 'package:flutter/material.dart';

import '../../../config/constants.dart';
import '../../../models/user_profile.dart';
import '../../../widgets/common/bb_chip_selector.dart';
import '../../../widgets/common/intolerance_trigger_modal.dart';

class IntoleranceSection extends StatelessWidget {
  final UserProfile profile;
  final ValueChanged<List<String>> onIntolerancesChanged;
  final void Function(String intolerance, List<String> triggers)
      onTriggersChanged;

  const IntoleranceSection({
    super.key,
    required this.profile,
    required this.onIntolerancesChanged,
    required this.onTriggersChanged,
  });

  List<String> _triggersFor(String intolerance) {
    return switch (intolerance) {
      'Fruktose' => profile.fructoseTriggers,
      'Laktose' => profile.lactoseTriggers,
      'Histamin' => profile.histaminTriggers,
      _ => [],
    };
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BbChipSelector(
          options: AppConstants.intoleranceOptions,
          selected: profile.intolerances,

          onChanged: (v) {
            final added =
                v.where((s) => !profile.intolerances.contains(s));
            onIntolerancesChanged(v);
            for (final item in added) {
              if (triggerIntolerances.contains(item)) {
                Future.microtask(() {
                  if (!context.mounted) return;
                  showIntoleranceTriggerModal(
                    context: context,
                    intolerance: item,
                    currentTriggers: _triggersFor(item),
                    onChanged: (triggers) =>
                        onTriggersChanged(item, triggers),
                  );
                });
              }
            }
          },
        ),
      ],
    );
  }
}
