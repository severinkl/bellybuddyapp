import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';
import 'buddy_controller.dart';

/// The edge a speech bubble's tail sits on.
enum BuddyBubbleSide {
  /// Below the bubble: it floats above the Buddy.
  down,

  /// On its left: it stands to the right of the Buddy.
  left,
}

/// Where a speech bubble's tail sits; it points at the Buddy.
@immutable
class BuddyBubbleTail {
  /// Under the bubble, its middle [shift] px right of the bubble's centre
  /// (negative: left of it).
  const BuddyBubbleTail.down({this.shift = 0}) : side = BuddyBubbleSide.down;

  /// On the bubble's left edge, its middle [shift] px below the top.
  const BuddyBubbleTail.left({this.shift = AppConstants.buddyBubbleSideTailTop})
    : side = BuddyBubbleSide.left;

  final BuddyBubbleSide side;
  final double shift;

  @override
  bool operator ==(Object other) =>
      other is BuddyBubbleTail && other.side == side && other.shift == shift;

  @override
  int get hashCode => Object.hash(side, shift);
}

/// The Buddy's speech bubble: shows [BuddyController.bubble] in a comic
/// bubble (the Buddy's outline, a flat shadow in his pink, a [tail] pointing
/// at him) and pops each new `say()` in with a scale + fade. The text types
/// itself in (at most [AppConstants.buddyBubbleTypeMax]); a tap shows it
/// whole. Under reduced motion both happen instantly. Screen readers get the
/// whole text right away.
///
/// Rebuilds only when the bubble changes, not on every frame.
class BuddySpeechBubble extends StatelessWidget {
  const BuddySpeechBubble({
    super.key,
    required this.controller,
    this.maxWidth = AppConstants.buddyBubbleMaxWidth,
    this.tail = const BuddyBubbleTail.down(),
    this.fontSize = AppTheme.fontSizeBodyLG,
  });

  final BuddyController controller;
  final double maxWidth;
  final BuddyBubbleTail tail;

  /// The text's size; roomy places (the wizard header) use a larger one.
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final calm =
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false) ||
        controller.reducedMotion;
    final bubble = controller.bubbleListenable;
    return ListenableBuilder(
      listenable: bubble,
      builder: (context, _) {
        final (:text, :id) = bubble.value;
        return AnimatedSwitcher(
          duration: calm ? Duration.zero : AppConstants.animNormal,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: animation,
              alignment: tail.side == BuddyBubbleSide.down
                  ? Alignment.bottomCenter
                  : Alignment.centerLeft,
              child: child,
            ),
          ),
          child: text == null
              ? const SizedBox.shrink()
              : _Bubble(
                  key: ValueKey(id),
                  text: text,
                  maxWidth: maxWidth,
                  tail: tail,
                  fontSize: fontSize,
                  typewriter: !calm,
                ),
        );
      },
    );
  }
}

/// [text] with its closing run of symbols (an emoji like „💧", no letters
/// or digits) glued to the word before by a no-break space, so a wrap never
/// leaves it alone on the last line.
@visibleForTesting
String glueClosingSymbol(String text) {
  final match = _closingSymbol.firstMatch(text);
  if (match == null || _wordChar.hasMatch(match.group(1)!)) return text;
  return '${text.substring(0, match.start)}\u00A0${match.group(1)}';
}

final _closingSymbol = RegExp(r' (\S+)$');
final _wordChar = RegExp(r'[\p{L}\p{N}]', unicode: true);

class _Bubble extends StatefulWidget {
  const _Bubble({
    super.key,
    required this.text,
    required this.maxWidth,
    required this.tail,
    required this.fontSize,
    required this.typewriter,
  });

  final String text;
  final double maxWidth;
  final BuddyBubbleTail tail;
  final double fontSize;
  final bool typewriter;

  @override
  State<_Bubble> createState() => _BubbleState();
}

class _BubbleState extends State<_Bubble> with SingleTickerProviderStateMixin {
  /// The text as drawn ([glueClosingSymbol]).
  late final String _shownText = glueClosingSymbol(widget.text);

  /// Where each character (grapheme) of the text ends, as a string index,
  /// so the typed part is a plain substring.
  late final List<int> _ends = _characterEnds(_shownText);

  late final AnimationController _typing = AnimationController(
    vsync: this,
    duration: _typeDuration(_ends.length),
    value: widget.typewriter ? 0 : 1,
  );

  /// How many characters are typed; the text rebuilds only when it changes,
  /// not on every frame of [_typing].
  late final ValueNotifier<int> _shown = ValueNotifier(_typedCount);

  int get _typedCount => (_ends.length * _typing.value).round();

  static List<int> _characterEnds(String text) {
    var end = 0;
    return [for (final c in text.characters) end += c.length];
  }

  static Duration _typeDuration(int length) {
    final total = AppConstants.buddyBubbleCharDelay * math.max(length, 1);
    return total < AppConstants.buddyBubbleTypeMax
        ? total
        : AppConstants.buddyBubbleTypeMax;
  }

  @override
  void initState() {
    super.initState();
    _typing.addListener(() => _shown.value = _typedCount);
    if (widget.typewriter) _typing.forward();
  }

