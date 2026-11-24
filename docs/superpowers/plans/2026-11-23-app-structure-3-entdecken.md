# App-Struktur Stage 3: Entdecken complete — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Finish Entdecken: the myfodmap articles in the app (Wissen), the opt-in for weekly tips with the Buddy's one-time offer, the „Neue Tipps" row and announcement on Home, and a dot on the Entdecken tab while something new waits there.

**Architecture:**
- **Wissen:** a pure RSS parser (`package:xml`), a small HTTP service, a repository that also keeps the last good copy in SharedPreferences, and an `AsyncNotifier` with a 6 h freshness rule. Entdecken previews the newest 3 articles; `/discover/knowledge` (inside the Entdecken branch) lists them all with a category filter. Articles open in the in-app browser.
- **Weekly tips opt-in:** `profiles.weekly_tips_enabled` (core migration 0009) gets its own write path, so a backend without the column fails only that switch. One `WeeklyTipsSwitch` widget serves the Tipps section and Settings → Benachrichtigungen.
- **What is new:** the tip sets' own `seen_at` replaces the separate unseen count. `unseenTipSetProvider` feeds Home's tips row, the dot and the Buddy. A `discoverNewsProvider` keeps tips and alternatives loaded: on sign-in, on resume, on pushes and on Home/Entdecken loads.
- **Buddy:** two new `BuddyAnnouncement` kinds go through the existing queue and flags. Home offers them (`buddyOffersProvider` → `BuddyNotifier.offerAnnouncement`), and the hero plays them.

**Tech Stack:** Flutter 3.50 (`package:material_ui/material_ui.dart`), Riverpod 3 (`Notifier`/`AsyncNotifier`), GoRouter 18 (`StatefulShellRoute`), freezed/json_serializable, `xml` 7.0.1, `http` 1.6.0, `cached_network_image` + `shimmer`, `url_launcher`, mocktail, integration_test.

**Spec:** `docs/superpowers/specs/2026-11-23-app-structure-redesign-design.md` (approved 2026-11-23). This plan implements the app side of **Stage 3** (§6):
- §5.6.1 opt-in switch and the Buddy's offer;
- §5.6.4 Wissen in the app;
- §5.3 item 5, the tips row and its announcement;
- §5.6 "Badge";
- §5.9 for all new copy.

It also carries two decided additions: the Settings switch rename/placement, and core PR #9's app follow-ups (Task 13, droppable). The core side (§5.7: migration 0009 and the weekly job) is core PR #7 and not part of this plan. Mockups: „Runde 3 · App-Struktur" at https://claude.ai/artifact/1TXEAjPsD821CgJrKXLG4q; local copy `/private/tmp/claude-501/-Users-sevi-projects-bellybuddy/9b9dd6d2-9058-4d39-8ff3-9503f60250aa/scratchpad/mockups/buddy-mockups.html`. Where the mockup and the spec differ, the spec wins.

## Global Constraints

From the spec and `CLAUDE.md`, verbatim where they give values:
- Follow the repo's `CLAUDE.md`:
  - colours, font sizes, spacing and radii only through `AppTheme`/`AppConstants` (add tokens there first);
  - German UI;
  - Riverpod AsyncNotifier, GoRouter, `AppLogger` (never `print`);
  - network images through `CachedNetworkImage` with a `shimmer` placeholder;
  - `dart format`; `flutter analyze` with zero issues; conventional commits.
