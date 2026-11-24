import 'package:material_ui/material_ui.dart';

import '../../config/app_theme.dart';
import 'buddy_controller.dart';
import 'buddy_geometry.dart';
import 'buddy_pose.dart';
import 'buddy_side_header.dart';
import 'buddy_stage.dart';

/// The Buddy in [mood] saying [line] for as long as he is shown: on a stage
/// with the bubble above him, or beside him ([BuddySays.beside]), where the
/// bubble shows the whole line however long. A new [line] is said, a new
/// [mood] taken on, by the same Buddy.
class BuddySays extends StatefulWidget {
  /// On a stage [height] high.
  const BuddySays({
    super.key,
    this.mood = BuddyMood.happy,
    required this.line,
    required this.height,
  }) : beside = false,
       fontSize = AppTheme.fontSizeSubtitleLG;

  /// Beside him, [height] high (as wide as his stage's aspect), the line in
  /// [fontSize].
  const BuddySays.beside({
    super.key,
    this.mood = BuddyMood.happy,
    required this.line,
    required this.height,
    this.fontSize = AppTheme.fontSizeSubtitleLG,
  }) : beside = true;

  final BuddyMood mood;
  final String line;
  final double height;

  /// Whether the bubble is beside him rather than above.
  final bool beside;

  /// The size of the bubble's text beside him.
  final double fontSize;

  @override
  State<BuddySays> createState() => _BuddySaysState();
}

class _BuddySaysState extends State<BuddySays> {
  late final BuddyController _controller = BuddyController(mood: widget.mood)
    ..say(widget.line, duration: null);

  @override
  void didUpdateWidget(BuddySays old) {
    super.didUpdateWidget(old);
    _controller.mood = widget.mood;
    if (old.line != widget.line) _controller.say(widget.line, duration: null);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.beside) {
      return BuddySideHeader(
        controller: _controller,
        buddySize: Size(widget.height * kBuddyStageAspect, widget.height),
        grow: true,
        fontSize: widget.fontSize,
      );
    }
    return SizedBox(
      height: widget.height,
      child: BuddyStage(controller: _controller),
    );
  }
}
