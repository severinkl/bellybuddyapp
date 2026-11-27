import 'package:material_ui/material_ui.dart';

/// Gives a text field [child] a name for assistive tech that stays while
/// the user types (a hint goes). The label lands on the field's own node,
/// so a screen reader finds one named field, not a wrapper and an unnamed
/// one.
///
/// Only a label, no flags: a [TextField] is a node of its own and takes the
/// label in, while a button in its decoration (a clear ✕, a password eye)
/// stays a node of its own beside it. (A `textField` flag here would make a
/// second, empty node, and merging the subtree would swallow that button.)
class BbLabeledField extends StatelessWidget {
  const BbLabeledField({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(label: label, child: child);
}
