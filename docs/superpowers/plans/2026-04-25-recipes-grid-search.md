# Recipes grid + search — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the row-based recipes list with a 2-column image grid, pin a search bar above it, and back search with Postgres full-text search on `user_recipes`.

**Architecture:** New `RecipeCard` widget (image OR pastel-monogram fallback), new `RecipesSearchField` widget, new `pastelForTitle` helper. `UserRecipeService` gains `searchForUser` using a `tsvector` generated column + GIN index. `UserRecipesNotifier` gains a debounced `setQuery` that branches `fetch` between `fetchForUser` and `searchForUser`. `MyRecipesTab` becomes `Column([SearchField, Expanded(GridView.builder)])`. `RecipeListTile` is deleted.

**Tech Stack:** Flutter, Riverpod, Supabase (Postgres `tsvector` + GIN), Freezed/json_serializable.

**Spec:** `docs/superpowers/specs/2026-04-25-recipes-grid-search-design.md`

**Branch:** `feat/recipes-grid-search` (off `feat/user-recipes`). Spec doc already committed.

**Note on data layer state:** `feat/user-recipes` has the full data layer (model, service, repo, provider) and `MyRecipesTab` already wired. This plan extends those pieces, not replaces them.

---

## File structure

New (5):
- `lib/utils/title_color.dart` — `Color pastelForTitle(String title)`.
- `lib/screens/recipes/widgets/recipe_card.dart` — grid card.
- `lib/screens/recipes/widgets/recipes_search_field.dart` — search bar.
- `supabase/migrations/20260425120000_user_recipes_fts.sql` — `tsvector` column + index.
- Tests: `test/utils/title_color_test.dart`, `test/screens/recipes/widgets/recipe_card_test.dart`, `test/screens/recipes/widgets/recipes_search_field_test.dart`.

Modified (5):
- `lib/services/user_recipe_service.dart` — `searchForUser` + `_buildTsQuery`.
- `lib/repositories/user_recipe_repository.dart` — `searchForUser` delegation.
- `lib/providers/user_recipes_provider.dart` — `_query`, `setQuery`, debounced timer, branched `fetch`.
- `lib/screens/recipes/my_recipes_tab.dart` — `Column` with search field + `GridView.builder`.
- `lib/screens/trackers/meal/widgets/recipe_selector_sheet.dart` — drop the `RecipeListTile` import; inline a `ListTile` row with `SignedPathImage` thumbnail.

Deleted (2):
- `lib/screens/recipes/widgets/recipe_list_tile.dart`
- `test/screens/recipes/widgets/recipe_list_tile_test.dart`

Tests touched (existing):
- `test/screens/recipes/my_recipes_tab_test.dart` — update for grid + search.
- `test/screens/trackers/meal/widgets/recipe_selector_sheet_test.dart` — update if the inline `ListTile` swap breaks finders.
- `test/providers/user_recipes_provider_test.dart` — add `setQuery` cases.
- `test/services/user_recipe_service_test.dart` — add `_buildTsQuery` cases.

---

## Phase 1 — Data layer (search + provider)

Delivers: working `searchForUser` end-to-end, debounced `setQuery` on the provider. UI still renders the old list — Phase 2 redesigns.

### Task 1: Migration — `tsvector` generated column + GIN index

**Files:**
- Create: `supabase/migrations/20260425120000_user_recipes_fts.sql`

- [ ] **Step 1: Write the migration**

```sql
-- Postgres FTS over user_recipes: stored generated tsvector + GIN index.
-- 'german' config covers stemming + stopwords for the app's UI language.

alter table user_recipes
  add column search_tsv tsvector
  generated always as (
    to_tsvector(
      'german',
      coalesce(title, '') || ' ' || coalesce(array_to_string(ingredients, ' '), '')
    )
  ) stored;

create index user_recipes_search_tsv_idx
  on user_recipes using gin (search_tsv);
```

- [ ] **Step 2: Apply locally if you have Supabase running**

Run: `supabase db reset` (or `supabase migration up`).
Expected: applies without error. Skip this step if no local stack.

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/20260425120000_user_recipes_fts.sql
git commit -m "$(cat <<'EOF'
feat(db): add tsvector + GIN index on user_recipes for FTS

Generated column search_tsv covers title + ingredients (joined) with
the german text-search config. GIN index over the column. No app-side
trigger maintenance — Postgres rewrites on every write.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task 2: `UserRecipeService.searchForUser` + `_buildTsQuery` (TDD)

**Files:**
- Modify: `lib/services/user_recipe_service.dart`
- Modify: `test/services/user_recipe_service_test.dart`

- [ ] **Step 1: Write the failing tests**

Append to `test/services/user_recipe_service_test.dart` inside its existing `main()`:

