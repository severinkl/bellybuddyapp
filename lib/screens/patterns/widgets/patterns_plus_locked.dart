import 'package:material_ui/material_ui.dart';

import '../../../config/constants.dart';
import '../../../services/insights/insight_copy.dart';
import '../../../services/plus/plus_copy.dart';
import '../../../widgets/common/plus_locked_card.dart';
import '../../registration/widgets/step_field_label.dart';
import 'patterns_preview.dart';

/// The Muster page once the patterns unlocked, while Belly Buddy Plus is
/// locked: the card with the way to Plus and the blurred sample
/// ([PatternsPreview]).
class PatternsPlusLocked extends StatelessWidget {
  const PatternsPlusLocked({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PlusLockedCard(
          title: PlusCopy.patternsTitle,
          line: PlusCopy.patternsLine,
        ),
        AppConstants.gap24,
        StepFieldLabel(InsightCopy.previewLabel),
        AppConstants.gap8,
        PatternsPreview(),
      ],
    );
  }
}
