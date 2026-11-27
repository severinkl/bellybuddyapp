import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/models/product.dart';
import 'package:belly_buddy/providers/product_finder_provider.dart';
import 'package:belly_buddy/screens/trackers/meal/widgets/product_finder_sheet.dart';
import 'package:belly_buddy/services/product_service.dart';
import 'package:belly_buddy/utils/url_utils.dart';
import 'package:belly_buddy/widgets/scanner/barcode_scanner.dart';

import '../../../../helpers/app_host.dart';

const _code = '4000000000013';

const _product = ProductPrefill(
  barcode: _code,
  title: 'Testjoghurt',
  brand: 'Testmarke',
  ingredients: [
    ProductIngredient(name: 'Milch', ingredientId: 'i-1'),
    ProductIngredient(name: 'Zucker'),
  ],
);

/// Each call waits for the test to complete its answer.
class _FakeProductService implements ProductService {
  final lookups = <String>[];
  final searches = <String>[];
  final lookupAnswers = <Completer<ProductLookup>>[];
  final searchAnswers = <Completer<List<ProductHit>>>[];

  @override
  Future<ProductLookup> lookup(String barcode) {
    lookups.add(barcode);
    final c = Completer<ProductLookup>();
    lookupAnswers.add(c);
    return c.future;
  }

  @override
  Future<List<ProductHit>> search(String query) {
    searches.add(query);
    final c = Completer<List<ProductHit>>();
    searchAnswers.add(c);
    return c.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// No camera: two buttons emit a barcode or report the camera denied.
class _FakeScanner extends StatelessWidget {
  const _FakeScanner({
    required this.active,
    required this.onBarcode,
    required this.onFailure,
  });

  final bool active;
  final ValueChanged<String> onBarcode;
  final ValueChanged<ScannerFailure> onFailure;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.black,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton(
          onPressed: () => onBarcode(_code),
          child: const Text('emit $_code'),
        ),
        ElevatedButton(
          onPressed: () => onFailure(ScannerFailure.permissionDenied),
          child: const Text('deny'),
        ),
      ],
    ),
  );
}

Widget _fakeScanner(
  BuildContext context, {
  required bool active,
  required ValueChanged<String> onBarcode,
  required ValueChanged<ScannerFailure> onFailure,
}) => _FakeScanner(active: active, onBarcode: onBarcode, onFailure: onFailure);

class _Harness {
  final service = _FakeProductService();
  final opened = <Uri>[];
  ProductPrefill? result;
  bool closed = false;

  /// What [open] answers.
  bool openResult = true;

  Future<bool> open(Uri url, {LaunchMode mode = LaunchMode.platformDefault}) {
    opened.add(url);
    return Future.value(openResult);
  }

  Future<void> pump(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1170, 2532)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productServiceProvider.overrideWithValue(service),
          barcodeScannerProvider.overrideWithValue(_fakeScanner),
        ],
        child: MaterialApp(
          theme: AppTheme.theme,
          localizationsDelegates: germanLocalizations,
          supportedLocales: const [germanLocale],
          locale: germanLocale,
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  result = await showProductFinderSheet(ctx, openUrl: open);
                  closed = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }
}

bool _scannerActive(WidgetTester tester) => tester
    .widgetList<_FakeScanner>(find.byType(_FakeScanner))
    .any((s) => s.active);

Future<void> _scan(WidgetTester tester) async {
  await tester.tap(find.text('emit $_code'));
  await tester.pump();
}

Future<void> _answer(
  WidgetTester tester,
  Completer<ProductLookup> c,
  ProductLookup answer,
) async {
  c.complete(answer);
  await tester.pumpAndSettle();
}

/// Scans [_code] and has the lookup answer [answer].
Future<void> _scanAndAnswer(
  WidgetTester tester,
  _Harness h,
  ProductLookup answer,
) async {
  await _scan(tester);
  await _answer(tester, h.service.lookupAnswers.single, answer);
}

