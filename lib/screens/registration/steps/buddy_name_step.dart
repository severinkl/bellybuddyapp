import 'package:flutter/services.dart';
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
///
/// The length limit and the counter count Unicode code points, like the
/// database and [AppConstants.isValidBuddyName] (an emoji family is one
/// visible character but five code points).
class BuddyNameStep extends StatefulWidget {
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
  State<BuddyNameStep> createState() => _BuddyNameStepState();
}

class _BuddyNameStepState extends State<BuddyNameStep> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// „n/20" in code points.
  Widget _counter(
    BuildContext context, {
    required int currentLength,
    required bool isFocused,
    required int? maxLength,
  }) => Semantics(
    container: true,
    liveRegion: isFocused,
    child: Text(
      '${_controller.text.runes.length}/${AppConstants.buddyNameMaxLength}',
      style: const TextStyle(
        fontSize: AppTheme.fontSizeCaption,
        color: AppTheme.mutedForeground,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          key: BuddyNameStep.titleKey,
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
          key: BuddyNameStep.fieldKey,
          controller: _controller,
          inputFormatters: const [
            _CodePointLimitFormatter(AppConstants.buddyNameMaxLength),
          ],
          buildCounter: _counter,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          autocorrect: false,
          decoration: const InputDecoration(labelText: 'Name'),
          onChanged: widget.onChanged,
          onFieldSubmitted: (_) => widget.onSubmitted?.call(),
        ),
      ],
    );
  }
}

/// Caps the text at [max] Unicode code points, cutting only between whole
/// characters. Typing at the limit keeps the text as it was.
class _CodePointLimitFormatter extends TextInputFormatter {
  const _CodePointLimitFormatter(this.max);

  final int max;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.runes.length <= max) return newValue;
    if (oldValue.text.runes.length == max && oldValue.selection.isCollapsed) {
      return oldValue;
    }
    final kept = StringBuffer();
    var count = 0;
    for (final character in newValue.text.characters) {
      count += character.runes.length;
      if (count > max) break;
      kept.write(character);
    }
    final text = kept.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
