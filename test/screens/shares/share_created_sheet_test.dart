import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/models/data_share.dart';
import 'package:belly_buddy/providers/share_launcher_provider.dart';
import 'package:belly_buddy/screens/shares/widgets/share_created_sheet.dart';

const _link = 'https://example.test/s/abc';
const _secret = ShareSecret(link: _link, code: '482913');

void main() {
  late List<String> shared;
  late List<Rect> origins;
  bool failClipboard = false;
  bool failShare = false;
  String? clipboard;

  Future<void> open(WidgetTester tester, {String? title}) async {
    shared = [];
    origins = [];
    failClipboard = false;
    failShare = false;
    clipboard = null;
    tester.view.physicalSize = const Size(393, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          if (failClipboard) throw PlatformException(code: 'x');
          clipboard = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shareLauncherProvider.overrideWithValue((text, origin) async {
            if (failShare) throw Exception('no share');
            shared.add(text);
            origins.add(origin);
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.theme,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => title == null
                    ? showShareSecretSheet(context, _secret)
                    : showShareSecretSheet(context, _secret, title: title),
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

  testWidgets('shows link and the grouped code, default heading', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Link und Code'), findsOneWidget);
    expect(find.text(_link), findsOneWidget);
    expect(find.text('482 913'), findsOneWidget);
    expect(
      find.text('Sag ihn deiner Berater:in getrennt vom Link.'),
      findsOneWidget,
    );
    final style = tester
        .widget<SelectableText>(find.widgetWithText(SelectableText, '482 913'))
        .style!;
    expect(style.fontSize, AppTheme.fontSizeDisplayLG);
  });

  testWidgets('the created heading', (tester) async {
    await open(tester, title: 'Dein Link ist bereit');
    expect(find.text('Dein Link ist bereit'), findsOneWidget);
  });

  testWidgets('Link senden shares the link without the code', (tester) async {
    await open(tester);
    await tester.tap(find.text('Link senden'));
    await tester.pump();
    expect(shared, ['Hier ist mein Belly Buddy Tagebuch: $_link']);
    expect(shared.single.contains('482'), isFalse);
    // iPad anchors its popover at the button.
    expect(origins.single, isNot(Rect.zero));
    expect(
      origins.single.contains(tester.getCenter(find.text('Link senden'))),
      isTrue,
    );
  });

  testWidgets('a failing share or copy shows the usual text', (tester) async {
    const failed = 'Das hat nicht geklappt. Versuch es später nochmal.';
    await open(tester);
    failShare = true;
    await tester.tap(find.text('Link senden'));
    await tester.pumpAndSettle();
    expect(find.text(failed), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failing clipboard shows the usual text', (tester) async {
    await open(tester);
    failClipboard = true;
    await tester.tap(find.text('Kopieren'));
    await tester.pumpAndSettle();
    expect(
      find.text('Das hat nicht geklappt. Versuch es später nochmal.'),
      findsOneWidget,
    );
    expect(find.text('Kopiert'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the copy button is a live region', (tester) async {
    await open(tester);
    final semantics = tester.widget<Semantics>(find.byKey(shareCopiedLiveKey));
    expect(semantics.properties.liveRegion, isTrue);
  });

  testWidgets('Kopieren copies the link, reads Kopiert for 2 seconds', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Kopieren'));
    await tester.pump();
    expect(clipboard, _link);
    expect(find.text('Kopiert'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1900));
    expect(find.text('Kopiert'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Kopieren'), findsOneWidget);
    expect(find.text('Kopiert'), findsNothing);
  });
}
