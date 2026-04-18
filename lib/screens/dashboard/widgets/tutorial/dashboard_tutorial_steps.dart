import 'package:flutter/widgets.dart';

import '../../../../config/app_theme.dart';
import '../../../../config/constants.dart';
import 'tutorial_keys.dart';
import 'tutorial_step.dart';

const _baseStyle = TextStyle(
  fontSize: AppTheme.fontSizeBody,
  color: AppTheme.foreground,
  height: 1.35,
);

const _boldStyle = TextStyle(
  fontSize: AppTheme.fontSizeBody,
  color: AppTheme.foreground,
  fontWeight: FontWeight.w700,
  height: 1.35,
);

TextSpan _t(String text) => TextSpan(text: text, style: _baseStyle);
TextSpan _b(String text) => TextSpan(text: text, style: _boldStyle);

/// The 10 tutorial steps, in the fixed order shown by the mockups in
/// `Anleitung Homescreen/` (filenames 1.png–10.png).
final List<TutorialStep> dashboardTutorialSteps = [
  TutorialStep(
    targetKey: TutorialKeys.bauchgefuehl,
    targetRadius: AppConstants.radiusLg,
    preferredAnchor: TooltipAnchor.below,
    richText: [
      _t('Tracke deine '),
      _b('Beschwerden und deine Befindlichkeit'),
      _t(
        ' hier, um uns zu helfen, einen Zusammenhang zwischen deiner Ernährung und deinem Wohlbefinden herauszufinden.',
      ),
    ],
  ),
  TutorialStep(
    targetKey: TutorialKeys.klo,
    targetRadius: AppConstants.radiusLg,
    preferredAnchor: TooltipAnchor.below,
    richText: [
      _t(
        "Wann, wie oft und in welcher Form du auf's Klo gehst, ist ebenfalls eine sehr wichtige Information. Hier kannst du ",
      ),
      _b('deinen Stuhlgang tracken'),
      _t('.'),
    ],
  ),
  TutorialStep(
    targetKey: TutorialKeys.essenTracken,
    targetRadius: AppConstants.radiusFull,
    preferredAnchor: TooltipAnchor.above,
    richText: [
      _t('Tracke '),
      _b('Speisen und Getränke'),
      _t(
        ', die du zu dir nimmst. Je regelmäßiger du das tust, desto besser können wir dir Tipps für mehr Wohlbefinden geben.',
      ),
    ],
  ),
  TutorialStep(
    targetKey: TutorialKeys.fuerDich,
    targetRadius: AppConstants.radiusLg,
    preferredAnchor: TooltipAnchor.above,
    richText: [
      _t('Hol dir 1 x pro Tag Feedback zu '),
      _b('deinen Speisen und Getränken'),
      _t(
        ' und erfahre, was du in Zukunft anders machen kannst, um dich wohler zu fühlen.',
      ),
    ],
  ),
  TutorialStep(
    targetKey: TutorialKeys.alternativen,
    targetRadius: AppConstants.radiusLg,
    preferredAnchor: TooltipAnchor.above,
    richText: [
      _t('Alle besser '),
      _b('verträglichen Lebensmittel-Alternativen'),
      _t(' basierend auf deinen Speisen findest du hier.'),
    ],
  ),
  TutorialStep(
    targetKey: TutorialKeys.wissen,
    targetRadius: AppConstants.radiusLg,
    preferredAnchor: TooltipAnchor.above,
    richText: [
      _t(
        'Du willst mehr über die Themen Verdauung, ungeniert Pupsen und Co erfahren? ',
      ),
      _b("Hier geht's zum Blog!"),
    ],
  ),
  TutorialStep(
    targetKey: TutorialKeys.rezepte,
    targetRadius: AppConstants.radiusLg,
    preferredAnchor: TooltipAnchor.above,
    richText: [
      _t(
        'Auf deine Bedürfnisse angepasste Rezepte findest du (sehr bald) hier.',
      ),
    ],
  ),
  TutorialStep(
    targetKey: TutorialKeys.tagebuch,
    targetRadius: AppConstants.radiusMd,
    preferredAnchor: TooltipAnchor.above,
    richText: [
      _t('Was hast du wann gegessen und wie ist es dir dabei gegangen? Eine '),
      _b('Übersicht'),
      _t(' über alle deine erfassten Daten findest du hier.'),
    ],
  ),
  TutorialStep(
    targetKey: TutorialKeys.feedback,
    targetRadius: AppConstants.radiusFull,
    preferredAnchor: TooltipAnchor.below,
    richText: [
      _b('Fragen und Feedback zur App'),
      _t(' kannst du uns hier ganz einfach schicken.'),
    ],
  ),
  TutorialStep(
    targetKey: TutorialKeys.settings,
    targetRadius: AppConstants.radiusFull,
    preferredAnchor: TooltipAnchor.below,
    richText: [
      _t('Alle '),
      _b('Einstellungen'),
      _t(' zu deinem Profil kannst du hier einsehen und bearbeiten.'),
    ],
  ),
];
