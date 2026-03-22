import 'package:flutter_test/flutter_test.dart';
import 'package:belly_buddy/utils/drink_helpers.dart';
import 'package:belly_buddy/models/drink.dart';

void main() {
  Drink makeDrink(String id, String name) =>
      Drink(id: id, name: name);

  final wasser = makeDrink('w', 'Wasser');
  final kaffee = makeDrink('k', 'Kaffee');
  final tee = makeDrink('t', 'Tee');
  final orangensaft = makeDrink('o', 'Orangensaft');
  final apfelsaft = makeDrink('a', 'Apfelsaft');

  group('buildQuickDrinks', () {
    test('Wasser appears first when present', () {
      final result = DrinkHelpers.buildQuickDrinks(
        [kaffee, wasser, tee],
        ['k', 't'],
      );
      expect(result.first.name, 'Wasser');
    });

    test('recent drinks follow in order, skipping Wasser duplicate', () {
      final result = DrinkHelpers.buildQuickDrinks(
        [kaffee, wasser, tee],
        ['w', 'k', 't'],
      );
      expect(result.map((d) => d.id).toList(), ['w', 'k', 't']);
    });

    test('falls back to first 11 drinks when no recent IDs', () {
      final drinks = List.generate(15, (i) => makeDrink('$i', 'Drink $i'));
      final result = DrinkHelpers.buildQuickDrinks(drinks, []);
      expect(result.length, 11);
    });

    test('empty allDrinks returns empty list', () {
      final result = DrinkHelpers.buildQuickDrinks([], ['w']);
      expect(result, isEmpty);
    });

    test('falls back when recent IDs dont match any drink', () {
      final drinks = [kaffee, tee];
      final result = DrinkHelpers.buildQuickDrinks(drinks, ['nonexistent']);
      expect(result.length, 2); // fallback: take first 11
    });
  });

  group('search', () {
    final allDrinks = [wasser, kaffee, tee, orangensaft, apfelsaft];

    test('empty query returns empty list', () {
      expect(DrinkHelpers.search('', allDrinks), isEmpty);
    });

    test('whitespace query returns empty list', () {
      expect(DrinkHelpers.search('   ', allDrinks), isEmpty);
    });

    test('single word matches substring', () {
      final result = DrinkHelpers.search('saft', allDrinks);
      expect(result.length, 2);
      expect(result.every((d) => d.name.contains('saft')), true);
    });

    test('multi-word requires all words to match', () {
      final result = DrinkHelpers.search('orangen saft', allDrinks);
      expect(result.length, 1);
      expect(result.first.name, 'Orangensaft');
    });

    test('results capped at 8', () {
      final manyDrinks = List.generate(20, (i) => makeDrink('$i', 'Drink $i'));
      final result = DrinkHelpers.search('Drink', manyDrinks);
      expect(result.length, 8);
    });

    test('prefix matches ranked higher', () {
      final drinks = [
        makeDrink('1', 'Eiskaffee'),
        makeDrink('2', 'Kaffee'),
      ];
      final result = DrinkHelpers.search('kaffee', drinks);
      expect(result.first.name, 'Kaffee');
    });

    test('word-start matches ranked higher than mid-word', () {
      final drinks = [
        makeDrink('1', 'Milchkaffee'),
        makeDrink('2', 'Eis Kaffee'),
      ];
      final result = DrinkHelpers.search('kaffee', drinks);
      expect(result.first.name, 'Eis Kaffee');
    });

    test('case insensitive', () {
      final result = DrinkHelpers.search('WASSER', allDrinks);
      expect(result.length, 1);
      expect(result.first.name, 'Wasser');
    });
  });

  group('parseAmount', () {
    test('valid positive int string returns int', () {
      expect(DrinkHelpers.parseAmount('250'), 250);
    });

    test('zero returns null', () {
      expect(DrinkHelpers.parseAmount('0'), null);
    });

    test('negative number returns null', () {
      expect(DrinkHelpers.parseAmount('-5'), null);
    });

    test('non-numeric string returns null', () {
      expect(DrinkHelpers.parseAmount('abc'), null);
    });

    test('empty string returns null', () {
      expect(DrinkHelpers.parseAmount(''), null);
    });
  });

  group('formatAmount', () {
    test('below 1000 shows ml', () {
      expect(DrinkHelpers.formatAmount(250), '250 ml');
    });

    test('exactly 1000 shows 1 L without .0', () {
      expect(DrinkHelpers.formatAmount(1000), '1 L');
    });

    test('1500 shows 1.5 L', () {
      expect(DrinkHelpers.formatAmount(1500), '1.5 L');
    });

    test('2000 shows 2 L without .0', () {
      expect(DrinkHelpers.formatAmount(2000), '2 L');
    });

    test('0 shows 0 ml', () {
      expect(DrinkHelpers.formatAmount(0), '0 ml');
    });
  });
}
