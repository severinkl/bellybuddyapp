import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/providers/share_launcher_provider.dart';
import 'package:belly_buddy/screens/shares/widgets/share_created_sheet.dart';

const _link = 'https://example.test/s/abc';

void main() {
  late List<String> shared;
  String? clipboard;

  Future<void> open(WidgetTester tester, {String? title}) async {
    shared = [];
    clipboard = null;
    tester.view.physicalSize = const Size(393, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
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
          shareLauncherProvider.overrideWithValue((text) async {
            shared.add(text);
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.theme,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => title == null
                    ? showShareSecretSheet(context, link: _link, code: '482913')
                    : showShareSecretSheet(
                        context,
                        link: _link,
                        code: '482913',
                        title: title,
                      ),
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
