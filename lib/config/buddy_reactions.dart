import 'dart:math';

import '../services/buddy/buddy_copy.dart';
import '../widgets/buddy/buddy_actions.dart';
import '../widgets/buddy/buddy_controller.dart';
import '../widgets/buddy/buddy_pose.dart';

/// A Buddy reaction: optional mood/action plus 1-3 German line variants.
/// `{name}` is replaced by the Buddy's own name ([BuddyLineReaction.react]).
class BuddyLine {
  const BuddyLine({this.mood, this.action, required this.lines});

  final BuddyMood? mood;
  final BuddyAction? action;
  final List<String> lines;

  String pick(Random rnd) => BuddyCopy.pick(lines, rnd);
}

/// Plays [BuddyLine]s on a Buddy.
extension BuddyLineReaction on BuddyController {
  /// Plays [line]: its mood and action, and one of its texts with `{name}`
  /// filled in, shown for [duration] (null: until the next `say`).
  void react(
    BuddyLine line, {
    required String name,
    required Random rnd,
    required Duration? duration,
  }) {
    final mood = line.mood;
    final action = line.action;
    if (mood != null) this.mood = mood;
    if (action != null) play(action);
    say(BuddyCopy.fill(line.pick(rnd), name: name), duration: duration);
  }
}

/// Builds a catalog key, e.g. `wizardKey('gender', 'weiblich')`.
String wizardKey(String step, [String? value]) => '$step:${value ?? 'any'}';

BuddyLine? wizardReaction(String key) => kWizardReactions[key];