```dart
  group('UserRecipeService._buildTsQuery (via @visibleForTesting)', () {
    test('blank query returns empty string', () {
      expect(UserRecipeService.buildTsQuery(''), '');
      expect(UserRecipeService.buildTsQuery('   '), '');
    });

    test('single token gets prefix wildcard', () {
      expect(UserRecipeService.buildTsQuery('kart'), 'kart:*');
    });

    test('multi-token query joins with & and prefixes each', () {
      expect(UserRecipeService.buildTsQuery('curry reis'), 'curry:* & reis:*');
    });

    test('extra whitespace between tokens is collapsed', () {
      expect(UserRecipeService.buildTsQuery('  curry   reis  '), 'curry:* & reis:*');
    });
  });
```

The test calls `UserRecipeService.buildTsQuery(query)` as a static — we expose a `@visibleForTesting` static method so this is unit-testable without touching Supabase.

- [ ] **Step 2: Run, expect failure**

Run: `flutter test test/services/user_recipe_service_test.dart`
Expected: FAIL — `The getter 'buildTsQuery' isn't defined for the type 'UserRecipeService'`.

- [ ] **Step 3: Add `searchForUser` + `buildTsQuery` to the service**

Add to `lib/services/user_recipe_service.dart` (place `buildTsQuery` near the bottom, `searchForUser` next to `fetchForUser`):

```dart
import 'package:meta/meta.dart';

// ... existing imports + class declaration ...

  Future<List<UserRecipe>> searchForUser(String userId, String query) async {
    final tsQuery = buildTsQuery(query);
    if (tsQuery.isEmpty) return fetchForUser(userId);
    try {
      final data = await _client
          .from(_table)
          .select()
          .eq('user_id', userId)
          .textSearch('search_tsv', tsQuery, config: 'german')
          .order('created_at', ascending: false);
      return (data as List)
          .map((e) => UserRecipe.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      _log.error('searchForUser failed', e, st);
      rethrow;
    }
  }

  /// Converts a free-form user query into a tsquery string with prefix-match
  /// per token (`token:*`) joined by `&` so multi-word queries narrow.
  /// Exposed for tests; not part of the public API.
  @visibleForTesting
  static String buildTsQuery(String query) {
    final tokens = query
        .trim()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return '';
    return tokens.map((t) => '$t:*').join(' & ');
  }
```

If `meta` isn't already imported and the analyzer flags it as `depend_on_referenced_packages`, drop the `@visibleForTesting` annotation and rely on the public-by-Dart-convention nature of the static — the test still works against `UserRecipeService.buildTsQuery`.

- [ ] **Step 4: Run, expect pass**

Run: `flutter test test/services/user_recipe_service_test.dart`
Expected: PASS (4 new tests + the 1 existing construction test).

- [ ] **Step 5: Analyzer**

Run: `flutter analyze lib/services/user_recipe_service.dart test/services/user_recipe_service_test.dart`
Expected: `No issues found!`. If the `meta` annotation surfaces a lint, drop it per Step 3's note.

- [ ] **Step 6: Commit**

```bash
git add lib/services/user_recipe_service.dart test/services/user_recipe_service_test.dart
git commit -m "$(cat <<'EOF'
feat(services): UserRecipeService.searchForUser

Calls Postgres FTS (.textSearch on search_tsv with the german config).
buildTsQuery (static, unit-tested) splits on whitespace, prefix-tags
each token (':*'), joins with '&'. Empty query falls back to
fetchForUser.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task 3: Repository delegation (TDD)

**Files:**
- Modify: `lib/repositories/user_recipe_repository.dart`
- Modify: `test/repositories/user_recipe_repository_test.dart`

- [ ] **Step 1: Write the failing test**

Append to `test/repositories/user_recipe_repository_test.dart`:

```dart
  group('searchForUser', () {
    test('delegates to service', () async {
      final recipes = [testUserRecipe()];
      when(() => service.searchForUser(any(), any()))
          .thenAnswer((_) async => recipes);

      final result = await repo.searchForUser('user-1', 'curry');

      expect(result, recipes);
      verify(() => service.searchForUser('user-1', 'curry')).called(1);
    });
  });
```

The mock setup needs `MockUserRecipeService` to know about `searchForUser`. mocktail is dynamic — no extra setup needed. If `verify` fails to match because the new method wasn't stubbed, the test framework will say so.

- [ ] **Step 2: Run, expect failure**

Run: `flutter test test/repositories/user_recipe_repository_test.dart`
Expected: FAIL — `The method 'searchForUser' isn't defined for the type 'UserRecipeRepository'`.

- [ ] **Step 3: Add the method**

Append in `lib/repositories/user_recipe_repository.dart` after `fetchForUser`:

```dart
  Future<List<UserRecipe>> searchForUser(String userId, String query) =>
      _service.searchForUser(userId, query);
```

- [ ] **Step 4: Run, expect pass**

Run: `flutter test test/repositories/user_recipe_repository_test.dart`
Expected: PASS (existing 4 + new 1).

- [ ] **Step 5: Commit**

