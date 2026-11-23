import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the one-vocabulary rule (spec 5.9): banned words must not appear in
/// user-facing string literals under lib/. Comments are ignored.
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
  ];

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

  test('no banned vocabulary in user-facing strings', () {
    final offenders = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !exempt.any(f.path.endsWith));
    for (final file in files) {
      final lines = file.readAsLinesSync();
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
        for (final m in literal.allMatches(line)) {
          final body = m.group(0)!.substring(1, m.group(0)!.length - 1);
          for (final re in banned) {
            if (re.hasMatch(body)) {
              offenders.add('${file.path}:${i + 1}: $body');
              break;
            }
          }
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
