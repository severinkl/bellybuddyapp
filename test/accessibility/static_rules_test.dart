import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The accessibility pass's static rules over `lib/` (spec §4.2), modelled on
/// `test/utils/vocabulary_test.dart`: comments are dropped and string
/// literals blanked, then each widget call is matched to its closing
/// parenthesis and its top-level arguments are read.
///
/// An offence is named `<file>:<pattern>#<n>`, the n-th match of the pattern
/// in that file (1-based, offending or not), so fixing one call by adding
/// what it lacks keeps the others' names. Each rule has a commented
/// allowlist of today's offenders with the task that removes them as the
/// reason; the area task deletes its entries with the fix. An entry that no
/// longer offends fails the rule too, so none is left behind.
///
/// Limits: `${…}` inside strings is blanked with the string; a widget built
/// through a variable or a helper (not a literal call) isn't seen.
void main() {
  group('static rules', () {
    for (final rule in _rules) {
      test(rule.title, () {
        final found = <String>{};
        for (final file in _libFiles()) {
          if (rule.exempt.any(file.path.endsWith)) continue;
          found.addAll(rule.offences(file.path, file.readAsStringSync()));
        }
        final fresh = found.difference(rule.allowed.keys.toSet()).toList()
          ..sort();
        final stale = rule.allowed.keys.toSet().difference(found).toList()
          ..sort();
        expect(fresh, isEmpty, reason: 'new offenders:\n${fresh.join('\n')}');
        expect(
          stale,
          isEmpty,
          reason:
              'fixed or renumbered, remove from the allowlist:\n'
              '${stale.join('\n')}',
        );
      });
    }

    test('every allowlist reason that names a task names XA4–XA10', () {
      final orphans = [
        for (final rule in _rules)
          for (final MapEntry(:key, :value) in rule.allowed.entries)
            for (final id in RegExp(r'XA\d+').allMatches(value))
              if (!RegExp(r'^XA([4-9]|10)$').hasMatch(id.group(0)!))
                '$key → $value',
      ];
      expect(orphans, isEmpty);
    });
  });

  group('the scan', () {
    test('blanks comments and strings, keeps lines', () {
      final code = _mask(
        "a('IconButton(') // IconButton(\n"
        '/* IconButton( */ b("x\\")") r\'(\' \'\'\'\n(\n\'\'\'',
      );
      expect(code, isNot(contains('IconButton')));
      expect(code.split('\n'), hasLength(4));
      expect(RegExp(r'\(').allMatches(code), hasLength(2));
    });

    test('an IconButton without a tooltip of its own offends', () {
      final rule = _rules.first;
      expect(
        rule.offences('f.dart', '''
IconButton(icon: Icon(Icons.add), onPressed: f, tooltip: 'Neu');
IconButton(icon: Tooltip(message: 'x', tooltip: 1), onPressed: f);
IconButton.styleFrom(foregroundColor: c);
IconButton(onPressed: () => g('tooltip:'), icon: x);
'''),
        ['f.dart:IconButton#2', 'f.dart:IconButton#3'],
      );
    });

    test('a GestureDetector or InkWell around just an Icon offends', () {
      final rule = _rules[1];
      expect(
        rule.offences('f.dart', '''
GestureDetector(onTap: f, child: const Icon(Icons.close));
InkWell(onTap: f, child: Padding(padding: p, child: Icon(Icons.close)));
InkWell(child: Row(children: [Icon(Icons.close), Text('x')]), onTap: f);
GestureDetector(child: Container(decoration: d, child: Center(child: Icon(i))));
'''),
        [
          'f.dart:GestureDetector#1',
          'f.dart:GestureDetector#2',
          'f.dart:InkWell#1',
        ],
      );
    });

    test('so does one around just a close glyph as text', () {
      final rule = _rules[1];
      expect(
        rule.offences('f.dart', r'''
GestureDetector(onTap: f, child: const Text('\u{2715}', style: s));
InkWell(onTap: f, child: Padding(padding: p, child: Text('×')));
GestureDetector(onTap: f, child: Text("x"));
InkWell(onTap: f, child: Center(child: Text('✕')));
GestureDetector(onTap: f, child: Text('xy'));
GestureDetector(onTap: f, child: Text(label));
InkWell(onTap: f, child: Row(children: [Text('✕'), Text('Aus')]));
'''),
        [
          'f.dart:GestureDetector#1',
          'f.dart:GestureDetector#2',
          'f.dart:InkWell#1',
          'f.dart:InkWell#2',
        ],
      );
    });
  });
}