```bash
git add lib/repositories/user_recipe_repository.dart test/repositories/user_recipe_repository_test.dart
git commit -m "$(cat <<'EOF'
feat(repositories): UserRecipeRepository.searchForUser

Single-line delegation to UserRecipeService.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task 4: Provider — `setQuery` + branched `fetch` (TDD)

**Files:**
- Modify: `lib/providers/user_recipes_provider.dart`
- Modify: `test/providers/user_recipes_provider_test.dart`

- [ ] **Step 1: Write the failing tests**

Append to `test/providers/user_recipes_provider_test.dart` inside its existing `main()`:

```dart
  group('setQuery + search branch', () {
    test('setQuery with a non-empty value triggers searchForUser after debounce', () async {
      when(() => repo.fetchForUser(any())).thenAnswer((_) async => []);
      when(() => repo.searchForUser(any(), any()))
          .thenAnswer((_) async => [testUserRecipe(title: 'Curry mit Reis')]);

      final container = makeContainer();
      await container.read(userRecipesProvider.notifier).fetch();

      container.read(userRecipesProvider.notifier).setQuery('curry');

      // Wait past the 300ms debounce.
      await Future<void>.delayed(const Duration(milliseconds: 350));

      verify(() => repo.searchForUser(testUserId, 'curry')).called(1);
      expect(
        container.read(userRecipesProvider).value?.first.title,
        'Curry mit Reis',
      );
    });

    test('setQuery with empty / whitespace value clears the search', () async {
      when(() => repo.fetchForUser(any())).thenAnswer((_) async => []);

      final container = makeContainer();
      await container.read(userRecipesProvider.notifier).fetch();
      reset(repo);
      when(() => repo.fetchForUser(any())).thenAnswer((_) async => []);

      container.read(userRecipesProvider.notifier).setQuery('curry');
      container.read(userRecipesProvider.notifier).setQuery('');
      await Future<void>.delayed(const Duration(milliseconds: 350));

      // Empty query falls back to fetchForUser, not searchForUser.
      verify(() => repo.fetchForUser(testUserId)).called(1);
      verifyNever(() => repo.searchForUser(any(), any()));
    });

    test('rapid calls only fire the last value (debounce)', () async {
      when(() => repo.fetchForUser(any())).thenAnswer((_) async => []);
      when(() => repo.searchForUser(any(), any())).thenAnswer((_) async => []);

      final container = makeContainer();
      await container.read(userRecipesProvider.notifier).fetch();

      final notifier = container.read(userRecipesProvider.notifier);
      notifier.setQuery('c');
      notifier.setQuery('cu');
      notifier.setQuery('cur');
      await Future<void>.delayed(const Duration(milliseconds: 350));

      verify(() => repo.searchForUser(testUserId, 'cur')).called(1);
      verifyNever(() => repo.searchForUser(testUserId, 'c'));
      verifyNever(() => repo.searchForUser(testUserId, 'cu'));
    });

    test('identical query is a no-op', () async {
      when(() => repo.fetchForUser(any())).thenAnswer((_) async => []);
      when(() => repo.searchForUser(any(), any())).thenAnswer((_) async => []);

      final container = makeContainer();
      await container.read(userRecipesProvider.notifier).fetch();

      container.read(userRecipesProvider.notifier).setQuery('curry');
      await Future<void>.delayed(const Duration(milliseconds: 350));
      reset(repo);
      when(() => repo.searchForUser(any(), any())).thenAnswer((_) async => []);

      container.read(userRecipesProvider.notifier).setQuery('curry');
      await Future<void>.delayed(const Duration(milliseconds: 350));

      verifyNever(() => repo.searchForUser(any(), any()));
    });
  });
```

- [ ] **Step 2: Run, expect failure**

Run: `flutter test test/providers/user_recipes_provider_test.dart`
Expected: FAIL — `setQuery` is not defined.

- [ ] **Step 3: Add `_query` + `setQuery` + branch `fetch`**

In `lib/providers/user_recipes_provider.dart`, add the timer field, the `setQuery` method, and update `fetch` to branch on `_query`:

```dart
import 'dart:async';

// ... existing imports ...

class UserRecipesNotifier extends Notifier<AsyncValue<List<UserRecipe>>> {
  static const _log = AppLogger('UserRecipesNotifier');
  static const _debounceDuration = Duration(milliseconds: 300);

  String? _query;
  Timer? _debounce;

  @override
  AsyncValue<List<UserRecipe>> build() {
    ref.onDispose(() => _debounce?.cancel());
    return const AsyncValue.loading();
  }