- The mascot is "Belly Buddy". Never "Bauch-Buddy".
- Reduced motion is respected. Text scale 1.3 and a 375×667 phone must not overflow.
- No invented statistics, no efficacy claims, and nothing that reads like a diagnosis. Article and tip copy is the source's; the app adds none of its own about health effects.
- No guilt and no punishing pet. Error states use a neutral mascot (`AppConstants.mascotClueless`), never `mascotSad`.
- Home must not end up busier than the mockup H2. The only new Home tap target is the tips row of §5.3 item 5, shown only while an unseen tip set exists.
- No tile, row or link may lead to an empty, paused or placeholder screen.
- One vocabulary (§5.9):
  - **eintragen**;
  - **Essen, Trinken, Bauchgefühl, Klo**;
  - **Speichern, Weiter**;
  - **Streak**, **Tagebuch**, **Tipps** (never „Empfehlung" in UI), **Alternativen**, **Home**.

  `test/utils/vocabulary_test.dart` stays green, with no new exemptions.
- Weekly tips are **off by default**. The switch is labelled „Wöchentliche Tipps" and carries the sentence „Dafür schicke ich deine Mahlzeiten und dein Bauchgefühl der letzten Woche an unseren KI-Dienst." It is separate from the push toggle, which only controls the push. Previously generated tips stay visible regardless.
- Notification taps route to `/meal-tracker`, `/gut-feeling-tracker`, `/recommendations`, `/ingredient-suggestions` and `/dashboard`. These keep working. Gate order is unchanged: upgrade gate → auth → health consent → Buddy onboarding gate.
- Deploy order: core first (0008 `buddy_state`, 0009 `weekly_tips_enabled`, job disabled), then the app. The app must still work against a backend without 0009: only the weekly switch may fail, never profile loading or other profile saves.
- Process per stage: build via plan → `/simplify` → `/code-review` → fix findings → PR to the stage's base. Severin tests locally. One release at the end.

Execution rules for this repo:
- **Commits:** `dart format .` and `flutter analyze` (0 issues) first. Then `git commit --no-verify` (the hook is broken in worktrees), with a conventional prefix and the trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. **Never push.**
- **Codegen:** after a Freezed model change (Tasks 5 and 7), run `dart run build_runner build --delete-conflicting-outputs`. Generated files are gitignored.
- **Dependencies:** only `xml: ^7.0.1` and `http: ^1.6.0` become direct dependencies. Both are already in `pubspec.lock` as transitive (`xml` 7.0.1, `http` 1.6.0), so `flutter pub get` changes only their `dependency:` lines. `flutter_lints`' `depend_on_referenced_packages` makes direct listing mandatory for an import.
- **No network in tests:** every test that builds Entdecken, the Wissen list or the real router overrides `knowledgeRepositoryProvider` with `FakeKnowledgeRepository` (Task 2). Add it to `baseOverrides` in `test/helpers/app_host.dart` and to `buildTestApp` in `integration_test/helpers/test_app.dart`.
- **Test seams:**
  - The root `test/flutter_test_config.dart` holds the Buddy and care-ring animations still. Hero tests keep `tickBuddiesInTests()`.
  - `Shimmer` animates forever. A test that shows an article **with** an image uses `pump`, never `pumpAndSettle`. Fixture articles elsewhere have no image.
- **Simulators:** integration tests run **only** on the iPhone Air `CB1F6232-482F-408F-ADF4-89FDA602E6A8`, one file at a time, shut down afterwards. **Never** `55746DB2…` (Severin's live session) or `7A26EDD4…`. Never run `flutter clean`.

## Review Focus

1. **Feed malformed or partial.**
   - A truncated or non-RSS response never replaces the last good copy, and never crashes.
   - Items without a title, without a link, or with a non-http(s) link (`javascript:`) are dropped; the rest show.
   - A missing date or image only hides that part.

   Pinned in Task 1 (`truncated XML throws FormatException`, `skips unusable items`) and Task 2 (`a malformed feed keeps the last good copy`).
2. **No network on the first open.**
   - Entdecken's Wissen says „Artikel konnten nicht geladen werden.", and the list screen offers „Nochmal versuchen".
   - Pull-to-refresh recovers without an app restart.
   - Offline later: the cached copy shows with the offline line.

   Pinned in Task 2 (`no copy, fetch fails: error`), Task 3 (`error without a copy`, `offline copy`) and Task 4 (`no copy and offline`).
3. **Backend without migration 0009.**
   - The profile loads (weekly tips read as off).
   - Every other profile save still works.
   - The weekly switch snaps back with „Wöchentliche Tipps konnten nicht gespeichert werden. Versuch es später nochmal."

   Pinned in Task 5 (`create/update never send weekly_tips_enabled`, `a missing column reverts only the switch`) and Task 6 (`failure snaps back with a SnackBar`).
4. **The offer shown twice.** The weekly-tips offer comes at most once per user and device. It does not come again after a restart, while weekly tips are already on (or were turned on in Settings meanwhile), or when the insights recompute again and again. Pinned in Task 10 (`offered once`, `not after a restart`, `repeated offers queue it once`) and Task 11 (`skipped when already on`).
5. **Row and dot stale after viewing.**
   - Opening the Tipps clears Home's row and the Entdecken dot at once.
   - A fetch that started earlier and lands afterwards does not bring them back. The same holds for the Alternativen.

   Pinned in Task 7 (`a fetch landing after markAllAsSeen keeps the sets seen`, `an earlier fetch landing after the mark keeps the count at 0`) and Task 8 (`the dot goes once the Tipps are opened`).

## Decisions (spec gaps ruled in this plan)

- **The offer leads to the switch** via a sheet with „Zu den Tipps" (→ `/discover`) and „Später". The opt-in switch itself stays in the two places §5.6.1 names (the Tipps section and Settings), so the consent sentence has one wording and one failure path.
- **Switch placement on Entdecken:** a separate, non-tappable card under the tip-set card, shown only while weekly tips are off. While on and without tips, the section shows the spec's empty line. While the profile is unknown, no switch shows.
- **"Unseen tip set"** = the newest loaded recommendation row with `seen_at == null`. That is the existing seen tracking, read from the rows themselves. `unseenRecommendationCountProvider` and `countUnseen` go away.
- **The tips announcement plays once per set** (flag suffix = the recommendation id). It is skipped if the set was seen before it played. A newer set replaces a pending older one.
- **The badge** shows while an unseen set or new alternatives exist, including while the Entdecken tab is open (spec: "while … exist").
- **Wissen categories:** Wix sends them with stray spaces and emojis (`" Gesund verdauen"`, `"❤️ Persönliches"`). They are trimmed, and leading non-letters are stripped. The filter is „Alle" plus the categories in order of first appearance, newest article first. The preview shows the newest 3 across all categories.
- **Cache:** SharedPreferences (already a direct dependency and used across the app) holds the parsed articles as JSON (~5 KB), not the raw XML. A file would need `path_provider` as a new direct dependency. The cache is public content, so it is not user-scoped and survives sign-out. A feed with zero items is a valid answer and shows the empty state.
- **`/discover/knowledge`** is a child route of the Entdecken branch (the bar stays). Like `/patterns`, it is not gated. Tapping the Entdecken tab while on it returns to the tab's root.
- **Article links:** only http(s) links and image URLs from the feed are used.
- **Tips row copy:** „✨ Neue Tipps · Woche 47 · 3 Tipps", with „1 Tipp" in the singular. The count part is omitted for a set without items (core may save a summary-only set). Without `createdAt`: „✨ Neue Tipps · 3 Tipps".
- **`ensure_ingredient`** (core #9) returns only the ingredient's uuid, not a row, and the caller may not be able to read that row. The app ignores the result.

---

## File Structure

| File | Responsibility |
|---|---|
| `pubspec.yaml`, `pubspec.lock` (modify) | `xml`, `http` direct |
| `lib/models/knowledge_article.dart` (create) | `KnowledgeArticle`, `KnowledgeFeed` |
| `lib/services/knowledge/knowledge_feed_parser.dart` (create) | pure `parseKnowledgeFeed` |
| `lib/services/knowledge/knowledge_feed_service.dart` (create) | HTTP GET of the feed |
| `lib/repositories/knowledge_repository.dart` (create) | fetch + parse; cache read/write |
| `lib/providers/knowledge_provider.dart` (create) | 6 h freshness, last good copy, refresh |
| `lib/utils/url_utils.dart`, `lib/utils/date_format_utils.dart` (modify) | launch mode; `formatDayMonthYear` |
| `lib/screens/discover/widgets/knowledge_article_tile.dart` (create) | one article row + `openArticle` |
| `lib/screens/discover/knowledge_screen.dart` (create) | Wissen list with the filter |
| `lib/screens/discover/widgets/discover_knowledge_section.dart` (create) | Entdecken preview; replaces `discover_knowledge_card.dart` (delete) |
| `lib/router/route_names.dart`, `lib/router/app_router.dart` (modify) | `/discover/knowledge` |
| `lib/models/user_profile.dart`, `lib/repositories/profile_repository.dart`, `lib/providers/profile_provider.dart` (modify) | `weeklyTipsEnabled` and its own write |
| `lib/widgets/common/weekly_tips_switch.dart` (create) | the opt-in switch + sentence |
| `lib/screens/discover/widgets/discover_tips_section.dart` (create) | the Tipps section's states |
| `lib/screens/settings/widgets/settings_notifications_screen.dart` (modify) | „Wöchentliche Tipps" + „Tipps per Push" |
| `lib/models/recommendation.dart`, `lib/providers/recommendation_provider.dart`, `lib/services/recommendation_service.dart`, `lib/repositories/recommendation_repository.dart` (modify) | `seenAt`, local stamp, `unseenTipSetProvider`; the count goes |
| `lib/providers/ingredient_suggestion_provider.dart` (modify) | keeps groups while reloading; seen ids |
| `lib/providers/discover_news_provider.dart` (create) | `discoverNewsProvider`, `discoverBadgeProvider` |
| `lib/app.dart` (modify) | watches `discoverNewsProvider`; push refresh |
| `lib/widgets/common/bb_bottom_nav.dart` (modify) | the dot; re-tap goes to the tab root |
| `lib/screens/dashboard/widgets/tips_row.dart` (create) | Home's „Neue Tipps" row |
| `lib/screens/dashboard/dashboard_screen.dart` (modify) | row, news refresh, offers → Buddy |
| `lib/providers/buddy_provider.dart` (modify) | two kinds, `offerAnnouncement` |
| `lib/providers/buddy_offers_provider.dart` (create) | `weeklyTipsOfferDueProvider`, `buddyOffersProvider` |
| `lib/screens/dashboard/widgets/buddy_hero.dart` (modify) | two cues |
| `lib/screens/dashboard/widgets/weekly_tips_offer_sheet.dart` (create) | the offer sheet |
| `lib/config/app_theme.dart`, `lib/config/constants.dart` (modify) | new tokens and constants |
| `lib/services/ingredient_service.dart` (modify, Task 13) | `ensure_ingredient` |

---

### Task 1: Wissen feed model and parser

**Files:**
- Modify: `pubspec.yaml` (add `xml: ^7.0.1` under dependencies), `pubspec.lock` (via `flutter pub get`)
- Create: `lib/models/knowledge_article.dart`, `lib/services/knowledge/knowledge_feed_parser.dart`
- Test: `test/models/knowledge_article_test.dart`, `test/services/knowledge/knowledge_feed_parser_test.dart`

**Interfaces:**
- Produces:
  ```dart
  class KnowledgeArticle {   // == / hashCode by value, no Freezed
    const KnowledgeArticle({required this.title, required this.link, this.category, this.publishedAt, this.imageUrl});
    final String title; final Uri link; final String? category;
    final DateTime? publishedAt;   // UTC
    final String? imageUrl;
    Map<String, Object?> toJson(); factory KnowledgeArticle.fromJson(Map<String, Object?> json);
  }
  class KnowledgeFeed {
    const KnowledgeFeed({required this.articles, required this.fetchedAt, this.offline = false});
    final List<KnowledgeArticle> articles;  // newest first
    final DateTime fetchedAt;
    final bool offline;                     // shown from the cache after a failed fetch; not persisted
    List<String> get categories;            // distinct, in order of first appearance
    KnowledgeFeed copyWith({bool? offline});
    Map<String, Object?> toJson(); factory KnowledgeFeed.fromJson(Map<String, Object?> json); // throws FormatException on bad shape
  }
  List<KnowledgeArticle> parseKnowledgeFeed(String xml);  // throws FormatException
  String? normalizeFeedCategory(String? raw);
  ```

The real feed is one line of RSS 2.0, 20 items. Each item has a CDATA `title`, a `link`, one CDATA `category`, a `pubDate` (`Thu, 27 Mar 2025 23:00:00 GMT`) and `<enclosure url="https://static.wixstatic.com/…/file.png" type="image/png"/>`. Titles inside CDATA still carry HTML entities (`Glutenfrei &#38; low FODMAP`). Build the test fixture as an inline Dart string with that shape; do not commit the real feed.

- [ ] **Step 1: Failing tests.**

  `parseKnowledgeFeed`:
  - **`reads title, link, category, date and image`:** an item with CDATA category `' Gesund verdauen'` and `pubDate` `Thu, 27 Mar 2025 23:00:00 GMT` gives:
    - `category == 'Gesund verdauen'`;
    - `publishedAt == DateTime.utc(2025, 3, 27, 23)`;
    - `imageUrl` = the enclosure URL;
    - `link == Uri.parse('https://www.myfodmap.at/die-zeitumstellung')`.
  - **`decodes entities left inside CDATA`:** `No-Bake Lemon Cheesecake - Glutenfrei &#38; low FODMAP` → `… Glutenfrei & low FODMAP`.
  - **`normalizes categories`:**
    - `'❤️ Persönliches'` → `'Persönliches'`;
    - `'  Rezepte '` → `'Rezepte'`;
    - `'   '` → `null`;
    - a missing `<category>` → `null`.
  - **`skips unusable items`:**
    - no `<link>` → dropped;
    - empty title → dropped;
    - `javascript:alert(1)` and `ftp://x` links → dropped;
    - an `ftp://` enclosure → `imageUrl == null`, item kept;
    - pubDate `gestern` → `publishedAt == null`, item kept.
  - **`sorts newest first, undated last`:** feed order B(2024), A(2025), C(no date) → A, B, C.
  - **`an empty channel is no error`:** `<rss><channel></channel></rss>` → `[]`.
  - **`truncated XML throws FormatException`:** the fixture cut in the middle of an item → `throwsFormatException`.
  - **`not RSS throws FormatException`:** `<html><body>Wartung</body></html>` → `throwsFormatException`.

  Model:
  - **`KnowledgeFeed round-trips through JSON without offline`:** `fromJson(toJson(feed.copyWith(offline: true))).offline == false`, and the articles are equal.
  - **`categories in order of first appearance`:** articles [Rezepte, Gesund verdauen, Rezepte, null] → `['Rezepte', 'Gesund verdauen']`.
  - **`fromJson of a bad shape throws FormatException`:** for example `{'articles': 3}`.
- [ ] **Step 2:** Run `flutter test test/models/knowledge_article_test.dart test/services/knowledge`. Expected: FAIL (undefined).
- [ ] **Step 3: Implement.**
  - Parse with `XmlDocument.parse`; an `XmlException` becomes a `FormatException`. A document without `rss > channel` throws `FormatException`.
  - Text comes from `innerText`. Decode with `const XmlDefaultEntityMapping.html5().decode(…)`, then trim.
  - The category strips `RegExp(r'^[^\p{L}\p{N}]+', unicode: true)` after trimming.
  - Dates come from `HttpDate.parse` (`dart:io`); a parse failure gives `null`.
  - Links and images must have the `http`/`https` scheme. Reuse `isValidImageUrl` from `url_utils.dart` for images.
  - The sort is stable.
- [ ] **Step 4:** Run the tests again. Expected: PASS.
- [ ] **Step 5: Commit** `feat(discover): read the myfodmap blog feed`

---

### Task 2: Wissen data — fetch, 6 h cache, last good copy

**Files:**
- Modify: `pubspec.yaml` (`http: ^1.6.0`), `pubspec.lock`, `lib/config/constants.dart`
- Create:
  - `lib/services/knowledge/knowledge_feed_service.dart`
  - `lib/repositories/knowledge_repository.dart`
  - `lib/providers/knowledge_provider.dart`
- Modify (test helpers): `test/helpers/fakes.dart` (`FakeKnowledgeRepository`), `test/helpers/fixtures.dart` (`testKnowledgeArticles()`), `test/helpers/app_host.dart` (`baseOverrides`)
- Test:
  - `test/services/knowledge/knowledge_feed_service_test.dart`
  - `test/repositories/knowledge_repository_test.dart`
  - `test/providers/knowledge_provider_test.dart`

**Interfaces:**
- Consumes: `parseKnowledgeFeed`, `KnowledgeFeed` (Task 1); `buddyClockProvider` (the app clock).
- Produces:
  - `AppConstants.knowledgeFeedUrl = 'https://www.myfodmap.at/blog-feed.xml'`
  - `AppConstants.knowledgeFeedMaxAge = Duration(hours: 6)`
  - `AppConstants.knowledgeFeedTimeout = Duration(seconds: 10)`
  - `AppConstants.keyKnowledgeFeedCache = 'knowledge_feed_cache_v1'`
  - `KnowledgeFeedService(http.Client client, {Duration timeout = AppConstants.knowledgeFeedTimeout})`, `Future<String> fetchFeed()`. It throws on a non-200 status or a timeout, and decodes the body as UTF-8. `knowledgeFeedServiceProvider` creates an `http.Client` and closes it on dispose.
  - `KnowledgeRepository(KnowledgeFeedService service)`:
    - `Future<List<KnowledgeArticle>> fetchArticles()` (service + parser);
    - `Future<KnowledgeFeed?> readCache()`: null when there is none, or when it is corrupt (logged);
    - `Future<void> writeCache(KnowledgeFeed feed)`.
    - `knowledgeRepositoryProvider`.
  - `knowledgeFeedProvider`: `AsyncNotifierProvider<KnowledgeFeedNotifier, KnowledgeFeed>`, with `retry: (_, _) => null`.
    - `Future<void> refresh()`: always fetches and never throws.
    - `Future<void> refreshIfStale()`: fetches only when the shown copy is `knowledgeFeedMaxAge` old or older.
  - `FakeKnowledgeRepository({List<KnowledgeArticle>? articles, KnowledgeFeed? cache})`, with:
    - `Object? fetchError`;
    - `int fetchCount`;
    - `KnowledgeFeed? cache` (in memory);
    - `List<KnowledgeFeed> written`.
  - `List<KnowledgeArticle> testKnowledgeArticles()`: 4 articles without images. Two are „Gesund verdauen", one „Rezepte", one „Persönliches", newest first, with distinct `https://www.myfodmap.at/…` links.

**`build()` rules** (now = `buddyClockProvider`):
1. Read the cache.
2. If it is younger than 6 h and not in the future, return it with no network call.
3. Otherwise fetch. On success, write the cache (a write failure is logged, not fatal) and return `KnowledgeFeed(articles, fetchedAt: now)`.
4. If the fetch fails: with a cache, return `cache.copyWith(offline: true)`; without one, rethrow (logged).

**`refresh()`:**
- On success, the new feed and a cache write.
- On failure, the current value with `offline: true`. Without a value, an `AsyncError`.

- [ ] **Step 1: Failing tests.**
  - **Service** (`MockClient` from `package:http/testing.dart`):
    - `200 → the body as UTF-8`: the bytes of `'Persönliches'` decode correctly;
    - `500 → throws`;
    - `slower than the timeout → throws` (`timeout: Duration(milliseconds: 10)` with a client that waits 50 ms);
    - it requests exactly `AppConstants.knowledgeFeedUrl`.
  - **Repository** (`SharedPreferences.setMockInitialValues({})`):
    - `writeCache then readCache round-trips`;
    - `a corrupt cache reads as none`: the key holds `'{nope'`;
    - `fetchArticles parses the service's feed`.
  - **Notifier** (fake repository, `buddyClockProvider` pinned to 23.11.2026 10:00):
    - `a fresh copy (< 6 h) is shown without a fetch`: cache at 05:00 → `fetchCount == 0`.
    - `a copy of exactly 6 h is fetched again`: cache at 04:00 → `fetchCount == 1`, `written.single.fetchedAt == now`.
    - `stale copy, fetch fails: the copy shows, offline` → `value.offline == true`, articles equal the cache's.
    - `no copy, fetch fails: error`: `hasError`, and `fetchCount == 1` (no retry loop).
    - `a copy from the future is fetched again`: cache at 23.11.2026 12:00.
    - `a malformed feed keeps the last good copy`: `fetchError = FormatException()`, stale cache → cache shown, `written` empty.
    - `refresh fetches even when fresh; a failed refresh keeps the articles and never throws`.
    - `refreshIfStale fetches only after 6 h`: advance the pinned clock from 10:00 to 15:59 → no fetch; to 16:00 → one fetch.
- [ ] **Step 2:** Run `flutter test test/services/knowledge test/repositories/knowledge_repository_test.dart test/providers/knowledge_provider_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement** per the interfaces. Add `knowledgeRepositoryProvider.overrideWithValue(FakeKnowledgeRepository(articles: testKnowledgeArticles()))` to `baseOverrides`.
- [ ] **Step 4:** Run the tests again, then `flutter test test/router`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(discover): keep the blog articles for 6 hours and offline`

---

### Task 3: The Wissen list under Entdecken

**Files:**
- Modify:
  - `lib/utils/url_utils.dart`
  - `lib/utils/date_format_utils.dart`
  - `lib/router/route_names.dart`
  - `lib/router/app_router.dart` (child route of the `/discover` branch route)
  - `lib/widgets/common/bb_bottom_nav.dart` (`goBranch`)
  - `lib/config/constants.dart`
- Create: `lib/screens/discover/widgets/knowledge_article_tile.dart`, `lib/screens/discover/knowledge_screen.dart`
- Test:
  - `test/utils/url_utils_test.dart` (create if missing)
  - `test/utils/date_format_utils_test.dart`
  - `test/screens/discover/knowledge_screen_test.dart`
  - `test/router/navigation_shell_test.dart`

**Interfaces:**
- Consumes: `knowledgeFeedProvider`, `KnowledgeArticle`, `FakeKnowledgeRepository` (Task 2).
- Produces:
  - `openExternalUrl(BuildContext, String url, {required String failureMessage, UrlOpener open = launchUrl, LaunchMode mode = LaunchMode.externalApplication})`. Existing callers are unchanged.
  - `String formatDayMonthYear(DateTime d)` → `'28. Mär 2025'` (via `kMonthShortNames`).
  - `RoutePaths.knowledge = '/discover/knowledge'`, `RouteNames.knowledge = 'knowledge'`.
  - `KnowledgeArticleTile({required KnowledgeArticle article, required VoidCallback onTap})`, with `static Key keyFor(KnowledgeArticle a)` → `ValueKey('knowledge_article_${a.link}')`.
  - `Future<void> openArticle(BuildContext context, KnowledgeArticle article, {UrlOpener open = launchUrl})`. It uses `LaunchMode.inAppBrowserView` and the failure text `'Der Artikel konnte nicht geöffnet werden.'`.
  - `KnowledgeScreen({super.key, this.openUrl = launchUrl})`, with `static Key chipKey(String? category)` → `ValueKey('knowledge_chip_${category ?? '*'}')`.
  - `AppConstants.knowledgeThumbSize = 64.0`.

**Screen** (top to bottom):
- AppBar `'Wissen'`.
- The source line `'Artikel aus dem myfodmap-Blog'`.
- While `offline`, the line `'Gerade offline – du siehst den zuletzt geladenen Stand.'`.
- A horizontally scrolling chip row: `'Alle'` + `feed.categories`, styled like `BbChipSelector` (selected `AppTheme.chipDefault`).
- The tiles.
- Pull-to-refresh calls `refresh()`; `initState` calls `refreshIfStale()`.

**Tile:**
- A `knowledgeThumbSize` thumbnail (radius `radiusMd`):
  - `CachedNetworkImage` with a `Shimmer.fromColors(baseColor: AppTheme.muted, highlightColor: AppTheme.background)` placeholder;
  - `memCacheWidth` = size × device pixel ratio (the Wix images are 1000 px);
  - an `Icons.menu_book_outlined` fallback on `AppTheme.muted` for no image or an error.
- The title: `fontSizeBodyLG`, w600, max 3 lines.
- The meta line `'Rezepte · 13. Mär 2025'`. Parts are joined with `' · '` and missing ones dropped; the date is `publishedAt.toLocal()`.
- `Semantics(button: true)`.

**States:**
- loading → `BbLoadingState(message: 'Laden…')`;
- error without a value → `BbErrorState(message: 'Die Artikel konnten nicht geladen werden.', retryLabel: 'Nochmal versuchen', mascotAsset: AppConstants.mascotClueless, onRetry: refresh)`;
- no articles → `'Gerade keine Artikel.'`.

**Bar:** `goBranch(index)` passes `initialLocation: index == navigationShell.currentIndex`, so tapping Entdecken on the Wissen list returns to Entdecken.

- [ ] **Step 1: Failing tests.**
  - `formatDayMonthYear(DateTime(2025, 3, 28)) == '28. Mär 2025'`.
  - `openExternalUrl passes the mode` (the fake opener records `LaunchMode.inAppBrowserView`). Without `mode` it is still `externalApplication`.
  - `KnowledgeScreen` (fake repository with `testKnowledgeArticles()`):
    - **`shows Alle and the feed's categories in order`:** chip labels `Alle`, `Gesund verdauen`, `Rezepte`, `Persönliches`, left to right.
    - **`a category shows only its articles; Alle shows all again`.**
    - **`an article opens in the in-app browser`:** `launches.urls == [article.link]`, `launches.modes == [LaunchMode.inAppBrowserView]`.
    - **`a failed launch says so`:** the opener returns false → SnackBar `'Der Artikel konnte nicht geöffnet werden.'`.
    - **`meta line`:** `find.text('Rezepte · 13. Mär 2025')`. An undated article shows only its category.
    - **`error without a copy`:** `fetchError` set and no cache → the message plus `'Nochmal versuchen'`. Clearing the error and tapping the button shows the articles.
    - **`offline copy`:** stale cache plus `fetchError` → the offline line and the cached titles.
    - **`no articles`:** `'Gerade keine Artikel.'`, and no chips except `Alle`.
    - **`a picked category gone after a refresh falls back to Alle`.**
    - **`images load cached, with a shimmer`:** one article with `imageUrl`. Use `pump()` only. `tester.widget<CachedNetworkImage>(…)` has that `imageUrl`, and its `placeholder!(context, url)` is a `Shimmer`.
    - **`fits 375×667 at text scale 1.3`** with a 140-character title → `tester.takeException()` is null.
  - `navigation_shell_test.dart`:
    - **`Wissen opens under Entdecken with the bar`:** push `RoutePaths.knowledge` from Entdecken → `KnowledgeScreen` shown and `BbBottomNav` still found.
    - **`tapping Entdecken on Wissen goes back to Entdecken`.**
- [ ] **Step 2:** Run them. Expected: FAIL.
- [ ] **Step 3: Implement.** The `/discover` route gets `routes: [GoRoute(path: 'knowledge', name: RouteNames.knowledge, builder: …)]`. `buddyOnboardingGatedPaths` is unchanged.
- [ ] **Step 4:** Run `flutter test test/utils test/screens/discover/knowledge_screen_test.dart test/router`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(discover): Wissen — the blog's articles in the app, by category`

---

### Task 4: Entdecken previews Wissen

**Files:**
- Create: `lib/screens/discover/widgets/discover_knowledge_section.dart`
- Modify: `lib/screens/discover/discover_screen.dart`, `lib/config/constants.dart` (remove `blogUrl`)
- Delete: `lib/screens/discover/widgets/discover_knowledge_card.dart`
- Test: `test/screens/discover/discover_screen_test.dart`

**Interfaces:**
- Consumes: `knowledgeFeedProvider` (Task 2), `KnowledgeArticleTile`, `openArticle`, `RoutePaths.knowledge` (Task 3).
- Produces:
  - `DiscoverKnowledgeSection({required AsyncValue<KnowledgeFeed> feed, required VoidCallback onOpenAll, required ValueChanged<KnowledgeArticle> onOpen})`, with `sectionKey = Key('discover_knowledge')` and `static const shown = 3`.
  - `DiscoverScreen.knowledgeKey = DiscoverKnowledgeSection.sectionKey`.

**Section:** a `DiscoverSection(title: 'Wissen')`.
- With articles: the header gets `DiscoverAllLink` → `context.push(RoutePaths.knowledge)`. The body is one `BbCard` with the first 3 tiles and dividers, like the Alternativen.
- No value: `DiscoverNote.pending(feed, 'Artikel')`, which reads „Laden…" or „Artikel konnten nicht geladen werden.".
- No articles: `DiscoverNote('Gerade keine Artikel.')`, with no link.

**`DiscoverScreen._load`:** calls `refreshIfStale()`, or `refresh()` on pull-to-refresh.

- [ ] **Step 1: Failing tests.** Replace `Wissen opens the blog` and the `blogUrl` assertions.
  - **`Wissen previews the newest 3 and Alle ›`:** 4 fake articles → 3 tiles inside `knowledgeKey`. `'Alle ›'` → location `/discover/knowledge`; add it to the stub routes.
  - **`an article opens in the in-app browser`:** `modes == [LaunchMode.inAppBrowserView]`.
  - **`no copy and offline`:** `'Artikel konnten nicht geladen werden.'`, and no `'Alle ›'` in the section.
  - **`no articles`:** `'Gerade keine Artikel.'`.
  - **`pull-to-refresh refreshes the feed`:** the fake's `fetchCount` rises by 1 after a fling.
  - `four sections in order` stays green.
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3: Implement.** Run `grep -rn blogUrl lib test` → empty.
- [ ] **Step 4:** Run `flutter test test/screens/discover`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(discover): Wissen previews the newest articles instead of linking out`

---

### Task 5: `weekly_tips_enabled` — read with the profile, written on its own

**Files:**
- Modify:
  - `lib/models/user_profile.dart`
  - `lib/repositories/profile_repository.dart`
  - `lib/providers/profile_provider.dart`
  - `test/helpers/fakes.dart` (`FakeProfileRepository`)
  - `test/helpers/fixtures.dart` (`testUserProfile(weeklyTipsEnabled:)`)
- Test:
  - `test/models/user_profile_test.dart`
  - `test/repositories/profile_repository_test.dart`
  - `test/providers/profile_provider_test.dart`

**Interfaces:**
- Produces:
  - `UserProfile.weeklyTipsEnabled`: `@JsonKey(name: 'weekly_tips_enabled') @Default(false) bool`.
  - `Future<void> ProfileRepository.setWeeklyTips(String userId, bool enabled)` → `_profileService.update(userId, {'weekly_tips_enabled': enabled})`.
  - `createProfile` and `updateProfile` remove `'weekly_tips_enabled'` from their payloads. A backend without migration 0009 then still creates and updates profiles, and a stale profile can't flip the opt-in.
  - `Future<void> ProfileNotifier.setWeeklyTips(bool enabled)`: an optimistic update of the loaded profile, reverted and rethrown on failure. It throws `StateError` without a loaded profile.
  - `final weeklyTipsEnabledProvider = Provider<bool?>` is `profileProvider`'s data `?.weeklyTipsEnabled`. It is null while loading, failed or without a profile.
  - `FakeProfileRepository`: `Object? weeklyTipsError`, `List<bool> weeklyTipsWrites`. `setWeeklyTips` records the call, throws when the error is set, and otherwise stores the value.

- [ ] **Step 1: Failing tests.**
  - **Model:**
    - `fromJson` without the key → `false`;
    - `{'weekly_tips_enabled': true}` → `true`.
  - **Repository:**
    - `create/update never send weekly_tips_enabled`: the captured upsert and update maps lack the key, also for `testUserProfile(weeklyTipsEnabled: true)`;
    - `setWeeklyTips writes only that column`: `verify(() => profileService.update('user-123', {'weekly_tips_enabled': true}))`.
  - **Provider:**
    - `setWeeklyTips is optimistic`: the state flips before the repository completes (a `Completer`).
    - `a missing column reverts only the switch`:
      - `weeklyTipsError = PostgrestException(message: "Could not find the 'weekly_tips_enabled' column of 'profiles' in the schema cache", code: 'PGRST204')`;
      - `setWeeklyTips(true)` throws, and the state is back to `false`;
      - a following `updateProfile(profile.copyWith(remindersEnabled: false))` succeeds.
    - `weeklyTipsEnabledProvider is null until a profile is loaded, then its value`.
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3: Implement**, then run `dart run build_runner build --delete-conflicting-outputs`.
- [ ] **Step 4:** Run `flutter test test/models test/repositories/profile_repository_test.dart test/providers/profile_provider_test.dart`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(tips): the weekly-tips opt-in on the profile, off by default`

---

### Task 6: The „Wöchentliche Tipps" switch on Entdecken and in Settings

**Files:**
- Create: `lib/widgets/common/weekly_tips_switch.dart`, `lib/screens/discover/widgets/discover_tips_section.dart`
- Modify: `lib/screens/discover/discover_screen.dart`, `lib/screens/settings/widgets/settings_notifications_screen.dart`
- Test:
  - `test/widgets/common/weekly_tips_switch_test.dart`
  - `test/screens/discover/discover_screen_test.dart`
  - `test/screens/settings/settings_notifications_test.dart`

**Interfaces:**
- Consumes: `weeklyTipsEnabledProvider`, `ProfileNotifier.setWeeklyTips` (Task 5); `DiscoverTipsCard`, `DiscoverNote` (Stage 1).
- Produces:
  - `WeeklyTipsSwitch({super.key})`, a `ConsumerStatefulWidget`:
    - a `SwitchListTile(title: Text(WeeklyTipsSwitch.title), contentPadding: EdgeInsets.zero)` with the sentence below as a caption (`fontSizeCaptionLG`, `mutedForeground`);
    - nothing while `weeklyTipsEnabledProvider` is null;
    - taps are ignored while a save runs;
    - on failure: logged, and SnackBar `failure`.
    - Constants:
      - `title = 'Wöchentliche Tipps'`;
      - `sentence = 'Dafür schicke ich deine Mahlzeiten und dein Bauchgefühl der letzten Woche an unseren KI-Dienst.'`;
      - `failure = 'Wöchentliche Tipps konnten nicht gespeichert werden. Versuch es später nochmal.'`;
      - `switchKey = Key('weekly_tips_switch')`.
  - `DiscoverTipsSection({required AsyncValue<List<Recommendation>> tips, required bool unseen, required bool? weeklyTips, required VoidCallback onOpen})`. `unseen` is passed through to Stage 1's `DiscoverTipsCard` until Task 7 removes it from both. It has:
    - `static const emptyWhileOn = 'Deine ersten Tipps kommen am Montag, wenn du diese Woche mindestens 5 Mahlzeiten einträgst.'`;
    - `optInKey = Key('discover_weekly_tips')`, a `BbCard` holding `WeeklyTipsSwitch`.

**The section's states:**

| tips | weeklyTips `false` | weeklyTips `true` | weeklyTips `null` |
|---|---|---|---|
| no value | pending note + opt-in card | pending note | pending note |
| empty | opt-in card only | `emptyWhileOn` note | `'Noch keine Tipps.'` |
| some | tip-set card + opt-in card | tip-set card | tip-set card |

**Settings → Benachrichtigungen:** the Tipps `SettingsSectionCard` moves out of the permission-greyed group, below it. It contains:
1. `WeeklyTipsSwitch`, never greyed: it controls generation, not delivery.
2. A divider.
3. `SwitchListTile(title: 'Tipps per Push')` with the caption `'Ich sag dir Bescheid, sobald neue Tipps da sind.'`. Only this switch is wrapped in `IgnorePointer(ignoring: !allowed)` + `AnimatedOpacity(disabledOpacity)` and shows `allowed && profile.pushEnabled`.

- [ ] **Step 1: Failing tests.**
  - **Switch:**
    - `shows the title and the sentence`;
    - `flipping it on saves true`: `weeklyTipsWrites == [true]`;
    - `failure snaps back with a SnackBar`: `weeklyTipsError` set → the switch is off again and `find.text(WeeklyTipsSwitch.failure)` is shown;
    - `a second tap while saving is ignored`: a slow fake → one write.
  - **Entdecken** (seeded `ProfileNotifier`; one test per table cell that has its own content):
    - `off, no tips: only the opt-in` → `optInKey` found, no `'Noch keine Tipps.'`;
    - `off, with tips: set card and opt-in`;
    - `on, no tips: when the first tips come` → `find.text(DiscoverTipsSection.emptyWhileOn)`, no switch;
    - `on, with tips: no switch`;
    - `profile unknown: no switch`;
    - `turning it on shows when the first tips come`.
  - **Settings:**
    - `the weekly switch works without notification permission`: with `NotificationPermission.notDetermined`, flipping it writes `true`. No `IgnorePointer` ancestor ignores it (`find.ancestor(of: switchKey, matching: find.byWidgetPredicate((w) => w is IgnorePointer && w.ignoring))` findsNothing).
    - `Tipps per Push is greyed without permission`.
    - `the push switch is called Tipps per Push`: `switchOn(tester, 'Tipps per Push')` replaces every `'Tipps'` switch lookup in the existing tests. `SwitchListTile` count 4 → 5.
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3: Implement.** `DiscoverScreen` passes `ref.watch(weeklyTipsEnabledProvider)`.
- [ ] **Step 4:** Run `flutter test test/widgets/common test/screens/discover test/screens/settings test/utils/vocabulary_test.dart`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(tips): opt in to weekly tips on Entdecken and in Settings; „Tipps per Push" for the push`

---

### Task 7: What is new — seen tip sets, seen alternatives, kept fresh

**Files:**
- Modify:
  - `lib/models/recommendation.dart`
  - `lib/providers/recommendation_provider.dart`
  - `lib/services/recommendation_service.dart`, `lib/repositories/recommendation_repository.dart` (remove `countUnseen`)
  - `lib/providers/ingredient_suggestion_provider.dart`
  - `lib/screens/discover/widgets/discover_tips_card.dart`, `discover_tips_section.dart` (drop `unseen`), `lib/screens/discover/discover_screen.dart` (drop the count listener)
  - `lib/app.dart`
  - `test/helpers/fakes.dart` (`FakeRecommendationRepository`), `test/helpers/fixtures.dart` (`testRecommendation(seenAt:)`)
- Create: `lib/providers/discover_news_provider.dart`
- Test:
  - `test/models/recommendation_test.dart`
  - `test/providers/recommendation_provider_test.dart`
  - `test/providers/ingredient_suggestion_provider_test.dart`
  - `test/providers/discover_news_provider_test.dart`
  - recommendation service/repository tests (remove the `countUnseen` cases)
  - `test/screens/discover/discover_screen_test.dart`

**Interfaces:**
- Produces:
  - `Recommendation.seenAt`: `@JsonKey(name: 'seen_at') DateTime?`.
  - `RecommendationNotifier.markAllAsSeen()` (same signature). It stamps `seenAt = now` on every loaded unseen set **before** the server call and remembers their ids. `fetchRecommendations` keeps that stamp on those ids even when the server still returns them unseen. `build()` forgets the ids.
  - `final unseenTipSetProvider = Provider<Recommendation?>`: the newest loaded set while its `seenAt == null`; null while loading, failed, empty or seen.
  - Removed:
    - `unseenRecommendationCountProvider`;
    - `RecommendationService.countUnseen`, `RecommendationRepository.countUnseen`;
    - their tests and fakes;
    - the two `ref.invalidate(unseenRecommendationCountProvider)` calls in `app.dart`.
  - `IngredientSuggestionNotifier`:
    - `fetchSuggestions` keeps the loaded groups while it reloads (loading only without a value, like `fetchRecommendations`);
    - `markAllNewAsSeen` adds the marked ids to a session set, only after the server write succeeds;
    - `newIngredientSuggestionCountProvider` = groups with `isNew` whose `suggestionIds` are not all in that set;
    - `_markedSeen` goes.
  - `discoverNewsProvider`: `NotifierProvider<DiscoverNewsNotifier, void>`.
    - `build()` listens to `currentUserIdProvider` (fire immediately) and calls `refresh()` in a microtask for each signed-in user.
    - It registers `AppLifecycleListener(onResume: refresh)` (only while signed in), disposed with the provider.
    - `Future<void> refresh()` runs `fetchRecommendations()` and `fetchSuggestions()` together, joins a refresh already running, and never throws.
  - `app.dart`:
    - `ref.watch(discoverNewsProvider)` next to `notificationSyncProvider`;
    - the foreground-push handler calls `ref.read(discoverNewsProvider.notifier).refresh()` instead of its two lines.
  - `DiscoverTipsCard({required tips, required onTap})`: „Neu" while `list.first.seenAt == null`. `DiscoverTipsSection` loses its `unseen` parameter too.
  - `DiscoverScreen._load` uses `discoverNewsProvider.notifier.refresh()` + recipes (+ knowledge from Task 4).
  - `FakeRecommendationRepository({List<Recommendation>? sets})`:
    - its default is one set seen on 1.11.2026, so existing flows see nothing new;
    - `markAllAsSeen` stamps its sets;
    - it records `fetchCount`.

- [ ] **Step 1: Failing tests.**
  - `fromJson reads seen_at`.
  - **Tip sets:**
    - `markAllAsSeen stamps the loaded sets at once`: `unseenTipSetProvider` is null before the repository's `markAllAsSeen` completes (a `Completer`).
    - `a fetch landing after markAllAsSeen keeps the sets seen`: start `fetchRecommendations` (held by a `Completer`), call `markAllAsSeen`, then complete the fetch with the set still unseen → `unseenTipSetProvider` stays null.
    - `unseenTipSetProvider`:
      - newest unseen → it;
      - newest seen → null;
      - an older unseen set behind a seen newest → null;
      - loading → null.
  - **Alternativen:**
    - `fetchSuggestions keeps the groups while reloading`: during the second fetch, `state.value` is the first list.
    - `an earlier fetch landing after the mark keeps the count at 0`.
    - The existing `a failed mark keeps the count` and `new groups arriving after a mark count again` stay green.
  - **`discoverNewsProvider`** (`TestWidgetsFlutterBinding.ensureInitialized()`):
    - `signed in: loads tips and alternatives once`;
    - `back in the foreground: loads them again` (`inactive` → `resumed`);
    - `signed out: loads nothing`;
    - `two refreshes at once fetch once`.
  - **Entdecken:**
    - the tips card shows „Neu" for `testRecommendation(seenAt: null)` and not for a seen one;
    - replace every `countUnseen` stub.
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3: Implement**, then run `build_runner`. Run `grep -rn "unseenRecommendationCountProvider\|countUnseen" lib test integration_test` → empty.
- [ ] **Step 4:** Run `flutter test test/models test/providers test/services test/repositories test/screens/discover test/screens/recommendations test/screens/ingredient_suggestions`. Expected: PASS.
- [ ] **Step 5: Commit** `refactor(tips): a tip set is new until seen, and stays seen once opened`

---

### Task 8: The Entdecken dot

**Files:**
- Modify: `lib/providers/discover_news_provider.dart`, `lib/widgets/common/bb_bottom_nav.dart`, `lib/config/app_theme.dart`, `lib/config/constants.dart`
- Test: `test/providers/discover_news_provider_test.dart`, `test/router/navigation_shell_test.dart`

**Interfaces:**
- Consumes: `unseenTipSetProvider`, `newIngredientSuggestionCountProvider` (Task 7).
- Produces:
  - `final discoverBadgeProvider = Provider<bool>` = `unseenTipSetProvider != null || newIngredientSuggestionCountProvider > 0`.
  - `BbBottomNav.discoverBadgeKey = Key('bottom_nav_discover_badge')`.
  - `_NavItem({…, bool badge = false})`. The dot is `AppConstants.navBadgeSize = 10.0`, in `AppTheme.navBadge = Color(0xFFE8456F)`, with a `Colors.white` border of `AppConstants.borderWidthLg`. It sits on the icon's top-right and is wrapped in `Semantics(label: 'Neues')`.

- [ ] **Step 1: Failing tests.**
  - **Provider:**
    - unseen set → true;
    - one new alternative → true;
    - neither → false;
    - both loading → false.
  - **Shell:**
    - `the dot shows on Entdecken while a tip set is new`: `find.byKey(discoverBadgeKey)` findsOneWidget, and it lies inside `navDiscoverKey`'s rect.
    - `no dot when nothing is new`.
    - `the dot goes once the Tipps are opened`: with the real `RecommendationsScreen` route, open `/recommendations`, then go back → findsNothing.
    - `the dot stays for new alternatives after the Tipps are seen`.
    - The `5-slot bar fits 375×667 at text scale 1.3` test also runs with the dot.
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3: Implement.** Only the Entdecken item passes `badge: ref.watch(discoverBadgeProvider)`.
- [ ] **Step 4:** Run `flutter test test/providers/discover_news_provider_test.dart test/router test/widgets`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(nav): a dot on Entdecken while new tips or alternatives wait`

---

### Task 9: Home's „Neue Tipps" row

**Files:**
- Create: `lib/screens/dashboard/widgets/tips_row.dart`
- Modify: `lib/screens/dashboard/dashboard_screen.dart`
- Test:
  - `test/screens/dashboard/widgets/tips_row_test.dart`
  - `test/screens/dashboard/dashboard_screen_test.dart` (`_overrides` adds a `FakeRecommendationRepository`)

**Interfaces:**
- Consumes: `unseenTipSetProvider`, `discoverNewsProvider` (Task 7); `isoWeekOf`.
- Produces:
  - `TipsRow({required Recommendation set, required VoidCallback onTap})`, with:
    - `rowKey = Key('home_tips_row')`;
    - `static String label(Recommendation set)`.
  - The row is a `BbCard` with `Semantics(button: true)`, holding `Expanded(Text(label, maxLines: 2))` + `Icon(Icons.chevron_right)`.
  - Dashboard: under `InsightCard`, a `Consumer` shows `AppConstants.gap12` + `TipsRow` only while `unseenTipSetProvider` is non-null. A tap → `context.push(RoutePaths.recommendations)`.
  - `_loadData` also awaits `ref.read(discoverNewsProvider.notifier).refresh()`; it joins the app root's refresh.

- [ ] **Step 1: Failing tests.**
  - **`label`:**
    - created 16.11.2026 with 3 items → `'✨ Neue Tipps · Woche 47 · 3 Tipps'`;
    - 1 item → `'… · 1 Tipp'`;
    - 0 items → `'✨ Neue Tipps · Woche 47'`;
    - no `createdAt` → `'✨ Neue Tipps · 3 Tipps'`.
  - **Dashboard:**
    - `an unseen tip set shows the row under the insight card`: the row's top ≥ the card's bottom.
    - `tapping it opens the Tipps`: location `/recommendations`.
    - `no row when every set is seen`. The existing test `Home shows chip, ring, one button and the insight card, nothing else` stays green.
    - `fits 375×667 at text scale 1.3 with the row`.
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4:** Run `flutter test test/screens/dashboard`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(home): „Neue Tipps" while a tip set waits`

---

### Task 10: The Buddy's new announcements — offered once

**Files:**
- Modify: `lib/providers/buddy_provider.dart`, `lib/screens/dashboard/dashboard_screen.dart`
- Create: `lib/providers/buddy_offers_provider.dart`
- Test:
  - `test/providers/buddy_provider_test.dart` (group `offerAnnouncement`)
  - `test/providers/buddy_offers_provider_test.dart`
  - `test/screens/dashboard/dashboard_screen_test.dart`

**Interfaces:**
- Consumes: `unseenTipSetProvider` (Task 7), `weeklyTipsEnabledProvider` (Task 5), `insightsProvider` (Stage 2).
- Produces:
  - `enum BuddyAnnouncement { saverUsed, streakBroken, saverEarned, goalReached, tipsArrived, weeklyTipsOffer }`. Update the enum's doc: the last two are offered from outside, not by the streak evaluation.
  - `Future<void> BuddyNotifier.offerAnnouncement(BuddyAnnouncement kind, {required String suffix})`:
    - It waits for a running load and never throws.
    - It does nothing in these cases:
      - signed out, or no status;
      - the user changed meanwhile;
      - the flag `<keyBuddyAnnouncedPrefix><userId>_<kind.name>_<suffix>` is set in SharedPreferences, or was marked shown this session;
      - the same key is already pending.
    - Otherwise it appends `kind` to the pending announcements. If `kind` is pending with another suffix, it keeps its place and takes the new key.
    - It re-reads the state after its last `await`. Pending offers survive refreshes through the existing `_withPending`.
    - A prefs read failure queues it ("better to repeat than to lose", as in `_announce`).
  - `const weeklyTipsOfferSuffix = 'once'`.
  - `final weeklyTipsOfferDueProvider = Provider<bool>`: `insightsProvider` is `AsyncData` with `unlocked`, **and** `weeklyTipsEnabledProvider == false`.
  - `final buddyOffersProvider = Provider<Map<BuddyAnnouncement, String>>`:
    - `{tipsArrived: set.id}` while an unseen set exists;
    - `{weeklyTipsOffer: weeklyTipsOfferSuffix}` while due.
  - `DashboardScreen.initState`: `ref.listenManual(buddyOffersProvider, …, fireImmediately: true)` calls `offerAnnouncement` for each entry in a microtask (never during build).

- [ ] **Step 1: Failing tests.**
  - **`offerAnnouncement`** (the real notifier over `FakeBuddyRepository`, `SharedPreferences.setMockInitialValues`):
    - `offered once`: offering the same kind and suffix twice → `announcements == [tipsArrived]`.
    - `a set flag stops it`: prefs hold `buddy_announced_<uid>_tipsArrived_rec-1` → nothing pending.
    - `not after it was shown`: `markAnnouncementsShown([weeklyTipsOffer])`, then offer again → nothing.
    - `not after a restart`: a new container over the same prefs → nothing.
    - `a newer set replaces a pending one`: offer `rec-1`, then `rec-2` → one `tipsArrived`, whose `announcementKeys` value ends in `_rec-2`.
    - `pending offers survive a refresh`.
    - `signed out: nothing`.
    - `waits for the first load`: offered while `build` runs → pending once loaded.
  - **`buddyOffersProvider`:**
    - unseen set `rec-1` → `{tipsArrived: 'rec-1'}`;
    - all seen → `{}`;
    - unlocked and weekly tips off → contains `weeklyTipsOffer: 'once'`;
    - unlocked and on → none;
    - locked → none;
    - profile unknown → none;
    - insights reloading for another user (an `AsyncLoading` with a value) → none.
  - **Dashboard:**
    - `an unseen tip set is offered to the Buddy`: after the load, `buddyProvider` has `tipsArrived` pending.
    - `repeated offers queue it once`: bump `entriesRevisionProvider` three times (the insights recompute) → still one `weeklyTipsOffer` pending.
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4:** Run `flutter test test/providers test/screens/dashboard`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(buddy): new tips and the weekly-tips offer join the Buddy's announcements`

---

### Task 11: The Buddy says „Neue Tipps sind da!" and offers weekly tips

**Files:**
- Modify: `lib/screens/dashboard/widgets/buddy_hero.dart`
- Create: `lib/screens/dashboard/widgets/weekly_tips_offer_sheet.dart`
- Test:
  - `test/screens/dashboard/widgets/buddy_hero_test.dart` (the harness adds `unseenTipSetProvider` and `weeklyTipsEnabledProvider` overrides, default `null`/`false`, plus stub routes for `/discover`)
  - `test/screens/dashboard/widgets/weekly_tips_offer_sheet_test.dart`

**Interfaces:**
- Consumes: the `BuddyAnnouncement` kinds (Task 10), `unseenTipSetProvider`, `weeklyTipsEnabledProvider`, `WeeklyTipsSwitch.sentence`.
- Produces:
  - `_Cue.tipsArrived(BuddyAnnouncement.tipsArrived)`, `_Cue.weeklyTipsOffer(BuddyAnnouncement.weeklyTipsOffer)`.
  - `Future<bool> showWeeklyTipsOfferSheet(BuildContext context)`. It returns true for „Zu den Tipps". It is shown with `useRootNavigator: true`, in the layout of `showStreakGoalSheet`: drag handle, a `BuddyStage` (height `AppConstants.streakSheetBuddyHeight`) whose Buddy says `WeeklyTipsOfferSheet.line`, the body, then the buttons.
    - Keys: `WeeklyTipsOfferSheet.openKey = Key('weekly_tips_offer_open')`, `laterKey = Key('weekly_tips_offer_later')`.
    - Copy:
      - `line = 'Ich seh schon erste Muster! Magst du jeden Montag Tipps von mir? ✨'`;
      - `body = 'Unter Entdecken kannst du sie einschalten. ${WeeklyTipsSwitch.sentence}'`;
      - buttons `BbButton('Zu den Tipps')` and `TextButton('Später')`.

**Cues:**
- **`tipsArrived`:**
  - when `ref.read(unseenTipSetProvider) == null` at its start: skip (go straight to `_nextCue()`, which marks it shown);
  - otherwise `BuddyAction.celebrate` + `'Neue Tipps sind da! ✨'`, held for `_cueLineDuration`.
- **`weeklyTipsOffer`:**
  - when `ref.read(weeklyTipsEnabledProvider) == true`: skip, the same way;
  - otherwise `BuddyAction.wave`; after `buddyActionDuration(wave)`, open the sheet;
  - true → `context.go(RoutePaths.discover)`; then `_nextCue()`.
  - Hidden when the sheet is due: it waits until visible. Generalize `_goalSheetDeferred` into one deferred sheet callback used by both `_askForNewGoal` and the offer.

- [ ] **Step 1: Failing tests.**
  - **Hero:**
    - `tipsArrived → celebrate and „Neue Tipps sind da! ✨"; marked shown once played`: the same shape as the `saverUsed` test.
    - `tipsArrived whose set was seen before it played says nothing`: `unseenTipSetProvider` null → the bubble never shows the line, and `buddy.shown == [tipsArrived]`.
    - `weeklyTipsOffer → wave, then the sheet; „Zu den Tipps" opens Entdecken`: location `/discover`, `buddy.shown == [weeklyTipsOffer]`.
    - `„Später" stays on Home and marks it shown`.
    - `skipped when already on`: `weeklyTipsEnabledProvider` true → no sheet, marked shown.
    - `the offer sheet waits while the hero is hidden`: the same shape as `goal sheet waits while the hero is hidden`.
    - `the goal sheet still waits while hidden`: the existing test stays green after the generalization.
  - **Sheet:**
    - `shows the line, the sentence and both buttons`;
    - `fits 375×667 at text scale 1.3`.
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4:** Run `flutter test test/screens/dashboard test/utils/vocabulary_test.dart`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(buddy): „Neue Tipps sind da!" and a one-time offer of weekly tips`

---

### Task 12: Integration flow and the stage check

**Files:**
- Modify: `integration_test/helpers/test_app.dart`:
  - override `knowledgeRepositoryProvider` with `FakeKnowledgeRepository(articles: testKnowledgeArticles())`;
  - new params `FakeRecommendationRepository? recommendationRepo` and `bool weeklyTipsEnabled = false`, applied to the seeded profile.
- Modify: `integration_test/insights_flow_test.dart` (its unlocked case passes `weeklyTipsEnabled: true`, so no offer covers the card)
- Create: `integration_test/discover_flow_test.dart`

**Flows (`discover_flow_test.dart`):**
1. **Wissen:**
   - Entdecken → the Wissen section shows 3 articles → `'Alle ›'` → chips `Alle`, `Gesund verdauen`, `Rezepte`, `Persönliches`;
   - tap `Rezepte` → only the recipe article;
   - tap the Entdecken tab → back on Entdecken, and the bar is visible.
2. **Opt-in:**
   - Entdecken shows `WeeklyTipsSwitch` → flip it → `DiscoverTipsSection.emptyWhileOn` shows;
   - Ich → Einstellungen → Benachrichtigungen → „Wöchentliche Tipps" is on, and „Tipps per Push" is present.
3. **New tips:**
   - `FakeRecommendationRepository(sets: [testRecommendation(seenAt: null, createdAt: <this Monday>)])` → Home shows `TipsRow.rowKey`, and the Entdecken dot shows;
   - tap the row → the Tipps → back → no row, no dot.
4. **Offer:** the unlocked insight source from `insights_flow_test` (move `_unlockedSource` to `test_app.dart` as `unlockedInsightSource()`) with weekly tips off → the offer sheet appears → `'Zu den Tipps'` → Entdecken with the switch.

- [ ] **Step 1:** Write the flows and the helper changes.
- [ ] **Step 2:** Run `dart format .`, `flutter analyze` (0 issues) and the full `flutter test`. Expected: all pass.
- [ ] **Step 3: Only on the iPhone Air**, one file at a time:
  ```bash
  SIM=CB1F6232-482F-408F-ADF4-89FDA602E6A8
  xcrun simctl boot $SIM || true
  for f in discover_flow_test insights_flow_test tutorial_flow_test recipes_flow_test auth_flow_test meal_tracking_flow_test; do
    flutter test integration_test/$f.dart -d $SIM --dart-define-from-file=env.json; echo "EXIT $? $f"
  done
  xcrun simctl shutdown $SIM
  ```
  Expected: every file `EXIT 0`. If a case fails, run that same file on the base commit (`git stash` is shared; use a temporary worktree) before calling it pre-existing.
- [ ] **Step 4: Commit** `test(integration): Wissen, the weekly-tips opt-in, new tips and the offer`

---

### Task 13 (ships only after core #9 is deployed; droppable): emoji-sized Buddy names and `ensure_ingredient`

Core PR #9 (migration 0011) makes two changes. `buddy_state.name` takes 1–100 code points. `public.ensure_ingredient(p_name text) returns uuid` replaces the app's pre-check + insert:
- `EXECUTE` is granted to `authenticated` only;
- the name is trimmed and must be 1–200 characters, otherwise 22023;
- it returns the id of a readable match, ignoring case, or of the row it created, or of a hidden row holding the exact name;
- it never raises 23505;
- before core #9 is live, the call fails with PGRST202.

Keep this task as two separate commits at the end of the branch, so it can be reverted cleanly.

**Files:**
- Modify: `lib/config/constants.dart`, `lib/utils/buddy_name.dart` (docs only), `lib/services/ingredient_service.dart`
- Test:
  - `test/utils/buddy_reactions_test.dart`
  - `test/screens/registration/buddy_name_step_test.dart`
  - `test/screens/me/me_screen_test.dart`
  - `test/services/ingredient_service_test.dart`

**Interfaces:**
- Produces:
  - `AppConstants.buddyNameMaxCodePoints = 100`. Its doc now says the check counts code points up to 100 (core 0011). `buddyNameMaxLength` stays 20 graphemes. `BuddyNameRules.tooManySymbols` still covers > 100 code points within 20 graphemes.
  - `IngredientService.insertIfNew(String name, {required String? userId})` keeps its signature and its early return for `userId == null`. Otherwise it is `await _client.rpc('ensure_ingredient', params: {'p_name': name})`. It ignores the returned id, logs and rethrows errors (the caller, `IngredientAutocompleteNotifier.addIngredient`, is best effort), and drops the `ilike` pre-check, the insert and the 23505 handling.

- [ ] **Step 1: Failing tests.**
  - **Names:**
    - `isValidBuddyName`: `'❤️' * 20` → true (40 code points);
    - 14 family emojis `'👨‍👩‍👧‍👦' * 14` → true (98);
    - 15 → false (105).
  - **Registration step:**
    - `a name the database cannot store yet says why` uses 15 family emojis → `tooManySymbols`;
    - 11 hearts are now valid.
  - **Ich:** `rename saves 20 hearts` → `setName` is called with them.
  - **Ingredients:** replace the `insertIfNew` groups with:
    - `calls ensure_ingredient with the name`: `verify(() => client.rpc('ensure_ingredient', params: {'p_name': 'Zwiebel'}))`, and `client.from` is never called;
    - `no user: no call`;
    - `errors surface`: a `PostgrestException(code: '22023')` is rethrown.
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4:** Run `flutter test test/utils test/screens/registration test/screens/me test/services/ingredient_service_test.dart test/providers/ingredient_autocomplete_provider_test.dart`. Expected: PASS. Also run `integration_test/registration_flow_test.dart` on the iPhone Air as in Task 12.
- [ ] **Step 5: Commits**
  - `fix(buddy): names of up to 20 emojis fit (core 0011 counts 100 code points)`
  - `refactor(ingredients): add typed ingredients through ensure_ingredient`

---

## Self-Review notes

**Spec coverage:**

| Spec section | Task(s) |
|---|---|
| §5.6.1 opt-in off by default, switch + sentence on the Tipps card | 5, 6 |
| §5.6.1 the same switch in Settings, separate from the push toggle | 6 |
| §5.6.1 the Buddy offers it once after the unlock | 10, 11 |
| §5.6.1 earlier tips stay visible; empty state when on | 6 |
| §5.6.4 RSS in the app, all categories, filter „Alle" + categories | 1, 3 |
| §5.6.4 title, category, date, image; in-app browser | 3 |
| §5.6.4 6 h cache, loading/error, last copy offline; `xml` justified | 1, 2, 3 |
| §5.3 item 5 tips row + „Neue Tipps sind da! ✨" once | 9, 10, 11 |
| §5.6 Badge | 7, 8 |
| §5.9 new copy | 6, 9, 11, guarded by `vocabulary_test` |
| Settings rename „Tipps per Push" | 6 |
| Core #9 follow-ups | 13 |

§5.7 (migration 0009, the job) is core PR #7. The app reads `weekly_tips_enabled` with the profile and writes it alone (Task 5).

**Interfaces across tasks:**
- `KnowledgeArticle`/`KnowledgeFeed`/`parseKnowledgeFeed` (T1 → T2–T4);
- `knowledgeFeedProvider`, `FakeKnowledgeRepository`, `testKnowledgeArticles` (T2 → T3, T4, T12);
- `openArticle`, `KnowledgeArticleTile`, `RoutePaths.knowledge` (T3 → T4, T12);
- `weeklyTipsEnabledProvider`, `ProfileNotifier.setWeeklyTips` (T5 → T6, T10, T11);
- `WeeklyTipsSwitch`, `DiscoverTipsSection.emptyWhileOn` (T6 → T11, T12);
- `unseenTipSetProvider`, `discoverNewsProvider` (T7 → T8–T11);
- `discoverBadgeProvider`, `BbBottomNav.discoverBadgeKey` (T8 → T12);
- `TipsRow.rowKey` (T9 → T12);
- `BuddyAnnouncement.tipsArrived`/`weeklyTipsOffer`, `offerAnnouncement` (T10 → T11).

**Known, accepted:**
- `notificationSyncProvider` re-syncs local reminders on any profile change, including the opt-in. This is harmless and unchanged.
- `IngredientService.fetchNewCount` stays unused (pre-existing).
