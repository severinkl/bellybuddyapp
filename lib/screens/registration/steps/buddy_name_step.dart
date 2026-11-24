import 'package:material_ui/material_ui.dart';

import '../../../utils/buddy_name.dart';

/// Lets the user name the Buddy: a text field prefilled with [value]. The
/// host shows the Buddy (his bubble asks for the name), adds the padding
/// and the „Weiter" button, and validates the name (trimmed, not empty).
///
/// [value] is only the initial text; later changes come from the field and
/// are reported through [onChanged]. [onSubmitted] runs on the keyboard's
/// done action (hosts wire it to their „Weiter").
///
/// The length limit and the counter count characters as a person sees them
/// ([BuddyNameRules]); a name the database can't store yet shows why.
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

  /// Identifies the step (it has no headline: the Buddy asks).
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

  /// „n/20" in characters as a person sees them.
  Widget _counter(
    BuildContext context, {
    required int currentLength,
    required bool isFocused,
    required int? maxLength,
  }) => BuddyNameRules.counter(_controller.text, isFocused: isFocused);

  @override
  Widget build(BuildContext context) {
    return Column(
      key: BuddyNameStep.titleKey,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          key: BuddyNameStep.fieldKey,
          controller: _controller,
          inputFormatters: const [BuddyNameLengthFormatter()],
          buildCounter: _counter,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: 'Name',
            // An empty name only disables „Weiter"; a name too long for the
            // database says why.
            errorText: _controller.text.trim().isEmpty
                ? null
                : BuddyNameRules.error(_controller.text),
            errorMaxLines: 2,
          ),
          onChanged: (value) {
            setState(() {});
            widget.onChanged(value);
          },
          onFieldSubmitted: (_) => widget.onSubmitted?.call(),
        ),
      ],
    );
  }
}