Future<void> _submitSearch(WidgetTester tester, String q) async {
  await tester.enterText(find.byKey(ProductFinderSheet.searchFieldKey), q);
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await tester.pump();
}

Future<void> _meetsGuidelines(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
}

void main() {
  testWidgets('scanned barcode → spinner → card with name, brand, chips and '
      'attribution', (tester) async {
    final h = _Harness();
    await h.pump(tester);
    expect(find.text('Produkt finden'), findsOneWidget);
    expect(find.text('Halte den Barcode in den Rahmen'), findsOneWidget);
    expect(_scannerActive(tester), isTrue);

    await _scan(tester);
    expect(find.text('Suche Produkt …'), findsOneWidget);
    expect(h.service.lookups, [_code]);

    await _answer(
      tester,
      h.service.lookupAnswers.single,
      ProductFound(_product),
    );
    expect(find.text('Testjoghurt'), findsOneWidget);
    expect(find.text('Testmarke'), findsOneWidget);
    expect(find.text('Milch'), findsOneWidget);
    expect(find.text('Zucker'), findsOneWidget);
    expect(find.text('Produktdaten: Open Food Facts (ODbL)'), findsOneWidget);
    expect(find.byKey(ProductFinderSheet.attributionKey), findsOneWidget);
  });

  testWidgets('Übernehmen pops the ProductPrefill', (tester) async {
    final h = _Harness();
    await h.pump(tester);
    await _scanAndAnswer(tester, h, ProductFound(_product));

    await tester.tap(find.byKey(ProductFinderSheet.applyKey));
    await tester.pumpAndSettle();
    expect(h.closed, isTrue);
    expect(h.result, same(_product));
  });

  testWidgets('Anderes Produkt goes back to scanner and search', (
    tester,
  ) async {
    final h = _Harness();
    await h.pump(tester);
    await _scanAndAnswer(tester, h, ProductFound(_product));

    await tester.tap(find.byKey(ProductFinderSheet.otherProductKey));
    await tester.pumpAndSettle();
    expect(find.text('Halte den Barcode in den Rahmen'), findsOneWidget);
    expect(find.byKey(ProductFinderSheet.searchFieldKey), findsOneWidget);
    expect(_scannerActive(tester), isTrue);
  });

  testWidgets('a second detection during the lookup is ignored', (
    tester,
  ) async {
    final h = _Harness();
    await h.pump(tester);
    final scanner = tester.widget<_FakeScanner>(find.byType(_FakeScanner));
    scanner.onBarcode(_code);
    scanner.onBarcode('4000000000020');
    await tester.pump();
    expect(h.service.lookups, [_code]);
  });

  testWidgets('search runs on submit only, not while typing', (tester) async {
    final h = _Harness();
    await h.pump(tester);
    await tester.enterText(
      find.byKey(ProductFinderSheet.searchFieldKey),
      'Joghurt',
    );
    await tester.pump();
    expect(h.service.searches, isEmpty);

    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    expect(h.service.searches, ['Joghurt']);
    expect(find.text('Suche Produkt …'), findsOneWidget);
  });

  testWidgets('search results list name and brand; tap looks up that barcode', (
    tester,
  ) async {
    final h = _Harness();
    await h.pump(tester);
    expect(find.text('Produkt oder Marke suchen'), findsOneWidget);
    await _submitSearch(tester, 'Joghurt');
    h.service.searchAnswers.single.complete(const [
      ProductHit(barcode: '4000000000020', name: 'Joghurt Natur', brand: 'Hof'),
      ProductHit(barcode: '4000000000037', name: 'Joghurt Erdbeere'),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('Joghurt Natur'), findsOneWidget);
    expect(find.text('Hof'), findsOneWidget);
    expect(find.text('Joghurt Erdbeere'), findsOneWidget);

    await tester.tap(find.text('Joghurt Erdbeere'));
    await tester.pump();
    expect(h.service.lookups, ['4000000000037']);
  });

  testWidgets('no results: the German empty text', (tester) async {
    final h = _Harness();
    await h.pump(tester);
    await _submitSearch(tester, 'Xyz');
    h.service.searchAnswers.single.complete(const []);
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Keine Produkte gefunden. Versuch einen anderen Namen oder trag die '
        'Mahlzeit selbst ein.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('not found: texts, Selbst eintragen pops null, the link opens '
      'offAddProductUrl(barcode)', (tester) async {
    final h = _Harness();
    await h.pump(tester);
    await _scanAndAnswer(tester, h, ProductNotFound(_code));

    expect(find.text('Dieses Produkt kennen wir noch nicht.'), findsOneWidget);
    expect(
      find.text('Du kannst die Mahlzeit einfach selbst eintragen.'),
      findsOneWidget,
    );
    expect(find.text('Nochmal scannen'), findsOneWidget);

    await tester.tap(find.byKey(ProductFinderSheet.offAddLinkKey));
    await tester.pump();
    expect(h.opened, [Uri.parse(AppConstants.offAddProductUrl(_code))]);
    expect(
      AppConstants.offAddProductUrl(_code),
      'https://world.openfoodfacts.org/cgi/product.pl'
      '?type=search_or_add&action=display&code=$_code',
    );

    await tester.tap(find.byKey(ProductFinderSheet.typeItKey));
    await tester.pumpAndSettle();
    expect(h.closed, isTrue);
    expect(h.result, isNull);
  });

  testWidgets('product without ingredients: the hint text, Übernehmen still '
      'enabled', (tester) async {
    final h = _Harness();
    await h.pump(tester);
    await _scanAndAnswer(
      tester,
      h,
      ProductFound(
        const ProductPrefill(barcode: _code, title: 'Wasser', ingredients: []),
      ),
    );

    expect(
      find.text(
        'Für dieses Produkt sind keine Zutaten hinterlegt. Du kannst sie '
        'gleich selbst eintragen.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(ProductFinderSheet.applyKey));
    await tester.pumpAndSettle();
    expect(h.result?.title, 'Wasser');
  });

  testWidgets('camera denied: explanation, Einstellungen öffnen opens '
      'app-settings:, search still works', (tester) async {
    final h = _Harness();
    await h.pump(tester);
    await tester.tap(find.text('deny'));
    await tester.pumpAndSettle();

    expect(find.text('Kein Zugriff auf die Kamera'), findsOneWidget);
    expect(
      find.text(
        'Erlaube Belly Buddy in den Einstellungen den Zugriff auf die Kamera, '
        'um Barcodes zu scannen. Du kannst das Produkt auch unten suchen.',
      ),
      findsOneWidget,
    );
    expect(find.byType(_FakeScanner), findsNothing);

    await tester.tap(find.text('Einstellungen öffnen'));
    await tester.pump();
    expect(h.opened, [Uri.parse('app-settings:')]);

    await _submitSearch(tester, 'Joghurt');
    expect(h.service.searches, ['Joghurt']);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('ProductException with core text shows that text; without '
      'text the fallback; Nochmal versuchen repeats the call', (tester) async {
    final h = _Harness();
    await h.pump(tester);
    await _scan(tester);
    h.service.lookupAnswers.single.completeError(
      const ProductException(status: 503, message: 'Open Food Facts ruht.'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Open Food Facts ruht.'), findsOneWidget);

    await tester.tap(find.byKey(ProductFinderSheet.retryKey));
    await tester.pump();
    expect(h.service.lookups, [_code, _code]);
    h.service.lookupAnswers.last.completeError(const ProductException());
    await tester.pumpAndSettle();
    expect(
      find.text('Das hat gerade nicht geklappt. Versuch es bitte nochmal.'),
      findsOneWidget,
    );
    expect(find.text('Nochmal versuchen'), findsOneWidget);
  });

  testWidgets('scanner inactive while the search field has focus and while a '
      'card is shown', (tester) async {
    final h = _Harness();
    await h.pump(tester);
    expect(_scannerActive(tester), isTrue);

    await tester.tap(find.byKey(ProductFinderSheet.searchFieldKey));
    await tester.pump();
    expect(_scannerActive(tester), isFalse);

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    expect(_scannerActive(tester), isTrue);

    await _scan(tester);
    expect(_scannerActive(tester), isFalse);
    await _answer(
      tester,
      h.service.lookupAnswers.single,
      ProductFound(_product),
    );
    expect(_scannerActive(tester), isFalse);
    expect(find.byType(_FakeScanner), findsNothing);
  });

  testWidgets('a failed search keeps the field with the query; a failed '
      'lookup does not', (tester) async {
    final h = _Harness();
    await h.pump(tester);
    await _submitSearch(tester, 'Joghurt');
    h.service.searchAnswers.single.completeError(const ProductException());
    await tester.pumpAndSettle();
    expect(find.text(productFinderFallbackError), findsOneWidget);
    expect(find.byKey(ProductFinderSheet.retryKey), findsOneWidget);
    expect(find.byKey(ProductFinderSheet.rescanKey), findsOneWidget);
    final field = tester.widget<TextField>(
      find.byKey(ProductFinderSheet.searchFieldKey),
    );
    expect(field.controller!.text, 'Joghurt');

    // A changed term searches again from here.
    await _submitSearch(tester, 'Käse');
    expect(h.service.searches, ['Joghurt', 'Käse']);

    await tester.tap(find.byKey(ProductFinderSheet.rescanKey));
    await tester.pumpAndSettle();
    await _scan(tester);
    h.service.lookupAnswers.single.completeError(const ProductException());
    await tester.pumpAndSettle();
    expect(find.byKey(ProductFinderSheet.searchFieldKey), findsNothing);
    expect(find.byKey(ProductFinderSheet.retryKey), findsOneWidget);
  });

  testWidgets('clearing the field while a search runs drops its results', (
    tester,
  ) async {
    final h = _Harness();
    await h.pump(tester);
    await _submitSearch(tester, 'Joghurt');
    await tester.tap(find.byTooltip('Suche löschen'));
    await tester.pump();
    expect(find.text('Halte den Barcode in den Rahmen'), findsOneWidget);

    h.service.searchAnswers.single.complete(const [
      ProductHit(barcode: '4000000000020', name: 'Joghurt Natur'),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Joghurt Natur'), findsNothing);
    expect(_scannerActive(tester), isTrue);
  });

  testWidgets('scanner inactive while the app is in the background', (
    tester,
  ) async {
    final h = _Harness();
    await h.pump(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(_scannerActive(tester), isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(_scannerActive(tester), isTrue);
  });

  testWidgets('attribution opens offProductUrl(barcode)', (tester) async {
    final h = _Harness();
    await h.pump(tester);
    await _scanAndAnswer(tester, h, ProductFound(_product));

    await tester.tap(find.byKey(ProductFinderSheet.attributionKey));
    await tester.pump();
    expect(h.opened, [
      Uri.parse('https://world.openfoodfacts.org/product/$_code'),
    ]);
    expect(
      AppConstants.offProductUrl(_code),
      'https://world.openfoodfacts.org/product/$_code',
    );
  });

  testWidgets('camera denied: coming back from the permission dialog keeps '
      'the explanation and does not start the camera again', (tester) async {
    final h = _Harness();
    await h.pump(tester);
    // The permission dialog sends the app to the background and back.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    await tester.tap(find.text('deny'), warnIfMissed: false);
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Kein Zugriff auf die Kamera'), findsOneWidget);
    expect(find.byType(_FakeScanner), findsNothing);

    // Any later trip to the background and back: the same.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Kein Zugriff auf die Kamera'), findsOneWidget);
    expect(find.byType(_FakeScanner), findsNothing);
  });

  testWidgets('camera denied: back from Einstellungen öffnen the scanner runs '
      'again', (tester) async {
    final h = _Harness();
    await h.pump(tester);
    await tester.tap(find.text('deny'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Einstellungen öffnen'));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.text('Kein Zugriff auf die Kamera'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Kein Zugriff auf die Kamera'), findsNothing);
    expect(_scannerActive(tester), isTrue);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('camera denied: Einstellungen öffnen on Android opens the app '
      'details page', (tester) async {
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      appSettingsChannel,
      (call) async {
        calls.add(call.method);
        return true;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        appSettingsChannel,
        null,
      ),
    );
    final h = _Harness();
    await h.pump(tester);
    await tester.tap(find.text('deny'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Einstellungen öffnen'));
    await tester.pumpAndSettle();
    expect(calls, ['openAppSettings']);
    expect(h.opened, isEmpty);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('camera denied: a settings page that did not open keeps the '
      'explanation on the way back', (tester) async {
    final h = _Harness()..openResult = false;
    await h.pump(tester);
    await tester.tap(find.text('deny'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Einstellungen öffnen'));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Kein Zugriff auf die Kamera'), findsOneWidget);
    expect(find.byType(_FakeScanner), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  Future<void> searchAndPick(WidgetTester tester, _Harness h) async {
    await _submitSearch(tester, 'Joghurt');
    h.service.searchAnswers.single.complete(const [
      ProductHit(barcode: '4000000000020', name: 'Joghurt Natur'),
      ProductHit(barcode: _code, name: 'Testjoghurt'),
    ]);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Testjoghurt'));
    await tester.pump();
  }

  String fieldText(WidgetTester tester) => tester
      .widget<TextField>(find.byKey(ProductFinderSheet.searchFieldKey))
      .controller!
      .text;

  testWidgets('Anderes Produkt after a search hit goes back to the hits with '
      'the term in the field', (tester) async {
    final h = _Harness();
    await h.pump(tester);
    await searchAndPick(tester, h);
    await _answer(
      tester,
      h.service.lookupAnswers.single,
      ProductFound(_product),
    );

    await tester.tap(find.byKey(ProductFinderSheet.otherProductKey));
    await tester.pumpAndSettle();
    expect(find.text('Joghurt Natur'), findsOneWidget);
    expect(find.text('Testjoghurt'), findsOneWidget);
    expect(fieldText(tester), 'Joghurt');
    expect(h.service.searches, ['Joghurt']);
  });

  testWidgets('not found and a failed lookup after a search hit offer '
      'Zurück zur Suche', (tester) async {
    final h = _Harness();
    await h.pump(tester);
    await searchAndPick(tester, h);
    await _answer(
      tester,
      h.service.lookupAnswers.single,
      ProductNotFound(_code),
    );
    expect(find.text('Nochmal scannen'), findsNothing);
    await tester.tap(find.text('Zurück zur Suche'));
    await tester.pumpAndSettle();
    expect(find.text('Joghurt Natur'), findsOneWidget);
    expect(fieldText(tester), 'Joghurt');

    await tester.tap(find.text('Testjoghurt'));
    await tester.pump();
    h.service.lookupAnswers.last.completeError(const ProductException());
    await tester.pumpAndSettle();
    expect(find.byKey(ProductFinderSheet.retryKey), findsOneWidget);
    await tester.tap(find.text('Zurück zur Suche'));
    await tester.pumpAndSettle();
    expect(find.text('Joghurt Natur'), findsOneWidget);
    expect(fieldText(tester), 'Joghurt');
  });

  testWidgets('Nochmal scannen from the hits goes to the camera and keeps '
      'the field text', (tester) async {
    final h = _Harness();
    await h.pump(tester);
    await _submitSearch(tester, 'Joghurt');
    h.service.searchAnswers.single.complete(const [
      ProductHit(barcode: '4000000000020', name: 'Joghurt Natur'),
    ]);
    await tester.pumpAndSettle();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.tap(find.byKey(ProductFinderSheet.rescanKey));
    await tester.pumpAndSettle();
    expect(_scannerActive(tester), isTrue);
    expect(find.text('Joghurt Natur'), findsNothing);
    expect(fieldText(tester), 'Joghurt');
  });

  testWidgets('Nochmal versuchen after a failed search searches the edited '
      'term', (tester) async {
    final h = _Harness();
    await h.pump(tester);
    await _submitSearch(tester, 'Joghurt');
    h.service.searchAnswers.single.completeError(const ProductException());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(ProductFinderSheet.searchFieldKey),
      'Käse',
    );
    await tester.pump();
    await tester.tap(find.byKey(ProductFinderSheet.retryKey));
    await tester.pump();
    expect(h.service.searches, ['Joghurt', 'Käse']);
  });

  testWidgets('a barcode rejected with 400 offers Nochmal scannen only', (
    tester,
  ) async {
    final h = _Harness();
    await h.pump(tester);
    await _scan(tester);
    h.service.lookupAnswers.single.completeError(
      const ProductException(status: 400, message: 'Ungültiger Barcode.'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ungültiger Barcode.'), findsOneWidget);
    expect(find.byKey(ProductFinderSheet.retryKey), findsNothing);
    expect(find.text('Nochmal versuchen'), findsNothing);
    await tester.tap(find.byKey(ProductFinderSheet.rescanKey));
    await tester.pumpAndSettle();
    expect(_scannerActive(tester), isTrue);
  });

  group('accessibility guidelines', () {
    testWidgets('scanning', (tester) async {
      final handle = tester.ensureSemantics();
      await _Harness().pump(tester);
      await _meetsGuidelines(tester);
      handle.dispose();
    });

    testWidgets('camera denied', (tester) async {
      final handle = tester.ensureSemantics();
      await _Harness().pump(tester);
      await tester.tap(find.text('deny'));
      await tester.pumpAndSettle();
      await _meetsGuidelines(tester);
      handle.dispose();
    });

    testWidgets('search results', (tester) async {
      final handle = tester.ensureSemantics();
      final h = _Harness();
      await h.pump(tester);
      await _submitSearch(tester, 'Joghurt');
      h.service.searchAnswers.single.complete(const [
        ProductHit(barcode: '4000000000020', name: 'Joghurt', brand: 'Hof'),
      ]);
      await tester.pumpAndSettle();
      await _meetsGuidelines(tester);
      handle.dispose();
    });

    testWidgets('found card', (tester) async {
      final handle = tester.ensureSemantics();
      final h = _Harness();
      await h.pump(tester);
      await _scanAndAnswer(tester, h, ProductFound(_product));
      await _meetsGuidelines(tester);
      handle.dispose();
    });

    testWidgets('not found', (tester) async {
      final handle = tester.ensureSemantics();
      final h = _Harness();
      await h.pump(tester);
      await _scanAndAnswer(tester, h, ProductNotFound(_code));
      await _meetsGuidelines(tester);
      handle.dispose();
    });

    testWidgets('failed search', (tester) async {
      final handle = tester.ensureSemantics();
      final h = _Harness();
      await h.pump(tester);
      await _submitSearch(tester, 'Joghurt');
      h.service.searchAnswers.single.completeError(const ProductException());
      await tester.pumpAndSettle();
      expect(find.byKey(ProductFinderSheet.retryKey), findsOneWidget);
      await _meetsGuidelines(tester);
      handle.dispose();
    });

    testWidgets('error', (tester) async {
      final handle = tester.ensureSemantics();
      final h = _Harness();
      await h.pump(tester);
      await _scan(tester);
      h.service.lookupAnswers.single.completeError(const ProductException());
      await tester.pumpAndSettle();
      await _meetsGuidelines(tester);
      handle.dispose();
    });
  });
}
