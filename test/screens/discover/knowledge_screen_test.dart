import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shimmer/shimmer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/models/knowledge_article.dart';
import 'package:belly_buddy/providers/auth_provider.dart';
import 'package:belly_buddy/providers/knowledge_opened_provider.dart';
import 'package:belly_buddy/providers/knowledge_provider.dart';
import 'package:belly_buddy/providers/buddy_provider.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';
import 'package:belly_buddy/repositories/knowledge_repository.dart';
import 'package:belly_buddy/router/route_names.dart';
import 'package:belly_buddy/screens/discover/knowledge_screen.dart';
import 'package:belly_buddy/screens/discover/widgets/knowledge_article_tile.dart';

import '../../helpers/app_host.dart';
import '../../helpers/fakes.dart';
import '../../helpers/fixtures.dart';
import '../../helpers/riverpod_helpers.dart';

void main() {
  late RecordingUrlOpener launches;
  late FakeKnowledgeRepository repo;
  late ProviderContainer container;

  setUp(() {
    launches = RecordingUrlOpener();
    repo = FakeKnowledgeRepository();
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pump(
    WidgetTester tester, {
    double textScale = 1,
    bool settle = true,
    // Seeds a signed-in user's profile with these (the „Für dich" source).
    List<String>? intolerances,
    List<Override> overrides = const [],
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
      overrides: [
        knowledgeRepositoryProvider.overrideWithValue(repo),
        currentUserIdProvider.overrideWithValue(testUserId),
        entryRepositoryProvider.overrideWithValue(FakeEntryRepository()),
        // No Buddy: the picks reads the progress, which asks for it.
        buddyProvider.overrideWith(() => FakeBuddyNotifier(() => null)),
        if (intolerances != null)
          profileProviderSeededWith(
            testUserProfile(intolerances: intolerances),
          ),
        ...overrides,
      ],
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

  group('Für dich', () {
    final laktose = KnowledgeArticle(
      title: 'Laktose im Alltag',
      link: Uri.parse('https://www.myfodmap.at/laktose'),
      category: 'Gesund verdauen',
      publishedAt: DateTime.utc(2026, 9, 1, 8),
    );

    /// The tiles' titles, top to bottom.
    List<String> titles(WidgetTester tester) => [
      for (final t in tester.widgetList<KnowledgeArticleTile>(
        find.byType(KnowledgeArticleTile),
      ))
        t.article.title,
    ];

    double top(WidgetTester tester, Finder f) => tester.getTopLeft(f).dy;

    testWidgets('Für dich block above the list under Alle, picks not '
        'repeated in Alle Artikel', (tester) async {
      repo = FakeKnowledgeRepository(
        articles: [...testKnowledgeArticles(), laktose],
      );
      await pump(tester, intolerances: const ['Laktose']);

      final forYou = find.text(KnowledgeScreen.forYouTitle);
      final caption = find.text(KnowledgeScreen.forYouCaption);
      final all = find.text(KnowledgeScreen.allArticlesTitle);
      expect(KnowledgeScreen.forYouTitle, 'Für dich');
      expect(
        KnowledgeScreen.forYouCaption,
        'Ausgewählt nach deinen Einträgen und Angaben.',
      );
      expect(KnowledgeScreen.allArticlesTitle, 'Alle Artikel');
      expect(forYou, findsOneWidget);
      expect(caption, findsOneWidget);
      expect(all, findsOneWidget);
      expect(find.text('Weil du Laktose angegeben hast'), findsOneWidget);
      expect(titles(tester), [
        'Laktose im Alltag',
        for (final a in testKnowledgeArticles()) a.title,
      ]);
      final pick = tile(laktose);
      expect(top(tester, chip(null)), lessThan(top(tester, forYou)));
      expect(top(tester, forYou), lessThan(top(tester, caption)));
      expect(top(tester, caption), lessThan(top(tester, pick)));
      expect(top(tester, pick), lessThan(top(tester, all)));
      expect(
        top(tester, all),
        lessThan(top(tester, tile(testKnowledgeArticles()[0]))),
      );
    });

    testWidgets('every article a pick: no Alle Artikel, no empty line', (
      tester,
    ) async {
      repo = FakeKnowledgeRepository(articles: [laktose]);
      await pump(tester, intolerances: const ['Laktose']);

      expect(find.text(KnowledgeScreen.forYouTitle), findsOneWidget);
      expect(titles(tester), ['Laktose im Alltag']);
      expect(find.text(KnowledgeScreen.allArticlesTitle), findsNothing);
      expect(find.text('Gerade keine Artikel.'), findsNothing);
    });

    testWidgets('another chip hides Für dich', (tester) async {
      repo = FakeKnowledgeRepository(
        articles: [...testKnowledgeArticles(), laktose],
      );
      await pump(tester, intolerances: const ['Laktose']);

      await tester.tap(chip('Gesund verdauen'));
      await tester.pumpAndSettle();

      expect(find.text(KnowledgeScreen.forYouTitle), findsNothing);
      expect(find.text(KnowledgeScreen.forYouCaption), findsNothing);
      expect(find.text(KnowledgeScreen.allArticlesTitle), findsNothing);
      expect(find.text('Weil du Laktose angegeben hast'), findsNothing);
      expect(titles(tester), [
        'Was ist FODMAP?',
        'Ballaststoffe verstehen',
        'Laktose im Alltag',
      ]);
      expect(find.text('Gesund verdauen · 1. Sep 2026'), findsOneWidget);
    });

    testWidgets('no pick: no Für dich, the list as before', (tester) async {
      await pump(tester, intolerances: const ['Laktose']);

      expect(find.text(KnowledgeScreen.forYouTitle), findsNothing);
      expect(find.text(KnowledgeScreen.allArticlesTitle), findsNothing);
      expect(titles(tester), [
        for (final a in testKnowledgeArticles()) a.title,
      ]);
    });

    testWidgets('tapping a pick marks it opened and opens it; it leaves '
        'Für dich', (tester) async {
      repo = FakeKnowledgeRepository(
        articles: [...testKnowledgeArticles(), laktose],
      );
      await pump(tester, intolerances: const ['Laktose']);

      await tester.tap(tile(laktose));
      await tester.pumpAndSettle();

      expect(launches.urls, [laktose.link]);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('knowledge_opened_$testUserId'), [
        laktose.link.toString(),
      ]);
      expect(find.text(KnowledgeScreen.forYouTitle), findsNothing);
      expect(find.text('Weil du Laktose angegeben hast'), findsNothing);
      expect(titles(tester), [
        for (final a in testKnowledgeArticles()) a.title,
        'Laktose im Alltag',
      ]);
    });

    testWidgets('a pick opens without waiting for the opened write', (
      tester,
    ) async {
      repo = FakeKnowledgeRepository(
        articles: [...testKnowledgeArticles(), laktose],
      );
      final write = Completer<void>();
      await pump(
        tester,
        intolerances: const ['Laktose'],
        overrides: [
          knowledgeOpenedProvider.overrideWith(() => _SlowWrite(write.future)),
        ],
      );

      await tester.tap(tile(laktose));
      await tester.pump();

      expect(launches.urls, [laktose.link]);
      write.complete();
      await tester.pumpAndSettle();
    });
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
    expect(
      image.placeholder!(context, image.imageUrl),
      isA<Shimmer>().having((s) => s.enabled, 'enabled', isTrue),
    );
    // Decoded as tall as the box (the landscape images' short side), so
    // BoxFit.cover fills it without upscaling.
    final dpr = tester.view.devicePixelRatio;
    expect(
      image.memCacheHeight,
      (AppConstants.knowledgeThumbSize * dpr).round(),
    );
    expect(image.memCacheWidth, isNull);
  });

  testWidgets('with reduced motion the shimmer stands still', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    repo = FakeKnowledgeRepository(
      articles: [
        KnowledgeArticle(
          title: 'Mit Bild',
          link: Uri.parse('https://www.myfodmap.at/bild'),
          imageUrl: 'https://static.wixstatic.com/media/x.jpg',
        ),
      ],
    );
    await pump(tester, settle: false);

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    final context = tester.element(find.byType(CachedNetworkImage));
    final shimmer = image.placeholder!(context, image.imageUrl) as Shimmer;
    expect(shimmer.enabled, isFalse);
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

/// Marks at once, but its write waits for [_write].
class _SlowWrite extends KnowledgeOpenedNotifier {
  _SlowWrite(this._write);
  final Future<void> _write;

  @override
  Future<Set<String>> build() async => const {};

  @override
  Future<void> markOpened(Uri link) async {
    state = AsyncData({...?state.value, link.toString()});
    await _write;
  }
}
