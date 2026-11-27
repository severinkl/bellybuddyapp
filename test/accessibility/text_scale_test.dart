import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../helpers/layout_checks.dart';
import 'a11y_screens.dart';

/// The tasks that own the pending checks (the accessibility plan's area
/// tasks).
final _areaTask = RegExp(r'^XA([4-9]|10)$');

/// The [RoutePaths] constants in `lib/router/route_names.dart`: name → path.
Map<String, String> _routePaths() {
  final source = File('lib/router/route_names.dart').readAsStringSync();
  final body = source.substring(source.indexOf('class RoutePaths'));
  return {
    for (final m in RegExp(
      r"static const String (\w+) = '([^']+)';",
    ).allMatches(body))
      m.group(1)!: m.group(2)!,
  };
}

/// Every main screen at 200 % text: nothing overflows at the top or the
/// bottom (horizontal overflows are test-font noise, see
/// [verticalOverflows]). Plus the guards that keep the screen list honest.
void main() {
  setUpA11yScreens();

  for (final s in a11yScreens) {
    final owner = s.pending[A11yCheck.textScale200];
    testWidgets(
      '${s.name}: no vertical overflow at 200 % text'
      '${owner == null ? '' : ' (pending $owner)'}',
      skip: owner != null,
      (tester) async {
        final errors = await collectFlutterErrors(
          () => pumpA11yScreen(tester, s, textScale: 2),
        );
        expect(verticalOverflows(errors), isEmpty);
      },
    );
  }

  test('every pending check names a task XA4–XA10', () {
    final orphans = [
      for (final s in a11yScreens)
        for (final MapEntry(:key, :value) in s.pending.entries)
          if (!_areaTask.hasMatch(value)) '${s.name}: ${key.name} → $value',
    ];
    expect(orphans, isEmpty);
  });

  test('screen names are unique', () {
    final names = a11yScreens.map((s) => s.name).toList();
    expect(names.toSet().length, names.length);
  });

  test('every RoutePaths route except loading is in a11yScreens', () {
    final routes = _routePaths()..remove('loading');
    expect(routes, isNotEmpty);
    final literals = routes.values.where((p) => !p.contains(':')).toSet();
    final missing = [
      for (final MapEntry(key: name, value: pattern) in routes.entries)
        if (!a11yScreens.any(
          (s) =>
              RegExp(
                '^${pattern.replaceAll(RegExp(r':\w+'), '[^/]+')}\$',
              ).hasMatch(s.path) &&
              // A literal route never stands in for a pattern
              // (`/recipe/new` is not `/recipe/:id`).
              (pattern == s.path || !literals.contains(s.path)),
        ))
          '$name ($pattern)',
    ];
    expect(missing, isEmpty);
  });
}