Iterable<File> _libFiles() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

class _Rule {
  const _Rule(
    this.title,
    this.patterns, {
    this.offends = _always,
    this.exempt = const [],
    this.allowed = const {},
  });

  final String title;

  /// Anchor name → the call or expression it matches.
  final Map<String, String> patterns;

  /// Whether a match whose top-level arguments are [args] offends, in the
  /// masked [code] of a file whose text is [source].
  final bool Function(Map<String, _Arg> args, String code, String source)
  offends;

  /// Files (path suffixes) the rule doesn't apply to.
  final List<String> exempt;

  /// `path:anchor#n` → reason (the task that removes it).
  final Map<String, String> allowed;

  List<String> offences(String path, String source) {
    final code = _mask(source);
    return [
      for (final MapEntry(key: anchor, value: pattern) in patterns.entries)
        for (final (i, m) in RegExp(pattern).allMatches(code).indexed)
          if (offends(_topLevelArgs(code, m.end), code, source))
            '${path.replaceAll(r'\', '/')}:$anchor#${i + 1}',
    ];
  }
}

bool _always(Map<String, _Arg> _, String _, String _) => true;

/// A top-level argument: its masked [code], from offset [at] of the file.
class _Arg {
  const _Arg(this.code, this.at);

  final String code;
  final int at;
}

final _icon = RegExp(r'^(const\s+)?Icon\(');

/// Boxes that only place or paint behind their child.
final _wrapper = RegExp(
  r'^(const\s+)?(Padding|Container|SizedBox|Center|Align|DecoratedBox|'
  r'ConstrainedBox|Opacity)\(',
);

final _text = RegExp(r'^(const\s+)?Text\(');

/// A close glyph drawn as text: an icon in all but name.
const _glyphs = {'✕', '×', r'\u{2715}', r'\u2715', 'x'};

/// Whether the [args]' `child:` is an Icon or a single close glyph
/// ([_glyphs]) as a `Text`, directly or through boxes that only place or
/// paint it ([_wrapper]): the icon is all there is to tap.
bool _childIsIcon(Map<String, _Arg> args, String code, String source) {
  final arg = args['child'];
  if (arg == null) return false;
  final lead = arg.code.length - arg.code.trimLeft().length;
  final child = arg.code.trim();
  if (_icon.hasMatch(child) || _isGlyph(child, arg.at + lead, code, source)) {
    return true;
  }
  final box = _wrapper.firstMatch(child);
  return box != null &&
      _childIsIcon(_topLevelArgs(code, arg.at + lead + box.end), code, source);
}

/// Whether [child] (masked, from offset [at]) is `Text('<glyph>', …)`.
bool _isGlyph(String child, int at, String code, String source) {
  final call = _text.firstMatch(child);
  if (call == null) return false;
  final text = _topLevelArgs(code, at + call.end)['#0'];
  if (text == null) return false;
  final lead = text.code.length - text.code.trimLeft().length;
  final literal = source.substring(
    text.at + lead,
    text.at + lead + text.code.trim().length,
  );
  final m = RegExp(r'''^(['"])(.*)\1$''').firstMatch(literal);
  return m != null && _glyphs.contains(m.group(2));
}