  @override
  void didUpdateWidget(_Bubble old) {
    super.didUpdateWidget(old);
    // Reduced motion switched on mid-typing: show it whole.
    if (!widget.typewriter) _typing.value = 1;
  }

  @override
  void dispose() {
    _typing.dispose();
    _shown.dispose();
    super.dispose();
  }

  void _complete() => _typing.value = 1;

  /// The whole text laid out once; the part not typed yet ([shown]
  /// characters on) is transparent, so the bubble keeps its size while it
  /// types.
  Widget _text(BuildContext context, int shown, Widget? _) {
    final cut = shown == 0 ? 0 : _ends[shown - 1];
    final typed = _shownText.substring(0, cut);
    final rest = _shownText.substring(cut);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: typed),
          if (rest.isNotEmpty)
            TextSpan(
              text: rest,
              style: const TextStyle(color: Colors.transparent),
            ),
        ],
      ),
      softWrap: true,
      maxLines: AppConstants.buddyBubbleMaxLines,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.start,
      style: TextStyle(
        color: AppTheme.foreground,
        fontSize: widget.fontSize,
        fontWeight: FontWeight.w600,
        height: AppTheme.lineHeightSnug,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tail = widget.tail;
    const shadow = AppConstants.buddyBubbleShadowOffset;
    const tailLength = AppConstants.buddyBubbleTailLength;
    return Semantics(
      container: true,
      liveRegion: true,
      label: widget.text,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _complete,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: widget.maxWidth),
            child: CustomPaint(
              painter: _BubblePainter(tail),
              child: Padding(
                // Room for the tail and the shadow, then the inner padding.
                padding: EdgeInsets.fromLTRB(
                  (tail.side == BuddyBubbleSide.left ? tailLength : 0) +
                      AppConstants.spacing14,
                  AppConstants.spacing10,
                  shadow.dx + AppConstants.spacing14,
                  (tail.side == BuddyBubbleSide.down ? tailLength : 0) +
                      shadow.dy +
                      AppConstants.spacing10,
                ),
                child: ValueListenableBuilder(
                  valueListenable: _shown,
                  builder: _text,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The outline of a bubble of [size] (tail and shadow room included) with
/// its [tail]: a rounded body and the tail as one path.
@visibleForTesting
Path buddyBubblePath(Size size, BuddyBubbleTail tail) {
  const inset = AppConstants.borderWidthLg / 2;
  const shadow = AppConstants.buddyBubbleShadowOffset;
  const length = AppConstants.buddyBubbleTailLength;
  const base = AppConstants.buddyBubbleTailBase;
  const radius = AppConstants.radiusRound;
  final body = Rect.fromLTRB(
    (tail.side == BuddyBubbleSide.left ? length : 0) + inset,
    inset,
    size.width - shadow.dx - inset,
    size.height -
        shadow.dy -
        (tail.side == BuddyBubbleSide.down ? length : 0) -
        inset,
  );
  final bodyPath = Path()
    ..addRRect(RRect.fromRectAndRadius(body, const Radius.circular(radius)));

  // The tail's base stays on the straight part of its edge.
  double along(double centre, double start, double end) {
    final lo = start + radius + base / 2;
    final hi = end - radius - base / 2;
    return hi < lo ? (start + end) / 2 : centre.clamp(lo, hi);
  }

  final Path tailPath;
  switch (tail.side) {
    case BuddyBubbleSide.down:
      final x = along(body.center.dx + tail.shift, body.left, body.right);
      // Overlaps the body by the outline so the union has no seam.
      final y = body.bottom - AppConstants.borderWidthLg;
      tailPath = Path()
        ..moveTo(x - base / 2, y)
        ..lineTo(x - base * 0.04, body.bottom + length)
        ..lineTo(x + base / 2, y)
        ..close();
    case BuddyBubbleSide.left:
      final y = along(body.top + tail.shift, body.top, body.bottom);
      final x = body.left + AppConstants.borderWidthLg;
      tailPath = Path()
        ..moveTo(x, y - base / 2)
        ..lineTo(body.left - length, y + base * 0.17)
        ..lineTo(x, y + base / 2)
        ..close();
  }
  return Path.combine(PathOperation.union, bodyPath, tailPath);
}

class _BubblePainter extends CustomPainter {
  _BubblePainter(this.tail);

  final BuddyBubbleTail tail;

  /// The outline (and its shadow) for [_size]: typing repaints the bubble
  /// with every new character, at the same size.
  Size? _size;
  late Path _path;
  late Path _shadowPath;

  static final Paint _shadow = Paint()..color = AppTheme.buddyBody;
  static final Paint _fill = Paint()..color = Colors.white;
  static final Paint _outline = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = AppConstants.borderWidthLg
    ..strokeJoin = StrokeJoin.round
    ..color = AppTheme.buddyOutline;

  @override
  void paint(Canvas canvas, Size size) {
    if (size != _size) {
      _size = size;
      _path = buddyBubblePath(size, tail);
      _shadowPath = _path.shift(AppConstants.buddyBubbleShadowOffset);
    }
    canvas
      ..drawPath(_shadowPath, _shadow)
      ..drawPath(_path, _fill)
      ..drawPath(_path, _outline);
  }

  @override
  bool shouldRepaint(_BubblePainter old) => old.tail != tail;
}
