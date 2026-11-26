import 'package:flutter/widgets.dart';

import '../../../../config/app_theme.dart';
import '../../../../config/constants.dart';
import 'tutorial_keys.dart';
import 'tutorial_step.dart';

const _baseStyle = TextStyle(
  fontSize: AppTheme.fontSizeBody,
  color: AppTheme.foreground,
  height: AppTheme.lineHeightSnug,
);

const _boldStyle = TextStyle(
  fontSize: AppTheme.fontSizeBody,
  color: AppTheme.foreground,
  fontWeight: FontWeight.w700,
  height: AppTheme.lineHeightSnug,
);

TextSpan _t(String text) => TextSpan(text: text, style: _baseStyle);
TextSpan _b(String text) => TextSpan(text: text, style: _boldStyle);

/// The 7 tour steps: Home top to bottom (the Buddy and his bubbles, the
/// next-action button), the plus, the insight card, then the tabs.
final List<TutorialStep> dashboardTutorialSteps = [
  TutorialStep(
    targetKey: TutorialKeys.buddy,
    targetRadius: AppConstants.radiusLg,
    preferredAnchor: TooltipAnchor.below,
    richText: [
      _t('Das ist dein '),
      _b('Buddy'),
      _t('! Jeder Eintrag hält euren 🔥 '),
      _b('Streak'),
      _t(' am Leben. Seine '),
      _b('Blasen'),
      _t(
        ' füllen sich, wenn du einträgst, und leeren sich langsam – tipp auf eine, um einzutragen.',
      ),
    ],
  ),
  TutorialStep(
    targetKey: TutorialKeys.nextAction,
    targetRadius: AppConstants.radiusLg,
    preferredAnchor: TooltipAnchor.above,
    richText: [
      _t('Dieser Knopf schlägt dir den '),
      _b('nächsten Eintrag'),
      _t(' vor – passend zur Tageszeit.'),
    ],
  ),
  TutorialStep(
    targetKey: TutorialKeys.plus,
    targetRadius: AppConstants.radiusFull,
    preferredAnchor: TooltipAnchor.above,
    richText: [
      _t('Hier trägst du '),
      _b('alles'),
      _t(' ein: Essen, Trinken, Bauchgefühl und Klo.'),
    ],
  ),
  TutorialStep(
    targetKey: TutorialKeys.insight,
    targetRadius: AppConstants.radiusRound,
    preferredAnchor: TooltipAnchor.above,
    richText: [
      _t('Sobald genug Einträge da sind, zeig ich dir hier, '),
      _b('was mir an deinem Bauch auffällt'),
      _t('.'),
    ],
  ),
  TutorialStep(
    targetKey: TutorialKeys.tagebuch,
    targetRadius: AppConstants.radiusMd,
    preferredAnchor: TooltipAnchor.above,
    richText: [
      _t('Im '),
      _b('Tagebuch'),
      _t(' siehst du alle deine Einträge, Tag für Tag.'),
    ],
  ),
  TutorialStep(
    targetKey: TutorialKeys.entdecken,
    targetRadius: AppConstants.radiusMd,
    preferredAnchor: TooltipAnchor.above,
    richText: [
      _t('Unter '),
      _b('Entdecken'),
      _t(
        ' findest du Alternativen, deine Rezepte und Wissen rund um die Verdauung.',
      ),
    ],
  ),
  TutorialStep(
    targetKey: TutorialKeys.ich,
    targetRadius: AppConstants.radiusMd,
    preferredAnchor: TooltipAnchor.above,
    richText: [
      _t('Unter '),
      _b('Ich'),
      _t(
        ' kannst du mich umbenennen, dein Streak-Ziel ändern und alles einstellen.',
      ),
    ],
  ),
];
