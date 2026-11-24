import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the one-vocabulary rule (spec 5.9): banned words must not appear in
/// user-facing string literals under lib/. Comments are ignored.
///
/// Two passes per non-comment line:
/// - every banned pattern against each one-line string literal;
/// - the narrow, unambiguous tokens [rawBanned] („Speise(n)", „Empfehlung")
///   against the whole line, which also covers literals nested in `${…}`
///   that the literal pattern cannot isolate.
///
/// Limits: the scan is line-based. Literals spanning lines (adjacent
/// literals are fine, each is on its own line; triple-quoted strings are
/// not), banned words split across adjacent literals, and the wider
/// patterns inside nested `${…}` literals are not caught. Block comments
/// are skipped only when they start a line.
void main() {
  final banned = <RegExp>[
    RegExp(r'Essen tracken'),
    RegExp(r'Bauch-Buddy'),
    RegExp(r'Belly Freund'),
    RegExp(r'\bLogbuch'),
    RegExp(r'Essens-Tagebuch'),
    RegExp(r'Ernährungstagebuch'),
    RegExp(r'Zutaten-Vorschläge'),
    RegExp(r'Toilettengang'),
    RegExp(r'Stuhlgang'),
    RegExp(r'Getränk tracken'),
    RegExp(r'Getränk hinzufügen'),
    RegExp(r'jetzt tracken'),
    RegExp(r'\bSerie\b'),
    RegExp(r'\bEmpfehlung'),
    RegExp(r'\bSpeisen?\b'),
    RegExp(r'^(speichern|weiter)$'),
    // The verb is „eintragen": no tracken/getrackt, no erfassen/erfasst.
    // Whole words only, so `tracked_at`, `/meal-tracker` and `trackedAt`
    // stay allowed.
    RegExp(r'\b(ge)?[Tt]rack(e|en|st|t|te|ten)\b'),
    RegExp(r'\b[Ee]rfass'),
    // The four Bauchgefühl levels: sehr gut, gut, mittel, schlecht.
    RegExp(r'[Dd]urchschnittlich'),
  ];

  // Never used outside of copy, so a hit anywhere in code is copy.
  final rawBanned = <RegExp>[RegExp(r'\bSpeisen?\b'), RegExp(r'\bEmpfehlung')];

  // Files whose copy is deliberately exempt.
  const exempt = ['health_consent_content.dart', 'buddy_copy.dart'];

  // Single- or double-quoted literals on one line (handles escapes).
  final literal = RegExp(r'''('(?:[^'\\\n]|\\.)*'|"(?:[^"\\\n]|\\.)*")''');

  String stripComment(String line) {
    final t = line.trimLeft();
    if (t.startsWith('//')) return '';
    // Drop trailing // comments that are outside of string literals.
    var inS = false, inD = false;
    for (var i = 0; i < line.length - 1; i++) {
      final c = line[i];
      if (c == r'\') {
        i++;
        continue;
      }
      if (c == "'" && !inD) inS = !inS;
      if (c == '"' && !inS) inD = !inD;
      if (!inS && !inD && c == '/' && line[i + 1] == '/') {
        return line.substring(0, i);
      }
    }
    return line;
  }

  /// The offending lines of [lines] (1-based numbers with their text).
  List<String> offendersIn(List<String> lines) {
    final offenders = <String>[];
    var inBlock = false;
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i];
      if (inBlock) {
        if (line.contains('*/')) inBlock = false;
        continue;
      }
      if (line.trimLeft().startsWith('/*')) {
        inBlock = !line.contains('*/');
        continue;
      }
      line = stripComment(line);
      final literalHit = literal.allMatches(line).any((m) {
        final body = m.group(0)!.substring(1, m.group(0)!.length - 1);
        return banned.any((re) => re.hasMatch(body));
      });
      if (literalHit || rawBanned.any((re) => re.hasMatch(line))) {
        offenders.add('${i + 1}: ${line.trim()}');
      }
    }
    return offenders;
  }

  test('no banned vocabulary in user-facing strings', () {
    final offenders = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !exempt.any(f.path.endsWith));
    for (final file in files) {
      offenders.addAll(
        offendersIn(file.readAsLinesSync()).map((o) => '${file.path}:$o'),
      );
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  group('the scan', () {
    test('finds a banned word in a literal, not in a comment', () {
      expect(
        offendersIn([
          "final a = 'Jetzt Essen tracken';",
          '// Essen tracken',
          "final b = 'eintragen'; // Essen tracken",
        ]),
        ["1: final a = 'Jetzt Essen tracken';"],
      );
    });

    test('finds tracken/erfassen as words, not inside identifiers', () {
      expect(
        offendersIn([
          "final a = 'Vergiss nicht, deine Mahlzeiten zu tracken!';",
          "final b = 'Erinnerungen zum Tracken';",
          "final c = 'Schon getrackt?';",
          "final d = 'Dein Eintrag wurde erfasst.';",
          "final e = 'Erfassung läuft';",
          "final f = select('id, tracked_at');",
          "final g = '/meal-tracker';",
          "final h = {'trackedAt': x};",
          "final i = 'Dein Eintrag ist eingetragen.';",
        ]).map((o) => o.split(':').first),
        ['1', '2', '3', '4', '5'],
      );
    });

    test('finds „Speise(n)" and „Empfehlung" in literals nested in '
        r'${…}', () {
      expect(
        offendersIn([
          r"""final a = '${n > 1 ? 'Speisen' : 'Essen'} heute';""",
          r"""final b = '${tip ? 'Neue Empfehlung' : ''}';""",
          r"""final c = '${n > 1 ? 'Gerichte' : 'Essen'} heute';""",
        ]).map((o) => o.split(':').first),
        ['1', '2'],
      );
    });
  });
}
