import 'package:material_ui/material_ui.dart';

/// Gives a text field [child] a name for assistive tech that stays while
/// the user types (a hint goes). Merged into the field's own node, so a
/// screen reader finds one named field, not a wrapper and an unnamed one.
///
/// It merges the whole subtree into that one node: never wrap a field with
/// its own interactive prefix or suffix (a clear ✕, a password eye), or
/// that button loses its own node and can't be reached.
class BbLabeledField extends StatelessWidget {
  const BbLabeledField({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Semantics(label: label, textField: true, child: child),
  );
}