  /// Sets the active search query. Empty / whitespace-only values clear it
  /// and the next fetch falls back to the unfiltered list. Calls debounce
  /// for [_debounceDuration]; identical queries are a no-op.
  void setQuery(String? q) {
    final next = (q == null || q.trim().isEmpty) ? null : q.trim();
    if (_query == next) return;
    _query = next;
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, () {
      fetch(force: true);
    });
  }

  Future<void> fetch({bool force = false}) async {
    if (state.hasValue && !force) return;
    if (!state.hasValue) {
      state = const AsyncValue.loading();
    }
    try {
      final userId = ref.read(currentUserIdProvider);
      if (userId == null) {
        state = const AsyncValue.data([]);
        return;
      }
      final repo = ref.read(userRecipeRepositoryProvider);
      final query = _query;
      final recipes = (query == null)
          ? await repo.fetchForUser(userId)
          : await repo.searchForUser(userId, query);
      state = AsyncValue.data(recipes);
    } catch (e, st) {
      _log.error('fetch failed', e, st);
      state = AsyncValue.error(e, st);
    }
  }

  // ... existing create / update / delete methods, unchanged ...
}
```

Confirm `create` / `update` / `delete` already pass `force: true` (they do, from the prior perf fix). No change needed there.

- [ ] **Step 4: Run, expect pass**

Run: `flutter test test/providers/user_recipes_provider_test.dart`
Expected: PASS.

- [ ] **Step 5: Analyzer**

Run: `flutter analyze lib/providers/user_recipes_provider.dart`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/providers/user_recipes_provider.dart test/providers/user_recipes_provider_test.dart
git commit -m "$(cat <<'EOF'
feat(providers): debounced setQuery + searchForUser branch on fetch

UserRecipesNotifier now holds an optional _query plus a 300ms debounce
timer; setQuery cancels and rearms. fetch() branches on _query and
calls either repo.fetchForUser or repo.searchForUser. Identical queries
are no-ops. Timer is cancelled in build()'s ref.onDispose.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Phase 2 — Pastel helper + RecipeCard

### Task 5: `pastelForTitle` helper (TDD)

**Files:**
- Create: `lib/utils/title_color.dart`
- Create: `test/utils/title_color_test.dart`

- [ ] **Step 1: Write the failing test**

`test/utils/title_color_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/utils/title_color.dart';

void main() {
  group('pastelForTitle', () {
    test('is deterministic across calls for the same input', () {
      expect(pastelForTitle('Curry mit Reis'), pastelForTitle('Curry mit Reis'));
    });

    test('produces different colors for different titles', () {
      final a = pastelForTitle('Curry mit Reis');
      final b = pastelForTitle('Pizza Margherita');
      expect(a, isNot(equals(b)));
    });

    test('handles the empty string without throwing', () {
      expect(() => pastelForTitle(''), returnsNormally);
      expect(pastelForTitle(''), isA<Color>());
    });
  });
}
```

- [ ] **Step 2: Run, expect failure**

Run: `flutter test test/utils/title_color_test.dart`
Expected: FAIL — URI not found.

- [ ] **Step 3: Create the helper**

`lib/utils/title_color.dart`:
```dart
import 'package:flutter/material.dart';

/// Deterministic light-pastel color derived from a title's hash. Saturation
/// and lightness are fixed so all returned colors sit in the same visual
/// register — only the hue varies. Used as an image fallback in recipe cards.
Color pastelForTitle(String title) {
  final hash = title.hashCode.abs();
  final hue = (hash % 360).toDouble();
  return HSLColor.fromAHSL(1, hue, 0.45, 0.86).toColor();
}
```

- [ ] **Step 4: Run, expect pass**

Run: `flutter test test/utils/title_color_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/utils/title_color.dart test/utils/title_color_test.dart
git commit -m "$(cat <<'EOF'
feat(utils): pastelForTitle deterministic pastel color

Hash → hue → fixed-S/L pastel via HSLColor. Used as the image fallback
in recipe cards so missing thumbnails read as decorative tiles instead
of broken-image placeholders.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task 6: `RecipeCard` widget (TDD)

**Files:**
- Create: `lib/screens/recipes/widgets/recipe_card.dart`
- Create: `test/screens/recipes/widgets/recipe_card_test.dart`

- [ ] **Step 1: Write the failing test**

`test/screens/recipes/widgets/recipe_card_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/screens/recipes/widgets/recipe_card.dart';

import '../../../helpers/fakes.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: SizedBox(width: 200, height: 280, child: child)),
        ),
      ),
    );
  }

  testWidgets('renders title and ingredients line', (tester) async {
    final recipe = testUserRecipe(
      title: 'Curry mit Reis',
      ingredients: const ['Reis', 'Curry', 'Kokosmilch', 'Zwiebel'],
    );
    await pump(tester, RecipeCard(recipe: recipe, onTap: () {}));

    expect(find.text('Curry mit Reis'), findsOneWidget);
    expect(find.textContaining('Reis · Curry · Kokosmilch'), findsOneWidget);
    expect(find.textContaining('Zwiebel'), findsNothing);
  });

  testWidgets('renders pastel monogram when imageUrl is null', (tester) async {
    final recipe = testUserRecipe(title: 'Pasta', imageUrl: null);
    await pump(tester, RecipeCard(recipe: recipe, onTap: () {}));

    // Title's first letter, uppercased.
    expect(find.text('P'), findsOneWidget);
  });

  testWidgets('tap fires onTap', (tester) async {
    var tapped = false;
    final recipe = testUserRecipe();
    await pump(tester, RecipeCard(recipe: recipe, onTap: () => tapped = true));

    await tester.tap(find.byType(RecipeCard));
    expect(tapped, isTrue);
  });

  testWidgets('falls back to "?" monogram for empty title', (tester) async {
    final recipe = testUserRecipe(title: '', imageUrl: null);
    await pump(tester, RecipeCard(recipe: recipe, onTap: () {}));

    expect(find.text('?'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run, expect failure**

Run: `flutter test test/screens/recipes/widgets/recipe_card_test.dart`
Expected: FAIL — URI not found.

- [ ] **Step 3: Create the widget**

`lib/screens/recipes/widgets/recipe_card.dart`:
```dart
import 'package:flutter/material.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../models/user_recipe.dart';
import '../../../utils/title_color.dart';
import '../../../widgets/common/signed_path_image.dart';

