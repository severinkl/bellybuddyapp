import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:belly_buddy/utils/url_utils.dart';

void main() {
  group('openExternalUrl', () {
    late List<Uri> urls;
    late List<LaunchMode> modes;

    setUp(() {
      urls = [];
      modes = [];
    });

    /// Pumps a button that opens [url] with [open] and taps it.
    Future<void> tapOpen(WidgetTester tester, UrlOpener open) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => openExternalUrl(
                  context,
                  'https://example.com/page',
                  failureMessage: 'Geht nicht.',
                  open: open,
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
      await tapOpen(tester, (url, {mode = LaunchMode.platformDefault}) async {
        urls.add(url);
        modes.add(mode);
        return true;
      });

      expect(urls, [Uri.parse('https://example.com/page')]);
      expect(modes, [LaunchMode.externalApplication]);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('openExternalUrl passes the mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => openExternalUrl(
                  context,
                  'https://example.com/page',
                  failureMessage: 'Geht nicht.',
                  mode: LaunchMode.inAppBrowserView,
                  open: (url, {mode = LaunchMode.platformDefault}) async {
                    modes.add(mode);
                    return true;
                  },
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      expect(modes, [LaunchMode.inAppBrowserView]);
    });

    testWidgets('a launch that reports false shows the failure message', (
      tester,
    ) async {
      await tapOpen(
        tester,
        (url, {mode = LaunchMode.platformDefault}) async => false,
      );

      expect(find.widgetWithText(SnackBar, 'Geht nicht.'), findsOneWidget);
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
