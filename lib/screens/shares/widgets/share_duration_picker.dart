import 'package:material_ui/material_ui.dart';

import '../../../config/constants.dart';
import '../../../models/data_share.dart';
import '../../../widgets/common/bb_chip_selector.dart';
import 'share_terms_form.dart';

/// „Wie lange?": „90 Tage" or „Bis ich es beende".
class ShareDurationPicker extends StatelessWidget {
  const ShareDurationPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final ShareDuration value;
  final ValueChanged<ShareDuration> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ShareFormHeading('Wie lange?'),
        Wrap(
          spacing: AppConstants.spacingSm,
          children: [
            for (final (duration, label) in [
              (ShareDuration.days90, '90 Tage'),
              (ShareDuration.open, 'Bis ich es beende'),
            ])
              BbFilterChip(
                label: label,
                selected: value == duration,
                onSelected: (_) => onChanged(duration),
              ),
          ],
        ),
      ],
    );
  }
}
