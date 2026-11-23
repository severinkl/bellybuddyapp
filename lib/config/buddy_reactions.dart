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
  /// filled in, shown for [duration] (null: until the next `say`) — or,
  /// with [hold], for that long before the resting line comes back
  /// ([BuddyController.sayThenRest]).
  void react(
    BuddyLine line, {
    required String name,
    required Random rnd,
    Duration? duration,
    Duration? hold,
  }) {
    assert(
      duration == null || hold == null,
      'A held line returns to the resting line; it has no duration.',
    );
    final mood = line.mood;
    final action = line.action;
    if (mood != null) this.mood = mood;
    if (action != null) play(action);
    final text = BuddyCopy.fill(line.pick(rnd), name: name);
    if (hold != null) {
      sayThenRest(text, hold: hold);
    } else {
      say(text, duration: duration);
    }
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
      'Fast geschafft! Leg dir noch ein Konto an.',
      'Damit ich mir alles merken kann, brauchst du ein Konto.',
    ],
  ),
  'emailCapture:intro': BuddyLine(
    mood: BuddyMood.happy,
    lines: ['Fast geschafft! Wohin darf ich dir schreiben?'],
  ),
  'birthYear:any': BuddyLine(
    action: BuddyAction.nodYes,
    lines: ['Perfekt, danke!', 'Ah, ein guter Jahrgang!'],
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
    lines: [
      'Oh je, das ist wirklich belastend.',
      'Das tut mir leid. Gut, dass du es mir sagst.',
    ],
  ),
  'symptom:Nervige Verstopfung': BuddyLine(
    mood: BuddyMood.empathetic,
    lines: [
      'Puh, das nervt wirklich. Ich bin bei dir.',
      'Echt lästig! Da schauen wir gemeinsam genauer hin.',
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
      'Das drückt ganz schön, oder? Ich versteh dich.',
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
      'Laktose, check! Bei Milch und Joghurt bin ich ab jetzt hellwach.',
      'Okay, Laktose! Milchiges haben wir ab jetzt zusammen im Blick.',
    ],
  ),
  'intolerance:Gluten': BuddyLine(
    action: BuddyAction.think,
    lines: [
      'Gluten, notiert! Brot und Nudeln behalte ich für dich im Auge.',
      'Gluten auch? Kein Problem, wir finden trotzdem Leckeres!',
    ],
  ),
  'intolerance:Fruktose': BuddyLine(
    action: BuddyAction.think,
    lines: [
      'Fruktose, oh! Beim Obst gucke ich ab jetzt zweimal hin.',
      'Fruchtzucker, alles klar – da bin ich wachsam!',
    ],
  ),
  'intolerance:Histamin': BuddyLine(
    action: BuddyAction.think,
    lines: [
      'Histamin, verstanden! Das hab ich bei jeder Mahlzeit dabei.',
      'Histamin – okay! Da bin ich ganz Ohr. Äh, ganz Bauch.',
    ],
  ),
  'intolerance:Sorbit': BuddyLine(
    action: BuddyAction.think,
    lines: [
      'Sorbit versteckt sich gern – ich helf dir beim Aufspüren!',
      'Sorbit, check! Kaugummi & Co. kommen auf meinen Radar.',
    ],
  ),
  'intolerance:Nüsse': BuddyLine(
    action: BuddyAction.think,
    lines: [
      'Nüsse, notiert! Ich halte für dich die Augen offen.',
      'Nüsse also! Danke, dass du mir das sagst.',
    ],
  ),
  'intolerance:Eier': BuddyLine(
    action: BuddyAction.think,
    lines: [
      'Eier, alles klar! Auch die versteckten in Teig und Soßen.',
      'Eier also – gut zu wissen, ich pass mit auf!',
    ],
  ),
  'intolerance:Soja': BuddyLine(
    action: BuddyAction.think,
    lines: [
      'Soja, check! Das steckt oft da, wo man es nicht erwartet.',
      'Okay, Soja! Das steht ab jetzt auf meinem Zettel.',
    ],
  ),
  'intolerance:Weizen': BuddyLine(
    action: BuddyAction.think,
    lines: [
      'Weizen, notiert! Brötchen und Gebäck hab ich auf dem Schirm.',
      'Weizen auch? Gut zu wissen, danke dir!',
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
    lines: ['Welches biologische Geschlecht hast du?'],
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
    lines: ['Wurden dir Unverträglichkeiten diagnostiziert?'],
  ),
};
