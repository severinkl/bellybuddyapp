import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';

/// A wizard step's short label (and optional [helper] text) above its input.
/// The Buddy's bubble asks the step's question; once he reacts to the
/// answer, this label keeps saying what the step is about.
class StepFieldLabel extends StatelessWidget {
  const StepFieldLabel(this.label, {super.key, this.helper});

  final String label;
  final String? helper;

  /// The label's style (drawn in capitals).
  static const style = TextStyle(
    fontSize: AppTheme.fontSizeCaptionLG,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    color: AppTheme.mutedForeground,
  );

  @override
  Widget build(BuildContext context) {
    final helper = this.helper;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(header: true, child: Text(label.toUpperCase(), style: style)),
        if (helper != null) ...[
          AppConstants.gap4,
          Text(
            helper,
            style: const TextStyle(
              fontSize: AppTheme.fontSizeBodyLG,
              height: AppTheme.lineHeightBody,
              color: AppTheme.mutedForeground,
            ),
          ),
        ],
      ],
    );
  }
}
