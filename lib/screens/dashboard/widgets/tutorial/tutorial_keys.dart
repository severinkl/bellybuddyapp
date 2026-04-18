import 'package:flutter/widgets.dart';

/// Global keys attached to the 10 dashboard elements highlighted in the
/// onboarding tour. Referenced both by the dashboard/bottom-nav widgets
/// (at construction time) and by the tutorial overlay (to resolve each
/// target's render box).
class TutorialKeys {
  TutorialKeys._();

  static final bauchgefuehl = GlobalKey(debugLabel: 'tutorial.bauchgefuehl');
  static final klo = GlobalKey(debugLabel: 'tutorial.klo');
  static final essenTracken = GlobalKey(debugLabel: 'tutorial.essenTracken');
  static final fuerDich = GlobalKey(debugLabel: 'tutorial.fuerDich');
  static final alternativen = GlobalKey(debugLabel: 'tutorial.alternativen');
  static final wissen = GlobalKey(debugLabel: 'tutorial.wissen');
  static final rezepte = GlobalKey(debugLabel: 'tutorial.rezepte');
  static final tagebuch = GlobalKey(debugLabel: 'tutorial.tagebuch');
  static final feedback = GlobalKey(debugLabel: 'tutorial.feedback');
  static final settings = GlobalKey(debugLabel: 'tutorial.settings');
}