class RecipeCard extends StatelessWidget {
  const RecipeCard({super.key, required this.recipe, required this.onTap});

  final UserRecipe recipe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = recipe.ingredients.take(3).join(' · ');
    return Material(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1.1,
              child: _Image(recipe: recipe),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingMd,
                vertical: AppConstants.spacingSm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.title.isEmpty ? 'Ohne Namen' : recipe.title,
                    style: const TextStyle(
                      fontSize: AppTheme.fontSizeBody,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.foreground,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle.isNotEmpty) ...[
                    AppConstants.gap4,
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: AppTheme.fontSizeCaption,
                        color: AppTheme.mutedForeground,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Image extends StatelessWidget {
  const _Image({required this.recipe});
  final UserRecipe recipe;

  @override
  Widget build(BuildContext context) {
    if (recipe.imageUrl == null || recipe.imageUrl!.isEmpty) {
      return _PastelMonogram(title: recipe.title);
    }
    return SignedPathImage(
      pathOrUrl: recipe.imageUrl,
      placeholder: _PastelMonogram(title: recipe.title),
      errorWidget: _PastelMonogram(title: recipe.title),
    );
  }
}

class _PastelMonogram extends StatelessWidget {
  const _PastelMonogram({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final letter = title.isEmpty ? '?' : title.characters.first.toUpperCase();
    return Container(
      color: pastelForTitle(title),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          fontSize: AppTheme.fontSizeTitleLG,
          fontWeight: FontWeight.w300,
          color: AppTheme.foreground.withValues(alpha: 0.45),
        ),
      ),
    );
  }
}
```

Note: this uses `String.characters.first` from `package:characters` (Dart's grapheme-cluster API). It's already a Flutter SDK transitive dependency — no new package required.

- [ ] **Step 4: Run, expect pass**

Run: `flutter test test/screens/recipes/widgets/recipe_card_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Analyzer**

Run: `flutter analyze lib/screens/recipes/widgets/recipe_card.dart`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/screens/recipes/widgets/recipe_card.dart test/screens/recipes/widgets/recipe_card_test.dart
git commit -m "$(cat <<'EOF'
feat(recipes): RecipeCard widget for the grid layout

1.1:1 image (SignedPathImage or pastel monogram fallback) on top, title
+ first 3 ingredients underneath, full-card InkWell. Empty titles fall
back to a '?' monogram.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Phase 3 — Search field + grid wiring + cleanup

### Task 7: `RecipesSearchField` widget (TDD)

**Files:**
- Create: `lib/screens/recipes/widgets/recipes_search_field.dart`
- Create: `test/screens/recipes/widgets/recipes_search_field_test.dart`

- [ ] **Step 1: Write the failing test**

`test/screens/recipes/widgets/recipes_search_field_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/user_recipes_provider.dart';
import 'package:belly_buddy/screens/recipes/widgets/recipes_search_field.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/mocks.dart';

void main() {
  late MockUserRecipeRepository repo;

  setUp(() {
    repo = MockUserRecipeRepository();
    when(() => repo.fetchForUser(any())).thenAnswer((_) async => []);
    when(() => repo.searchForUser(any(), any())).thenAnswer((_) async => []);
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userRecipeRepositoryProvider.overrideWithValue(repo),
          currentUserIdProvider.overrideWithValue(testUserId),
        ],
        child: const MaterialApp(
          home: Scaffold(body: RecipesSearchField()),
        ),
      ),
    );
  }

  testWidgets('typing pushes the query to the provider after debounce', (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'curry');
    await tester.pump(const Duration(milliseconds: 350));

    verify(() => repo.searchForUser(testUserId, 'curry')).called(1);
  });

  testWidgets('clear icon appears when text is non-empty and clears on tap', (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'curry');
    await tester.pump();

    final clear = find.byIcon(Icons.clear);
    expect(clear, findsOneWidget);

    await tester.tap(clear);
    await tester.pump();
    expect(find.text('curry'), findsNothing);
  });
}
```

- [ ] **Step 2: Run, expect failure**

Run: `flutter test test/screens/recipes/widgets/recipes_search_field_test.dart`
Expected: FAIL — URI not found.

- [ ] **Step 3: Create the widget**

`lib/screens/recipes/widgets/recipes_search_field.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../providers/user_recipes_provider.dart';

class RecipesSearchField extends ConsumerStatefulWidget {
  const RecipesSearchField({super.key});

  @override
  ConsumerState<RecipesSearchField> createState() =>
      _RecipesSearchFieldState();
}

class _RecipesSearchFieldState extends ConsumerState<RecipesSearchField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    ref.read(userRecipesProvider.notifier).setQuery(null);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _controller.text.isNotEmpty;
    return TextField(
      controller: _controller,
      decoration: InputDecoration(
        hintText: 'Rezept suchen…',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: hasText
            ? IconButton(icon: const Icon(Icons.clear), onPressed: _clear)
            : null,
        filled: true,
        fillColor: AppTheme.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusRound),
          borderSide: BorderSide.none,
        ),
        isDense: true,
      ),
      onChanged: (value) {
        ref.read(userRecipesProvider.notifier).setQuery(value);
        setState(() {}); // rebuild to show/hide the clear icon
      },
    );
  }
}
```

- [ ] **Step 4: Run, expect pass**

Run: `flutter test test/screens/recipes/widgets/recipes_search_field_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/screens/recipes/widgets/recipes_search_field.dart test/screens/recipes/widgets/recipes_search_field_test.dart
git commit -m "$(cat <<'EOF'
feat(recipes): RecipesSearchField

Material TextField with rounded fill, search prefix icon, conditional
clear suffix. onChanged → setQuery on the recipes notifier; the
notifier owns the 300ms debounce.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task 8: Rewire `MyRecipesTab` — grid + search field + empty states

**Files:**
- Modify: `lib/screens/recipes/my_recipes_tab.dart`
- Modify: `test/screens/recipes/my_recipes_tab_test.dart`

- [ ] **Step 1: Update the test for the new shape**

Replace the contents of `test/screens/recipes/my_recipes_tab_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/user_recipes_provider.dart';
import 'package:belly_buddy/screens/recipes/my_recipes_tab.dart';
import 'package:belly_buddy/screens/recipes/widgets/recipe_card.dart';
import 'package:belly_buddy/screens/recipes/widgets/recipes_search_field.dart';

import '../../helpers/fakes.dart';
import '../../helpers/mocks.dart';

void main() {
  late MockUserRecipeRepository repo;

  setUp(() {
    repo = MockUserRecipeRepository();
  });

  Future<void> pump(WidgetTester tester, {required List recipes}) async {
    when(() => repo.fetchForUser(any())).thenAnswer((_) async => recipes.cast());
    when(() => repo.searchForUser(any(), any()))
        .thenAnswer((_) async => recipes.cast());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userRecipeRepositoryProvider.overrideWithValue(repo),
          currentUserIdProvider.overrideWithValue(testUserId),
        ],
        child: const MaterialApp(
          home: Scaffold(body: MyRecipesTab()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows empty-state CTA when there are no recipes', (tester) async {
    await pump(tester, recipes: const []);
    expect(find.text('Noch keine Rezepte'), findsOneWidget);
    expect(find.text('Erstes Rezept erstellen'), findsOneWidget);
    expect(find.byType(RecipeCard), findsNothing);
    expect(find.byType(RecipesSearchField), findsNothing);
  });

  testWidgets('shows search field + grid when recipes exist', (tester) async {
    final recipes = [
      testUserRecipe(id: 'a', title: 'Curry'),
      testUserRecipe(id: 'b', title: 'Pasta'),
    ];
    await pump(tester, recipes: recipes);

    expect(find.byType(RecipesSearchField), findsOneWidget);
    expect(find.byType(RecipeCard), findsNWidgets(2));
    expect(find.byType(GridView), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run, expect failure**

Run: `flutter test test/screens/recipes/my_recipes_tab_test.dart`
Expected: FAIL — `RecipesSearchField` and grid expectations don't match the current implementation (which still renders the old list).

- [ ] **Step 3: Rewrite `MyRecipesTab`**

Open `lib/screens/recipes/my_recipes_tab.dart` and rewrite the data branch as a `Column([RecipesSearchField, Expanded(GridView.builder)])`. Empty state stays unchanged. Replace `RecipeListTile` with `RecipeCard`.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../providers/user_recipes_provider.dart';
import '../../router/route_names.dart';
import '../../widgets/common/mascot_image.dart';
import 'widgets/add_recipe_chooser_sheet.dart';
import 'widgets/recipe_card.dart';
import 'widgets/recipes_search_field.dart';

class MyRecipesTab extends ConsumerStatefulWidget {
  const MyRecipesTab({super.key});

  @override
  ConsumerState<MyRecipesTab> createState() => _MyRecipesTabState();
}

class _MyRecipesTabState extends ConsumerState<MyRecipesTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(userRecipesProvider.notifier).fetch();
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(userRecipesProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const Center(
        child: Text(
          'Konnte Rezepte nicht laden',
          style: TextStyle(
            fontSize: AppTheme.fontSizeBody,
            color: AppTheme.mutedForeground,
          ),
        ),
      ),
      data: (recipes) {
        // Truly empty (no recipes) → mascot CTA, no search bar.
        if (recipes.isEmpty) return const _EmptyState();
        return Column(
          children: [
            const Padding(
              padding: AppConstants.paddingMd,
              child: RecipesSearchField(),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(
                  AppConstants.spacingMd,
                  0,
                  AppConstants.spacingMd,
                  AppConstants.spacingMd,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: AppConstants.spacingSm,
                  mainAxisSpacing: AppConstants.spacingSm,
                  childAspectRatio: 0.78,
                ),
                itemCount: recipes.length,
                itemBuilder: (context, i) {
                  final recipe = recipes[i];
                  return RecipeCard(
                    recipe: recipe,
                    onTap: () =>
                        context.push(RoutePaths.recipeDetailFor(recipe.id)),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingXl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const MascotImage(
              assetPath: AppConstants.mascotWink,
              width: 128,
              height: 128,
            ),
            AppConstants.gap24,
            const Text(
              'Noch keine Rezepte',
              style: TextStyle(
                fontSize: AppTheme.fontSizeTitle,
                fontWeight: FontWeight.w600,
                color: AppTheme.foreground,
              ),
            ),
            AppConstants.gap8,
            const Text(
              'Speichere Mahlzeiten als Rezepte, um sie schnell wieder einzutragen.',
              style: TextStyle(
                fontSize: AppTheme.fontSizeBody,
                color: AppTheme.mutedForeground,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            AppConstants.gap24,
            FilledButton(
              onPressed: () => showAddRecipeChooserSheet(context),
              child: const Text('Erstes Rezept erstellen'),
            ),
          ],
        ),
      ),
    );
  }
}
```

Note: this implementation uses the simpler empty-state model from the spec's fallback path — when `data.isEmpty && _query == null` we show the mascot, otherwise the grid (which will be empty). To get a "Keine Treffer" message for empty search results within recipes the user has, we can extend later by tracking unfiltered count separately. The spec accepts this simpler default; an extension is in the Out of scope.

- [ ] **Step 4: Run tests**

Run: `flutter test test/screens/recipes/my_recipes_tab_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Analyzer**

Run: `flutter analyze lib/screens/recipes/my_recipes_tab.dart`
Expected: clean.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/recipes/my_recipes_tab.dart test/screens/recipes/my_recipes_tab_test.dart
git commit -m "$(cat <<'EOF'
feat(recipes): grid layout + pinned search field on MyRecipesTab

2-column GridView.builder of RecipeCard. RecipesSearchField pinned
above. Truly-empty state still shows mascot + CTA.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task 9: Drop `RecipeListTile`; switch `RecipeSelectorSheet` to inline `ListTile`

**Files:**
- Delete: `lib/screens/recipes/widgets/recipe_list_tile.dart`
- Delete: `test/screens/recipes/widgets/recipe_list_tile_test.dart`
- Modify: `lib/screens/trackers/meal/widgets/recipe_selector_sheet.dart`
- Modify: `test/screens/trackers/meal/widgets/recipe_selector_sheet_test.dart` (only if the existing `find.byType(RecipeListTile)` matchers break)

- [ ] **Step 1: Replace `RecipeListTile` usage in `recipe_selector_sheet.dart`**

Open `lib/screens/trackers/meal/widgets/recipe_selector_sheet.dart`. Replace the import and the `itemBuilder` to use a `ListTile` directly:

Replace the import:
```dart
import '../../../recipes/widgets/recipe_list_tile.dart';
```

with:
```dart
import '../../../../widgets/common/signed_path_image.dart';
import '../../../../config/app_theme.dart';
import '../../../../config/constants.dart';
```
(Adjust path depth so the imports resolve from this file's location; check the existing imports for the canonical relative-path convention.)

Replace the `itemBuilder` body that returned `RecipeListTile(...)` with:
```dart
itemBuilder: (context, i) {
  final recipe = recipes[i];
  final subtitle = recipe.ingredients.take(3).join(' · ');
  return ListTile(
    leading: SizedBox(
      width: AppConstants.iconBadgeXl,
      height: AppConstants.iconBadgeXl,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        child: SignedPathImage(
          pathOrUrl: recipe.imageUrl,
          width: AppConstants.iconBadgeXl,
          height: AppConstants.iconBadgeXl,
          placeholder: Container(color: AppTheme.muted),
          errorWidget: Container(color: AppTheme.muted),
        ),
      ),
    ),
    title: Text(
      recipe.title.isEmpty ? 'Ohne Namen' : recipe.title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
    subtitle: subtitle.isEmpty
        ? null
        : Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
    onTap: () => Navigator.of(context).pop(recipes[i]),
  );
},
```

(If the original sheet wraps the list in a particular separator scheme, preserve that.)

- [ ] **Step 2: Delete `RecipeListTile`**

```bash
rm lib/screens/recipes/widgets/recipe_list_tile.dart
rm test/screens/recipes/widgets/recipe_list_tile_test.dart
```

- [ ] **Step 3: Update `recipe_selector_sheet_test.dart`** (if needed)

Open `test/screens/trackers/meal/widgets/recipe_selector_sheet_test.dart`. If the test uses `find.byType(RecipeListTile)`, change to `find.byType(ListTile)`. If it asserts the recipe title via `find.text('Curry')`, that still works.

- [ ] **Step 4: Run impacted tests**

Run: `flutter test test/screens/trackers/meal/widgets/recipe_selector_sheet_test.dart`
Expected: PASS.

Run: `flutter analyze`
Expected: `No issues found!` (no orphan imports left).

- [ ] **Step 5: Commit**

```bash
git add lib/screens/recipes/widgets/recipe_list_tile.dart lib/screens/trackers/meal/widgets/recipe_selector_sheet.dart test/screens/trackers/meal/widgets/recipe_selector_sheet_test.dart test/screens/recipes/widgets/recipe_list_tile_test.dart
git commit -m "$(cat <<'EOF'
refactor(recipes): drop RecipeListTile; selector sheet uses ListTile

The grid redesign replaced RecipeListTile in MyRecipesTab. The recipe
selector sheet inside the meal tracker was the only other consumer;
inline a stock ListTile + SignedPathImage thumbnail there. Tile widget
and its test deleted.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Phase 4 — Ship

### Task 10: Full suite + manual smoke

- [ ] **Step 1: Full analyzer**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 2: Full test suite**

Run: `flutter test`
Expected: green (modulo pre-existing skips).

- [ ] **Step 3: `dart format`**

Run: `dart format lib/ test/`
Expected: 0 files changed.

- [ ] **Step 4: Manual smoke (Android 15 emulator, iOS, or whatever you have wired)**

1. Open Rezepte → Meine Rezepte. With ≥ 5 recipes a 2-column grid renders. Mix of imaged + pastel-monogram cards.
2. Type `kart` in the search bar. After ~300 ms the grid filters to matching titles/ingredients. No per-key fetch storm.
3. Tap the clear icon → grid returns to the full set.
4. Search a non-existent term → empty grid (current implementation; the "Keine Treffer" copy is in the Out of scope follow-up — see spec).
5. Delete every recipe → mascot empty-state reappears, search bar gone.
6. Open the meal tracker, tap "Aus Rezept auswählen" → list of recipes still works (selector unchanged).

### Task 11: Push and open PR

- [ ] **Step 1: Push**

```bash
git push -u origin feat/recipes-grid-search
```

- [ ] **Step 2: Open the PR against `feat/user-recipes`** (this branch sits ON TOP of the parent feature branch, not on develop)

```bash
gh pr create --base feat/user-recipes --title "feat(recipes): grid layout + Postgres FTS search" --body "$(cat <<'EOF'
## Summary
- Replace the recipes row list with a 2-column image grid (`RecipeCard`)
- Pin a `RecipesSearchField` above the grid; back search with a Postgres `tsvector` generated column + GIN index and prefix-per-token (`token:*`) tsquery formatting
- Provider gains a debounced `setQuery` (300 ms, last-value-wins, no-op on identical query)
- `RecipeListTile` deleted; selector sheet uses an inline `ListTile`
- Pastel monogram fallback (`pastelForTitle`) for cards without an image

Spec: `docs/superpowers/specs/2026-04-25-recipes-grid-search-design.md`
Plan: `docs/superpowers/plans/2026-04-25-recipes-grid-search.md`

## Test plan
- [x] `flutter analyze` clean
- [x] `flutter test` green
- [ ] Manual smoke on a real device:
  - [ ] Grid renders 2-up; mix of images + pastel monograms.
  - [ ] Type → debounce → filter; clear icon resets.
  - [ ] Empty result → empty grid (acceptable per spec).
  - [ ] Truly-empty recipes → mascot CTA returns (search bar hidden).
  - [ ] Selector sheet inside the meal tracker still picks recipes.
- [ ] Migration applied to Supabase before merge (`supabase db push` or SQL editor).

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Do **not** arm auto-merge.

If you'd rather PR straight to `develop` (skipping the `feat/user-recipes` chain), pass `--base develop` instead. That works only after `feat/user-recipes` (PR #61) lands.

---

## Self-review

### Spec coverage
- §1 layout (2-col grid + RecipeCard) — Tasks 6, 8. ✓
- §2 pastel fallback — Tasks 5, 6. ✓
- §3 Postgres FTS migration — Task 1. ✓
- §3 service `searchForUser` + `_buildTsQuery` — Task 2. ✓
- §4 provider `setQuery` + debounced fetch branch — Task 4. ✓
- §5 `RecipesSearchField` widget — Task 7. ✓
- §6 empty states — Task 8 (with documented spec-fallback behavior).
- §7 `RecipeSelectorSheet` unchanged behaviorally; widget swapped — Task 9. ✓

No spec section without a task.

### Placeholder scan
None. Every code step has full code; every command shows expected output; no "TBD" / "as needed" / "etc."

### Type consistency
- `setQuery(String? q)` — same signature in provider impl (Task 4) and search field (Task 7).
- `searchForUser(String userId, String query)` — same signature across service (Task 2), repository (Task 3), and provider call (Task 4).
- `pastelForTitle(String)` — defined in Task 5; consumed in Task 6.
- `SignedPathImage(pathOrUrl: ...)` — used in Task 6 + Task 9 with the existing API.
- The shared 300 ms debounce duration is a private constant on the notifier; the test's `Future.delayed(const Duration(milliseconds: 350))` matches.
