import '../../models/plus_status.dart';
import '../../utils/date_format_utils.dart';

/// Every German string of the Belly Buddy Plus paywall (spec 4.5) and the
/// status line of the Ich row (spec 4.6).
///
/// Price and trial length only ever come from the store offer: nothing here
/// spells out an amount or a number of days.
abstract final class PlusCopy {
  static const title = 'Belly Buddy Plus';
  static const intro = 'Damit holst du mehr aus deinen Einträgen:';
  static const benefits = [
    'Muster: was an guten und schwierigen Tagen auffällig oft dabei war',
    'Jeden Montag neue Tipps zu deinen Einträgen',
    'Alternativen zu Zutaten, die bei dir auffällig sind',
    'Rezepte für dich anpassen',
    'Dein Tagebuch per Link mit Diätolog:in oder Ärzt:in teilen',
  ];
  static const free =
      'Immer gratis: Mahlzeiten, Getränke, Bauchgefühl und Klo eintragen, '
      'dein Tagebuch, Belly Buddy, Streaks und die Reise.';

  /// „{n} Tage gratis, danach {price} pro Monat" while the user can get the
  /// trial, else „{price} pro Monat".
  static String priceLine(String price, int? trialDays) => _hasTrial(trialDays)
      ? '${_days(trialDays!)} gratis, danach $price pro Monat'
      : '$price pro Monat';

  /// „{n} Tage gratis testen" or „Plus abonnieren".
  static String buyLabel(int? trialDays) => _hasTrial(trialDays)
      ? '${_days(trialDays!)} gratis testen'
      : 'Plus abonnieren';

  static bool _hasTrial(int? days) => days != null && days > 0;
  static String _days(int n) => n == 1 ? '1 Tag' : '$n Tage';

  static const termsIos =
      'Das Abo verlängert sich jeden Monat automatisch, wenn du es nicht '
      'spätestens 24 Stunden vor Ablauf kündigst. Die Zahlung läuft über '
      'deine Apple-ID. Kündigen kannst du jederzeit in den Einstellungen '
      'deiner Apple-ID. Kündigst du in den Gratis-Tagen, zahlst du nichts.';
  static const termsAndroid =
      'Das Abo verlängert sich jeden Monat automatisch, bis du es kündigst. '
      'Die Zahlung läuft über dein Google-Play-Konto. Kündigen kannst du '
      'jederzeit in Google Play unter „Abos". Kündigst du in den '
      'Gratis-Tagen, zahlst du nichts.';

  static const unavailable =
      'Belly Buddy Plus ist gerade nicht verfügbar. '
      'Versuch es später nochmal.';
  static const welcome = 'Willkommen bei Belly Buddy Plus!';
  static const pending = 'Dein Kauf wartet noch auf Bestätigung.';
  static const failed =
      'Der Kauf hat nicht geklappt. Du wurdest nicht belastet.';
  static const restoreNone = 'Wir haben kein Abo gefunden.';
  static const restoreFailed =
      'Wiederherstellen hat nicht geklappt. Versuch es später nochmal.';

  // Locks (spec 4.4).

  /// The button of every [PlusLockedCard] and the Alternativen link.
  static const openPlus = 'Belly Buddy Plus ansehen';

  static const patternsTitle = 'Deine Muster sind da';
  static const patternsLine =
      'Mit Belly Buddy Plus siehst du, was an guten und schwierigen Tagen '
      'auffällig oft dabei war.';

  /// „Muster frei!" (day 7) while Plus is locked.
  static const patternsUnlockedLine =
      '7 Tage und 3× Bauchgefühl: Ich hab mir deine Einträge angeschaut. '
      'Deine ersten Muster sind da.';

  static const tipsTitle = 'Jeden Montag neue Tipps';
  static const tipsLine =
      'Mit Belly Buddy Plus schaut sich Belly Buddy jede Woche deine '
      'Einträge an.';

  /// The „Wöchentliche Tipps" switch's subline while Plus is locked.
  static const weeklyTipsSubline = 'Mit Belly Buddy Plus';

  /// Alternativen with none received while Plus is locked.
  static const alternativesNote =
      'Alternativen zu auffälligen Zutaten gibt es mit Belly Buddy Plus.';

  /// The small badge on a button that needs Plus („Für mich anpassen").
  static const plusBadge = 'Plus';

  /// Core's 402 text, for the moment before the paywall opens.
  static const plusRequired = 'Dafür brauchst du Belly Buddy Plus.';

  static const restore = 'Käufe wiederherstellen';
  static const terms = 'Nutzungsbedingungen';
  static const privacy = 'Datenschutz';
  static const manage = 'Abo verwalten';
  static const close = 'Schließen';
  static const linkFailed = 'Die Seite konnte nicht geöffnet werden.';

  /// Account deletion while Plus is trial/active (spec 4.6): deleting the
  /// account does not cancel the store subscription.
  static const deleteWarning =
      'Dein Abo läuft über den Store weiter. Kündige es dort, sonst wird es '
      'weiter verrechnet.';

  /// The status line of spec 4.6 (Ich row subtitle, paywall with Plus).
  /// A payment problem wins; a trial or subscription without an end date
  /// (lifetime, promotional) reads „Gratis-Test" / „Aktiv".
  static String statusLine(PlusStatus status) {
    if (status.billingIssue && status.state != PlusState.none) {
      return 'Zahlung offen – bitte im Store prüfen';
    }
    final at = status.expiresAt;
    final date = at == null ? null : formatDayMonth(at.toLocal());
    return switch (status.state) {
      PlusState.none => 'Alle Funktionen freischalten',
      PlusState.lapsed => 'Abgelaufen · Wieder abonnieren',
      PlusState.trial when date == null => 'Gratis-Test',
      PlusState.trial when status.willRenew => 'Gratis-Test bis $date',
      PlusState.trial => 'Gratis-Test endet am $date',
      PlusState.active when date == null => 'Aktiv',
      PlusState.active when status.willRenew =>
        'Aktiv · verlängert sich am $date',
      PlusState.active => 'Aktiv bis $date',
    };
  }
}
