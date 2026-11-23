import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/models/knowledge_article.dart';
import 'package:belly_buddy/providers/knowledge_provider.dart';
import 'package:belly_buddy/repositories/knowledge_repository.dart';
import 'package:belly_buddy/router/route_names.dart';
import 'package:belly_buddy/screens/discover/knowledge_screen.dart';
import 'package:belly_buddy/screens/discover/widgets/knowledge_article_tile.dart';

import '../../helpers/app_host.dart';
import '../../helpers/fakes.dart';
import '../../helpers/fixtures.dart';

class _Launches {
  final urls = <Uri>[];
  final modes = <LaunchMode>[];
  bool result = true;

  Future<bool> call(Uri url, {LaunchMode mode = LaunchMode.platformDefault}) {
    urls.add(url);
    modes.add(mode);
    return Future.value(result);
  }
}

void main() {
  late _Launches launches;
  late FakeKnowledgeRepository repo;
  late ProviderContainer container;

  setUp(() {
    launches = _Launches();
    repo = FakeKnowledgeRepository();
  });

  Future<void> pump(
    WidgetTester tester, {
    double textScale = 1,
    bool settle = true,
  }) async {
    final router = GoRouter(
      initialLocation: RoutePaths.knowledge,
      routes: [
        GoRoute(
          path: RoutePaths.knowledge,
          builder: (_, _) => KnowledgeScreen(openUrl: launches.call),
        ),
      ],
    );
    addTearDown(router.dispose);
    container = ProviderContainer.test(
      overrides: [knowledgeRepositoryProvider.overrideWithValue(repo)],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: germanRouterApp(router, textScale: textScale),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump();
    }
  }

  Finder tile(KnowledgeArticle a) => find.byKey(KnowledgeArticleTile.keyFor(a));

  Finder chip(String? category) =>
      find.byKey(KnowledgeScreen.chipKey(category));

  testWidgets('shows Alle and the feed\'s categories in order', (tester) async {
    await pump(tester);

    expect(find.text('Wissen'), findsOneWidget);
    expect(find.text('Artikel aus dem myfodmap-Blog'), findsOneWidget);
    final xs = [
      for (final c in [null, 'Gesund verdauen', 'Rezepte', 'Persönliches'])
        tester.getCenter(chip(c)).dx,
    ];
    expect(xs, orderedEquals([...xs]..sort()));
    expect(xs.toSet(), hasLength(4));
    expect(
      find.descendant(of: chip(null), matching: find.text('Alle')),
      findsOneWidget,
    );
    expect(find.text('Gerade offline', findRichText: true), findsNothing);
  });

  testWidgets('a category shows only its articles; Alle shows all again', (
    tester,
  ) async {
    await pump(tester);
    final articles = testKnowledgeArticles();

    await tester.tap(chip('Gesund verdauen'));
    await tester.pumpAndSettle();
    expect(tile(articles[0]), findsOneWidget);
    expect(tile(articles[3]), findsOneWidget);
    expect(tile(articles[1]), findsNothing);
    expect(tile(articles[2]), findsNothing);

    await tester.tap(chip(null));
    await tester.pumpAndSettle();
    for (final a in articles) {
      expect(tile(a), findsOneWidget);
    }
  });

  testWidgets('an article opens in the in-app browser', (tester) async {
    await pump(tester);
    final article = testKnowledgeArticles()[1];

    await tester.tap(tile(article));
    await tester.pumpAndSettle();

    expect(launches.urls, [article.link]);
    expect(launches.modes, [LaunchMode.inAppBrowserView]);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a failed launch says so', (tester) async {
    launches.result = false;
    await pump(tester);

    await tester.tap(tile(testKnowledgeArticles()[0]));
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(
        SnackBar,
        'Der Artikel konnte nicht geöffnet werden.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('meta line: category and date; undated shows the category', (
    tester,
  ) async {
    repo = FakeKnowledgeRepository(
      articles: [
        KnowledgeArticle(
          title: 'Mit Datum',
          link: Uri.parse('https://www.myfodmap.at/a'),
          category: 'Rezepte',
          publishedAt: DateTime.utc(2025, 3, 13, 12),
        ),
        KnowledgeArticle(
          title: 'Ohne Datum',
          link: Uri.parse('https://www.myfodmap.at/b'),
          category: 'Persönliches',
        ),
      ],
    );
    await pump(tester);

    expect(find.text('Rezepte · 13. Mär 2025'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(KnowledgeArticleTile.keyFor(repo.articles[1])),
        matching: find.text('Persönliches'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('error without a copy offers a retry', (tester) async {
    repo.fetchError = Exception('down');
    await pump(tester);

    expect(
      find.text('Die Artikel konnten nicht geladen werden.'),
      findsOneWidget,
    );
    expect(find.text('Nochmal versuchen'), findsOneWidget);

    repo.fetchError = null;
    await tester.tap(find.text('Nochmal versuchen'));
    await tester.pumpAndSettle();

    expect(find.text('Nochmal versuchen'), findsNothing);
    expect(tile(testKnowledgeArticles()[0]), findsOneWidget);
  });

  testWidgets('offline copy shows the line and the cached titles', (
    tester,
  ) async {
    repo.cache = KnowledgeFeed(
      articles: testKnowledgeArticles(),
      fetchedAt: DateTime.now().subtract(const Duration(days: 2)),
    );
    repo.fetchError = Exception('down');
    await pump(tester);

    expect(
      find.text('Gerade offline – du siehst den zuletzt geladenen Stand.'),
      findsOneWidget,
    );
    expect(find.text('Was ist FODMAP?'), findsOneWidget);
  });

  testWidgets('no articles', (tester) async {
    repo = FakeKnowledgeRepository(articles: const []);
    await pump(tester);

    expect(find.text('Gerade keine Artikel.'), findsOneWidget);
    expect(find.byType(FilterChip), findsOneWidget);
    expect(chip(null), findsOneWidget);
  });

  testWidgets('a picked category gone after a refresh falls back to Alle', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(chip('Persönliches'));
    await tester.pumpAndSettle();
    expect(tile(testKnowledgeArticles()[2]), findsOneWidget);
    expect(tile(testKnowledgeArticles()[0]), findsNothing);

    repo.articles
      ..clear()
      ..addAll(
        testKnowledgeArticles().where((a) => a.category != 'Persönliches'),
      );
    await container.read(knowledgeFeedProvider.notifier).refresh();
    await tester.pumpAndSettle();

    expect(chip('Persönliches'), findsNothing);
    expect(tile(testKnowledgeArticles()[0]), findsOneWidget);
    expect(tile(testKnowledgeArticles()[1]), findsOneWidget);
  });

  testWidgets('images load cached, with a shimmer', (tester) async {
    repo = FakeKnowledgeRepository(
      articles: [
        KnowledgeArticle(
          title: 'Mit Bild',
          link: Uri.parse('https://www.myfodmap.at/bild'),
          category: 'Rezepte',
          imageUrl: 'https://static.wixstatic.com/media/x.jpg',
        ),
      ],
    );
    await pump(tester, settle: false);

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(image.imageUrl, 'https://static.wixstatic.com/media/x.jpg');
    final context = tester.element(find.byType(CachedNetworkImage));
    expect(image.placeholder!(context, image.imageUrl), isA<Shimmer>());
    // Decoded as tall as the box (the landscape images' short side), so
    // BoxFit.cover fills it without upscaling.
    final dpr = tester.view.devicePixelRatio;
    expect(
      image.memCacheHeight,
      (AppConstants.knowledgeThumbSize * dpr).round(),
    );
    expect(image.memCacheWidth, isNull);
  });

  testWidgets('fits 375x667 at text scale 1.3', (tester) async {
    tester.view
      ..physicalSize = const Size(375, 667)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    repo = FakeKnowledgeRepository(
      articles: [
        KnowledgeArticle(
          title: List.filled(35, 'Wort').join(' ').substring(0, 140),
          link: Uri.parse('https://www.myfodmap.at/lang'),
          category: 'Gesund verdauen',
          publishedAt: DateTime.utc(2025, 3, 13, 12),
        ),
        ...testKnowledgeArticles(),
      ],
    );
    await pump(tester, textScale: 1.3);

    expect(tester.takeException(), isNull);
  });
}