const Map<String, BuddyLine> kWizardReactions = {
  'name:intro': BuddyLine(
    mood: BuddyMood.happy,
    lines: [
      'Ich hab noch keinen Namen. Magst du mir einen geben?',
      'Du darfst mich taufen! Wie soll ich heißen?',
    ],
  ),
  'name:confirmed': BuddyLine(
    mood: BuddyMood.inLove,
    action: BuddyAction.wave,
    lines: [
      'Ich bin {name} – schön, dass wir uns haben!',
      'Wunderbar, mit dem Namen fühl ich mich gleich wohl!',
    ],
  ),
  'consent:intro': BuddyLine(
    mood: BuddyMood.happy,
    lines: ['Bevor du mir von deinem Bauch erzählst, brauch ich kurz dein OK.'],
  ),
  'auth:intro': BuddyLine(
    mood: BuddyMood.happy,
    lines: [
      'Damit ich mir alles merken kann, brauchst du ein Konto.',
      'Fast geschafft! Ein Konto, und ich merk mir alles.',
    ],
  ),
  'emailCapture:intro': BuddyLine(
    mood: BuddyMood.happy,
    lines: ['Fast geschafft! Wohin darf ich dir schreiben?'],
  ),
  'birthYear:any': BuddyLine(
    action: BuddyAction.nodYes,
    lines: ['Perfekt, danke!', 'Alles klar, notiert!'],
  ),
  'heightWeight:any': BuddyLine(
    action: BuddyAction.nodYes,
    lines: ['Danke, das hilft mir weiter!', 'Super, damit kann ich arbeiten!'],
  ),
  'gender:weiblich': BuddyLine(
    mood: BuddyMood.happy,
    lines: ['Schön, dich kennenzulernen!', 'Hallo du! Ich freu mich auf uns.'],
  ),
  'gender:männlich': BuddyLine(
    mood: BuddyMood.happy,
    lines: ['Schön, dich kennenzulernen!', 'Hallo du! Ich freu mich auf uns.'],
  ),
  'gender:andere': BuddyLine(
    mood: BuddyMood.happy,
    lines: ['Schön, dass du da bist!', 'Hallo du! Ich freu mich auf uns.'],
  ),
  'diet:alles': BuddyLine(
    mood: BuddyMood.hungry,
    lines: ['Oh, da gibt es viel zu probieren!', 'Mhm, ich hab schon Hunger!'],
  ),
  'diet:vegetarisch': BuddyLine(
    mood: BuddyMood.happy,
    lines: [
      'Vegetarisch, das klingt lecker!',
      'Vegetarisch klingt gut für mich!',
    ],
  ),
  'diet:vegan': BuddyLine(
    mood: BuddyMood.inLove,
    lines: [
      'Ui, ganz viel Grünzeug für mich!',
      'Pflanzenpower, ich bin dabei!',
    ],
  ),
  'symptom:Belastender Durchfall': BuddyLine(
    mood: BuddyMood.empathetic,
    lines: ['Oh je, das ist wirklich belastend.', 'Das tut mir leid für dich.'],
  ),
  'symptom:Nervige Verstopfung': BuddyLine(
    mood: BuddyMood.empathetic,
    lines: [
      'Puh, das nervt wirklich. Ich bin bei dir.',
      'Das ist echt lästig, das tut mir leid.',
    ],
  ),
  'symptom:Unangenehme Blähungen': BuddyLine(
    mood: BuddyMood.empathetic,
    lines: [
      'Oh, das kenn ich nur zu gut!',
      'Blähungen sind echt fies, ich weiß.',
    ],
  ),
  'symptom:Übermäßiges Völlegefühl': BuddyLine(
    mood: BuddyMood.empathetic,
    lines: [
      'Oje, so ein Völlegefühl ist wirklich unangenehm.',
      'Ich fühl mit dir, das drückt.',
    ],
  ),
  'symptom:Hartnäckiger Blähbauch ohne Pupsen': BuddyLine(
    mood: BuddyMood.empathetic,
    lines: [
      'Ein praller Bauch, der nicht nachgibt – ich fühl mit dir!',
      'Das klingt wirklich unangenehm. Ich bin da.',
    ],
  ),
  'symptom:none': BuddyLine(
    mood: BuddyMood.happy,
    action: BuddyAction.celebrate,
    lines: ['Wie schön, dann starten wir entspannt!', 'Super, das freut mich!'],
  ),
  'intolerance:Laktose': BuddyLine(
    action: BuddyAction.think,
    lines: [
      'Notiert! Darauf passen wir zusammen auf.',
      'Alles klar, das merk ich mir!',
    ],
  ),
  'intolerance:Gluten': BuddyLine(
    action: BuddyAction.think,
    lines: [
      'Gluten, notiert! Wir behalten das im Blick.',
      'Alles klar, das merk ich mir!',
    ],
  ),
  'intolerance:Fruktose': BuddyLine(
    action: BuddyAction.think,
    lines: [
      'Fruktose, verstanden! Das merk ich mir.',
      'Alles klar, das merk ich mir!',
    ],
  ),
  'intolerance:Histamin': BuddyLine(
    action: BuddyAction.think,
    lines: [
      'Histamin, notiert! Darauf achten wir gemeinsam.',
      'Alles klar, das merk ich mir!',
    ],
  ),
  'intolerance:Sorbit': BuddyLine(
    action: BuddyAction.think,
    lines: [
      'Sorbit, verstanden! Das merk ich mir.',
      'Alles klar, das merk ich mir!',
    ],
  ),
  'intolerance:Nüsse': BuddyLine(
    action: BuddyAction.think,
    lines: [
      'Nüsse, notiert! Darauf passen wir auf.',
      'Alles klar, das merk ich mir!',
    ],
  ),
  'intolerance:Eier': BuddyLine(
    action: BuddyAction.think,
    lines: [
      'Eier, notiert! Das behalte ich im Kopf.',
      'Alles klar, das merk ich mir!',
    ],
  ),
  'intolerance:Soja': BuddyLine(
    action: BuddyAction.think,
    lines: [
      'Soja, verstanden! Das merk ich mir.',
      'Alles klar, das merk ich mir!',
    ],
  ),
  'intolerance:Weizen': BuddyLine(
    action: BuddyAction.think,
    lines: [
      'Weizen, notiert! Wir behalten das im Blick.',
      'Alles klar, das merk ich mir!',
    ],
  ),
  'intolerance:none': BuddyLine(
    mood: BuddyMood.happy,
    action: BuddyAction.celebrate,
    lines: ['Keine Unverträglichkeiten? Dann starten wir ganz unbeschwert!'],
  ),
  'step:birthYear': BuddyLine(
    mood: BuddyMood.happy,
    lines: ['Wann bist du geboren? Ich bin gespannt!'],
  ),
  'step:gender': BuddyLine(
    mood: BuddyMood.happy,
    lines: ['Wie darf ich dich ansprechen?'],
  ),
  'step:heightWeight': BuddyLine(
    mood: BuddyMood.happy,
    lines: ['Magst du mir deine Größe und dein Gewicht verraten?'],
  ),
  'step:diet': BuddyLine(
    mood: BuddyMood.hungry,
    lines: ['Was landet bei dir so auf dem Teller?'],
  ),
  'step:symptoms': BuddyLine(
    mood: BuddyMood.empathetic,
    lines: ['Was macht dir mit deinem Bauch zu schaffen?'],
  ),
  'step:intolerances': BuddyLine(
    mood: BuddyMood.happy,
    lines: ['Gibt es etwas, das du nicht verträgst?'],
  ),
};
