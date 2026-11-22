import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';

/// Lets the user name the Buddy: a title in the Buddy's voice over a text
/// field prefilled with [value]. The host shows the Buddy, adds the padding
/// and the „Weiter" button, and validates the name (trimmed, not empty).
///
/// [value] is only the initial text; later changes come from the field and
/// are reported through [onChanged]. [onSubmitted] runs on the keyboard's
/// done action (hosts wire it to their „Weiter").
class BuddyNameStep extends StatelessWidget {
  const BuddyNameStep({
    super.key,
    required this.value,
    required this.onChanged,
    this.onSubmitted,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final VoidCallback? onSubmitted;

  static const titleKey = Key('buddy_name_step_title');
  static const fieldKey = Key('buddy_name_field');

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          key: titleKey,
          'Wie soll ich heißen?',
          style: TextStyle(
            fontSize: AppTheme.fontSizeHeadingLG,
            fontWeight: FontWeight.w700,
            color: AppTheme.foreground,
          ),
          textAlign: TextAlign.center,
        ),
        AppConstants.gap16,
        TextFormField(
          key: fieldKey,
          initialValue: value,
          maxLength: AppConstants.buddyNameMaxLength,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          autocorrect: false,
          decoration: const InputDecoration(labelText: 'Name'),
          onChanged: onChanged,
          onFieldSubmitted: (_) => onSubmitted?.call(),
        ),
      ],
    );
  }
}
