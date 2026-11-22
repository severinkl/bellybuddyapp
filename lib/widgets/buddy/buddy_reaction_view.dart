import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../config/constants.dart';
import '../../providers/buddy_provider.dart';
import '../../services/buddy/buddy_mood_logic.dart';
import '../../utils/logger.dart';
import 'buddy_actions.dart';
import 'buddy_controller.dart';
import 'buddy_stage.dart';

/// The Buddy reacting to an entry the user just logged: plays the action of
/// [reactionFor] from its first frame, says the reaction line and then
/// switches to the reaction's mood. Used as the tracker success illustration.
///
/// Owns its [BuddyController]. For [EntryKind.meal], [foodImageBytes] (the
/// meal photo) is decoded first and falls as the bite; without a photo, or
/// when it can't be decoded, the Buddy eats an apple.
class BuddyReactionView extends ConsumerStatefulWidget {
  const BuddyReactionView({
    super.key,
    required this.kind,
    required this.sentiment,
    this.foodImageBytes,
    this.size = AppConstants.buddyReactionSize,
  });

  final EntryKind kind;
  final LogSentiment sentiment;

  /// Encoded meal photo (JPEG/PNG/…); only used by the `eat` reaction.
  final Uint8List? foodImageBytes;

  /// Maximum height of the stage (speech-bubble slot plus Buddy); the Buddy
  /// shrinks when less height is available.
  final double size;

  @override
  ConsumerState<BuddyReactionView> createState() => _BuddyReactionViewState();
}

class _BuddyReactionViewState extends ConsumerState<BuddyReactionView> {
  static const _log = AppLogger('BuddyReactionView');
  static const _fallbackName = 'Buddy';

  /// The photo is drawn as a small bite; decoding it smaller saves memory.
  static const int _foodDecodeWidth = 256;

  /// Long enough to read the longer empathy lines.
  static const Duration _bubbleDuration = Duration(seconds: 5);

  final BuddyController _controller = BuddyController();

  /// The decoded meal photo. Owned here: disposed after [_controller], so it
  /// outlives every frame the `eat` action draws it in.
  ui.Image? _food;

  @override
  void initState() {
    super.initState();
    final reaction = reactionFor(
      widget.kind,
      widget.sentiment,
      name: ref.read(buddyProvider).value?.state.name ?? _fallbackName,
      rnd: math.Random(),
    );
    final bytes = widget.foodImageBytes;
    if (reaction.action == BuddyAction.eat && bytes != null) {
      unawaited(_startWithFood(reaction, bytes));
    } else {
      _start(reaction);
    }
  }

  Future<void> _startWithFood(BuddyReaction reaction, Uint8List bytes) async {
    final food = await _decode(bytes);
    if (!mounted) {
      food?.dispose();
      return;
    }
    _food = food;
    _start(reaction);
  }

  Future<ui.Image?> _decode(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: _foodDecodeWidth,
        allowUpscaling: false,
      );
      try {
        return (await codec.getNextFrame()).image;
      } finally {
        codec.dispose();
      }
    } catch (e, st) {
      _log.error('Meal photo could not be decoded; eating an apple', e, st);
      return null;
    }
  }

  void _start(BuddyReaction reaction) {
    _controller
      ..play(reaction.action, food: _food)
      ..say(reaction.line, duration: _bubbleDuration);
    final moodAfter = reaction.moodAfter;
    if (moodAfter != null) _controller.mood = moodAfter;
  }

  @override
  void dispose() {
    _controller.dispose();
    _food?.dispose();
    _food = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = ref.watch(buddyProvider.select((s) => s.value?.state.name));
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: widget.size),
      child: BuddyStage(controller: _controller, name: name ?? _fallbackName),
    );
  }
}
