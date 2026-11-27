import 'package:flutter_test/flutter_test.dart';
import 'package:belly_buddy/utils/drink_helpers.dart';
import 'package:belly_buddy/models/drink.dart';
import 'package:belly_buddy/config/constants.dart';

void main() {
  Drink makeDrink(String id, String name) => Drink(id: id, name: name);

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
      final drinks = [tee, orangensaft]; // no starter drink among them
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

    test('results capped at searchResultLimit', () {
      final manyDrinks = List.generate(
        DrinkHelpers.searchResultLimit + 5,
        (i) => makeDrink('$i', 'Drink $i'),
      );
      final result = DrinkHelpers.search('Drink', manyDrinks);
      expect(result.length, DrinkHelpers.searchResultLimit);
    });

    test('prefix matches ranked higher', () {
      final drinks = [makeDrink('1', 'Eiskaffee'), makeDrink('2', 'Kaffee')];
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

  test('isValidAmount: 1 to 3000 ml', () {
    expect(DrinkHelpers.isValidAmount(0), isFalse);
    expect(DrinkHelpers.isValidAmount(1), isTrue);
    expect(DrinkHelpers.isValidAmount(3000), isTrue);
    expect(DrinkHelpers.isValidAmount(3001), isFalse);
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

    test('caps at maxAmountMl', () {
      expect(DrinkHelpers.maxAmountMl, 3000);
      expect(DrinkHelpers.parseAmount('3000'), 3000);
      expect(DrinkHelpers.parseAmount('3001'), null);
      expect(DrinkHelpers.parseAmount('999999'), null);
    });
  });

  group('amountError', () {
    test('no error for an empty field or a valid amount', () {
      expect(DrinkHelpers.amountError(''), isNull);
      expect(DrinkHelpers.amountError('1'), isNull);
      expect(DrinkHelpers.amountError('3000'), isNull);
    });

    test('names the allowed range otherwise', () {
      const message = 'Bitte gib 1 bis 3000 ml ein.';
      expect(DrinkHelpers.amountError('0'), message);
      expect(DrinkHelpers.amountError('3001'), message);
      expect(DrinkHelpers.amountError('99999'), message);
    });
  });

  group('formatAmount', () {
    test('below 1000 shows ml', () {
      expect(DrinkHelpers.formatAmount(250), '250 ml');
    });

    test('exactly 1000 shows 1 l without .0', () {
      expect(DrinkHelpers.formatAmount(1000), '1 l');
    });

    test('1500 shows 1.5 l', () {
      expect(DrinkHelpers.formatAmount(1500), '1,5 l');
    });

    test('2000 shows 2 l without .0', () {
      expect(DrinkHelpers.formatAmount(2000), '2 l');
    });

    test('0 shows 0 ml', () {
      expect(DrinkHelpers.formatAmount(0), '0 ml');
    });
  });

  group('drinks screen helpers', () {
    test('iconFor maps names by keyword in order', () {
      final cases = {
        'Wasser': DrinkIcon.glass,
        'Mineralwasser': DrinkIcon.glass,
        'Rotwein': DrinkIcon.glass,
        'Pfefferminztee': DrinkIcon.hotCup,
        'Kakao': DrinkIcon.hotCup,
        'Gemüsebrühe': DrinkIcon.hotCup,
        'Kaffee': DrinkIcon.cup,
        'Milchkaffee': DrinkIcon.cup,
        'Chai Latte': DrinkIcon.cup,
        'Apfelsaft gespritzt': DrinkIcon.bottle,
        'Eistee': DrinkIcon.bottle,
        'Tomatensaft': DrinkIcon.bottle,
        'Zitronenlimo': DrinkIcon.bottle,
        'Hafermilch': DrinkIcon.carton,
        'Sojadrink': DrinkIcon.carton,
        'Kefir': DrinkIcon.carton,
        'Cola Zero': DrinkIcon.can,
        'Energy Drink': DrinkIcon.can,
        'Alkoholfreies Bier': DrinkIcon.can,
      };
      cases.forEach(
        (name, icon) => expect(DrinkHelpers.iconFor(name), icon, reason: name),
      );
    });

    test('iconFor ignores case and falls back to glass', () {
      expect(DrinkHelpers.iconFor('KAFFEE'), DrinkIcon.cup);
      expect(DrinkHelpers.iconFor('Xyz'), DrinkIcon.glass);
      expect(DrinkHelpers.iconFor(''), DrinkIcon.glass);
    });

    test('glassFills: 1000 drunk gives four full glasses', () {
      expect(
        DrinkHelpers.glassFills(1000, 0),
        List.filled(4, (drunk: 1.0, pending: 0.0)),
      );
    });

    test('glassFills: 1100 drunk + 400 pending splits the fifth glass', () {
      expect(DrinkHelpers.glassFills(1100, 400), [
        ...List.filled(4, (drunk: 1.0, pending: 0.0)),
        (drunk: 0.4, pending: 0.6),
        (drunk: 0.0, pending: 1.0),
      ]);
    });

    test('glassFills: 1000 + 400 gives two pending glasses, last 60 %', () {
      final f = DrinkHelpers.glassFills(1000, 400);
      expect(f.length, 6);
      expect(f[4], (drunk: 0.0, pending: 1.0));
      expect(f[5].pending, closeTo(0.6, 1e-9));
    });

    test('glassFills: 0 ml is one empty glass; 15 l is capped at 48', () {
      expect(DrinkHelpers.glassFills(0, 0), [(drunk: 0.0, pending: 0.0)]);
      expect(DrinkHelpers.glassFills(15000, 0).length, 48);
    });

    test('glassesLabel', () {
      expect(DrinkHelpers.glassesLabel(0, 0), 'Nichts eingetragen');
      expect(DrinkHelpers.glassesLabel(250, 0), '1 Glas zu 250 ml getrunken');
      expect(
        DrinkHelpers.glassesLabel(1000, 0),
        '4 Gläser zu je 250 ml getrunken',
      );
      expect(
        DrinkHelpers.glassesLabel(1100, 0),
        '4 Gläser zu je 250 ml und 100 ml getrunken',
      );
      expect(DrinkHelpers.glassesLabel(100, 0), '100 ml getrunken');
      expect(
        DrinkHelpers.glassesLabel(1000, 400),
        '4 Gläser zu je 250 ml getrunken, dazu kommen 400 ml',
      );
      expect(
        DrinkHelpers.glassesLabel(0, 1000),
        'Nichts eingetragen, dazu kommen 1 l',
      );
      expect(
        DrinkHelpers.glassesLabel(0, 400),
        'Nichts eingetragen, dazu kommen 400 ml',
      );
    });

    final saft = makeDrink('s', 'Saft');
    final milch = makeDrink('m', 'Milch');
    final kakao = makeDrink('c', 'Kakao');
    final mate = makeDrink('x', 'Mate');

    test('tileDrinks: Wasser first, at most five, no duplicates', () {
      final r = DrinkHelpers.tileDrinks([
        kaffee,
        wasser,
        tee,
        saft,
        milch,
        kakao,
        kaffee,
      ], null);
      expect(r, [wasser, kaffee, tee, saft, milch]);
    });

    test('tileDrinks: a selected drink outside the five takes the fifth', () {
      final r = DrinkHelpers.tileDrinks([
        kaffee,
        wasser,
        tee,
        saft,
        milch,
        kakao,
      ], mate);
      expect(r, [wasser, kaffee, tee, saft, mate]);
    });

    test('tileDrinks: a selected drink among the five changes nothing', () {
      final r = DrinkHelpers.tileDrinks([
        kaffee,
        wasser,
        tee,
        saft,
        milch,
        kakao,
      ], tee);
      expect(r, [wasser, kaffee, tee, saft, milch]);
    });

    test('saveLabel', () {
      final t = makeDrink('p', 'Pfefferminztee');
      expect(DrinkHelpers.saveLabel(t, 400), '400 ml Pfefferminztee eintragen');
      expect(DrinkHelpers.saveLabel(t, 1000), '1 l Pfefferminztee eintragen');
      expect(DrinkHelpers.saveLabel(t, null), 'Pfefferminztee eintragen');
    });

    test('timeLabel', () {
      final now = DateTime(2026, 11, 27, 15);
      expect(
        DrinkHelpers.timeLabel(DateTime(2026, 11, 27, 14, 30), now),
        'Heute, 14:30',
      );
      expect(
        DrinkHelpers.timeLabel(DateTime(2026, 11, 26, 14, 30), now),
        'Gestern, 14:30',
      );
      expect(
        DrinkHelpers.timeLabel(DateTime(2026, 11, 19, 9, 5), now),
        '19. Nov., 09:05',
      );
    });

    test('buildQuickDrinks fills a user without history with starters', () {
      final all = [
        makeDrink('a', 'Apfelsaftschorle'),
        makeDrink('c', 'Cola'),
        makeDrink('k', 'kaffee'),
        makeDrink('w', 'Wasser'),
      ];
      expect(DrinkHelpers.buildQuickDrinks(all, []).map((d) => d.name), [
        'Wasser',
        'kaffee',
        'Apfelsaftschorle',
      ]);
    });

    test('buildQuickDrinks with five recents adds no starters', () {
      final all = [
        wasser,
        kaffee,
        tee,
        saft,
        milch,
        kakao,
        makeDrink('p', 'Pfefferminztee'),
      ];
      final r = DrinkHelpers.buildQuickDrinks(all, ['k', 't', 's', 'm']);
      expect(r.map((d) => d.id), ['w', 'k', 't', 's', 'm']);
    });

    test('vessels match AppConstants.drinkSizes', () {
      expect(DrinkVessel.values.map((v) => v.ml), AppConstants.drinkSizes);
      expect(DrinkVessel.values.map((v) => v.label), [
        'Glas',
        'Dose',
        'Flasche',
        'Große',
      ]);
    });
  });
}