const _rules = [
  _Rule('every IconButton has a tooltip', {
    'IconButton': r'(?<![\w.])IconButton(\.(?!styleFrom)\w+)?\(',
  }, offends: _noTooltip),
  _Rule(
    // „Directly": the Icon is the child, or the only thing inside boxes
    // that just place or paint it (the audit's five ✕s, spec §2.1).
    'no GestureDetector or InkWell whose child is directly an Icon '
    '(use BbIconTap)',
    {
      'GestureDetector': r'(?<![\w.])GestureDetector\(',
      'InkWell': r'(?<![\w.])InkWell\(',
    },
    offends: _childIsIcon,
    allowed: {
      'lib/widgets/common/circle_icon_button.dart:GestureDetector#1':
          'the shared round icon button: a Semantics button with its label '
          'wraps it (spec §2.1)',
    },
  ),
  _Rule(
    'Image.asset only in MascotImage and reminder_preview.dart',
    {'Image.asset': r'(?<![\w.])Image\.asset\('},
    exempt: [
      'lib/widgets/common/mascot_image.dart',
      'lib/screens/buddy/widgets/reminder_preview.dart',
    ],
  ),
  _Rule(
    'no MaterialTapTargetSize.shrinkWrap, minimumSize: Size.zero or '
    'Size(0, 0)',
    {
      'shrinkWrap': r'MaterialTapTargetSize\.shrinkWrap',
      'minimumSize':
          r'minimumSize:\s*(const\s+)?Size(\.zero\b|\(\s*0(\.0)?\s*,\s*0(\.0)?\s*\))',
    },
  ),
  _Rule('no foreground.withValues(alpha: 0.6) (use foregroundInactive)', {
    'foreground@60':
        r'(?<![\w])foreground\.withValues\(\s*alpha:\s*0?\.60*\s*\)',
  }),
];

bool _noTooltip(Map<String, _Arg> args, String _, String _) =>
    !args.containsKey('tooltip');

/// The arguments at the top level of the call whose `(` ends at [open] in
/// [code] (masked): name → its value, the positional ones as `#0`, `#1` ….
Map<String, _Arg> _topLevelArgs(String code, int open) {
  final args = <String, _Arg>{};
  var depth = 0;
  var start = open;
  var positional = 0;
  void take(int end) {
    final arg = code.substring(start, end);
    final lead = arg.length - arg.trimLeft().length;
    final m = RegExp(r'^(\w+)\s*:(?!:)').firstMatch(arg.trimLeft());
    if (m != null) {
      args[m.group(1)!] = _Arg(
        arg.substring(lead + m.end).trimRight(),
        start + lead + m.end,
      );
    } else if (arg.trim().isNotEmpty) {
      args['#${positional++}'] = _Arg(arg.trimRight(), start);
    }
  }

  for (var i = open; i < code.length; i++) {
    final c = code[i];
    if (c == '(' || c == '[' || c == '{') {
      depth++;
    } else if (c == ')' || c == ']' || c == '}') {
      if (depth == 0) {
        take(i);
        break;
      }
      depth--;
    } else if (c == ',' && depth == 0) {
      take(i);
      start = i + 1;
    }
  }
  return args;
}

/// [source] with comments and the contents of string literals replaced by
/// spaces (quotes and newlines kept, so offsets and lines stay).
String _mask(String source) {
  final out = StringBuffer();
  var i = 0;
  final n = source.length;
  String at(int j) => j < n ? source[j] : '';
  void blank(int from, int to) {
    for (var j = from; j < to; j++) {
      out.write(source[j] == '\n' ? '\n' : ' ');
    }
  }

  while (i < n) {
    final c = source[i];
    if (c == '/' && at(i + 1) == '/') {
      final end = source.indexOf('\n', i);
      final stop = end < 0 ? n : end;
      blank(i, stop);
      i = stop;
    } else if (c == '/' && at(i + 1) == '*') {
      var depth = 1;
      var j = i + 2;
      while (j < n && depth > 0) {
        if (source.startsWith('/*', j)) {
          depth++;
          j += 2;
        } else if (source.startsWith('*/', j)) {
          depth--;
          j += 2;
        } else {
          j++;
        }
      }
      blank(i, j);
      i = j;
    } else if (c == "'" || c == '"') {
      final raw = i > 0 && source[i - 1] == 'r';
      final triple = source.startsWith(c * 3, i);
      final quote = triple ? c * 3 : c;
      out.write(quote);
      var j = i + quote.length;
      while (j < n && !source.startsWith(quote, j)) {
        if (!triple && source[j] == '\n') break;
        j += !raw && source[j] == r'\' ? 2 : 1;
      }
      j = j > n ? n : j;
      blank(i + quote.length, j);
      if (j < n && source.startsWith(quote, j)) out.write(quote);
      i = j + (j < n && source.startsWith(quote, j) ? quote.length : 0);
    } else {
      out.write(c);
      i++;
    }
  }
  return out.toString();
}
