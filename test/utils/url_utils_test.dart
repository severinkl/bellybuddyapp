import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:belly_buddy/utils/url_utils.dart';

import '../helpers/fakes.dart';

void main() {
  group('openExternalUrl', () {
    late RecordingUrlOpener opener;

    setUp(() => opener = RecordingUrlOpener());

    /// Pumps a button that opens the page with [open] (in [mode], when
    /// given) and taps it.
    Future<void> tapOpen(
      WidgetTester tester,
      UrlOpener open, {
      LaunchMode? mode,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => mode == null
                    ? openExternalUrl(
                        context,
                        'https://example.com/page',
                        failureMessage: 'Geht nicht.',
                        open: open,
                      )
                    : openExternalUrl(
                        context,
                        'https://example.com/page',
                        failureMessage: 'Geht nicht.',
                        open: open,
                        mode: mode,
                      ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
    }

    testWidgets('opens the URL in an external app, no SnackBar', (
      tester,
    ) async {
      await tapOpen(tester, opener.call);

      expect(opener.urls, [Uri.parse('https://example.com/page')]);
      expect(opener.modes, [LaunchMode.externalApplication]);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('openExternalUrl passes the mode', (tester) async {
      await tapOpen(tester, opener.call, mode: LaunchMode.inAppBrowserView);

      expect(opener.modes, [LaunchMode.inAppBrowserView]);
    });

    testWidgets('a launch that reports false shows the failure message', (
      tester,
    ) async {
      opener.result = false;
      await tapOpen(tester, opener.call);

      expect(find.widgetWithText(SnackBar, 'Geht nicht.'), findsOneWidget);
    });

    testWidgets('completes with whether it opened', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      final context = tester.element(find.byType(Scaffold));
      final failing = RecordingUrlOpener()..result = false;

      expect(
        await openExternalUrl(
          context,
          'https://example.com/page',
          failureMessage: 'Geht nicht.',
          open: opener.call,
        ),
        isTrue,
      );
      expect(
        await openExternalUrl(
          context,
          'https://example.com/page',
          failureMessage: 'Geht nicht.',
          open: failing.call,
        ),
        isFalse,
      );
    });

    testWidgets('a launch that throws shows the failure message', (
      tester,
    ) async {
      await tapOpen(
        tester,
        (url, {mode = LaunchMode.platformDefault}) async =>
            throw Exception('no browser'),
      );

      expect(find.widgetWithText(SnackBar, 'Geht nicht.'), findsOneWidget);
    });
  });
}
