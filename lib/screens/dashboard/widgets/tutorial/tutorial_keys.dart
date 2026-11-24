import 'package:flutter/widgets.dart';

/// Global keys on the 7 elements the tour highlights: the Buddy hero, its
/// next-action button and the insight card on Home, then the bar's plus,
/// Tagebuch, Entdecken and Ich. Referenced by the dashboard and bottom-bar
/// widgets (at construction time) and by the tutorial overlay (to resolve
/// each target's render box).
class TutorialKeys {
  TutorialKeys._();

  static final buddy = GlobalKey(debugLabel: 'tutorial.buddy');
  static final nextAction = GlobalKey(debugLabel: 'tutorial.nextAction');
  static final plus = GlobalKey(debugLabel: 'tutorial.plus');
  static final insight = GlobalKey(debugLabel: 'tutorial.insight');
  static final tagebuch = GlobalKey(debugLabel: 'tutorial.tagebuch');
  static final entdecken = GlobalKey(debugLabel: 'tutorial.entdecken');
  static final ich = GlobalKey(debugLabel: 'tutorial.ich');
}
