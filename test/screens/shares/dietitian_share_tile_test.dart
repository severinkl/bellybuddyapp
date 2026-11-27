import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/models/data_share.dart';
import 'package:belly_buddy/screens/shares/widgets/dietitian_share_tile.dart';

import '../../helpers/share_fakes.dart';

void main() {
  final now = DateTime(2026, 11, 26, 12);
  setUpAll(() => initializeDateFormatting('de_DE', null));

  Future<void> pump(
    WidgetTester tester,
    DataShare share, {
    ShareState? state,
    VoidCallback? onEdit,
    VoidCallback? onEnd,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: DietitianShareTile(
            share: share,
            state: state ?? share.stateAt(now),
            now: now,
            onEdit: onEdit ?? () {},
            onEnd: onEnd ?? () {},
          ),
        ),
      ),
    ),
  );

  group('Sieht', () {
    test('everything but photos / everything', () {
      expect(
        dietitianSeesLine(testDietitianShare()),
        'Sieht alles außer Fotos',
      );
      expect(
        dietitianSeesLine(testDietitianShare(photos: true)),
        'Sieht alles',
      );
    });

    test('the switched-on names', () {
      String see({
        bool meals = false,
        bool drinks = false,
        bool gut = false,
        bool toilet = false,
        bool patterns = false,
        bool photos = false,
      }) => dietitianSeesLine(
        testDietitianShare(
          meals: meals,
          drinks: drinks,
          gut: gut,
          toilet: toilet,
          patterns: patterns,
          photos: photos,
        ),
      );
      expect(see(meals: true), 'Sieht Mahlzeiten');
      expect(see(meals: true, gut: true), 'Sieht Mahlzeiten und Bauchgefühl');
      expect(
        see(meals: true, gut: true, toilet: true),
        'Sieht Mahlzeiten, Bauchgefühl und Toiletten-Einträge',
      );
      expect(
        see(meals: true, drinks: true, gut: true, toilet: true, photos: true),
        'Sieht Mahlzeiten, Getränke, Bauchgefühl, Toiletten-Einträge und '
        'Fotos',
      );
    });
  });

  testWidgets('active open-ended: card, dates, no end line, both buttons', (
    tester,
  ) async {
    await pump(tester, testDietitianShare());
    expect(find.text('Anna Berger'), findsOneWidget);
    expect(
      find.text('Diätolog:in (eigene Angabe) · Praxis Berger, Innsbruck'),
      findsOneWidget,
    );
    expect(find.text('Aktiv'), findsOneWidget);
    expect(find.text('seit 5. Nov.'), findsOneWidget);
    expect(find.text('noch nicht angesehen'), findsOneWidget);
    expect(find.textContaining('bis '), findsNothing);
    expect(find.text('Ändern'), findsOneWidget);
    expect(find.text('Beenden'), findsOneWidget);
  });

  testWidgets('last seen yesterday, and a 90-day one shows its end', (
    tester,
  ) async {
    await pump(
      tester,
      testDietitianShare(
        lastOpenedAt: DateTime(2026, 11, 25, 16, 40),
        expiresAt: DateTime(2027, 1, 14, 10),
      ),
    );
    expect(find.text('zuletzt angesehen gestern, 16:40'), findsOneWidget);
    expect(find.text('bis 14. Jan.'), findsOneWidget);
  });

  test('seen today and earlier', () {
    expect(
      dietitianSeenLine(
        testDietitianShare(lastOpenedAt: DateTime(2026, 11, 26, 9, 5)),
        now,
      ),
      'zuletzt angesehen heute, 09:05',
    );
    expect(
      dietitianSeenLine(
        testDietitianShare(lastOpenedAt: DateTime(2026, 11, 20, 9, 5)),
        now,
      ),
      'zuletzt angesehen 20. Nov., 09:05',
    );
  });

  testWidgets('paused: word, line and only „Beenden"', (tester) async {
    await pump(
      tester,
      testDietitianShare(
        dietitian: testCard(blockedAt: DateTime(2026, 11, 20)),
      ),
    );
    expect(find.text('Pausiert'), findsOneWidget);
    expect(find.text('Aktiv'), findsNothing);
    expect(find.text('Diese Verbindung ist gerade pausiert.'), findsOneWidget);
    expect(find.text('Ändern'), findsNothing);
    expect(find.text('Beenden'), findsOneWidget);
  });

  testWidgets('deleted dietitian: name, „Beendet", no buttons', (tester) async {
    await pump(tester, testDietitianShare(dietitianId: null));
    expect(find.text('Berater:in (Konto gelöscht)'), findsOneWidget);
    expect(find.text('Beendet'), findsOneWidget);
    expect(find.text('Ändern'), findsNothing);
    expect(find.text('Beenden'), findsNothing);
  });

  testWidgets('ended: no buttons, no pause line', (tester) async {
    await pump(tester, testDietitianShare(revokedAt: DateTime(2026, 11, 20)));
    expect(find.text('Beendet'), findsOneWidget);
    expect(find.text('Ändern'), findsNothing);
    expect(find.text('Beenden'), findsNothing);
  });

  testWidgets('the buttons call back', (tester) async {
    var edited = 0, ended = 0;
    await pump(
      tester,
      testDietitianShare(),
      onEdit: () => edited++,
      onEnd: () => ended++,
    );
    await tester.tap(find.text('Ändern'));
    await tester.tap(find.text('Beenden'));
    expect((edited, ended), (1, 1));
  });
}
