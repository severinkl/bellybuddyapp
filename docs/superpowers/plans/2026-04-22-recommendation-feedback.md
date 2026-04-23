# Recommendation Feedback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users rate a recommendation as helpful or not, optionally categorize why it wasn't, and hide disliked recommendations from future views. Persist the state on the recommendation row in Supabase; reflect it in the UI with a feedback component at the end of each recommendation's detail section inside `_RecommendationPage`.

**Architecture:** Extend the `Recommendation` Freezed model with four new fields (`state`, `dislikeCategory`, `dislikeComment`, `ratedAt`). Add a `RecommendationState` enum + a `DislikeCategory` enum with German display labels. Extend `RecommendationRepository` with `updateFeedback(...)` and filter hidden rows in `fetchByUserId`. Add notifier methods `setRecommendationState(...)` (optimistic update + revert on error) and `setDislikeComment(...)` (debounced). Build a self-contained `RecommendationFeedbackView` widget that renders differently per state and drop it at the end of `_RecommendationPage`'s ListView.

**Tech Stack:** Flutter Freezed (codegen), Riverpod `Notifier`, existing `RecommendationRepository` backed by Supabase, existing `RecommendationNotifier`. No new dependencies.

---

## File Structure

**New runtime code:**
- `lib/models/dislike_category.dart` — `enum DislikeCategory` with DB string + German label getter.
- `lib/screens/recommendations/widgets/recommendation_feedback_view.dart` — `ConsumerStatefulWidget` rendering the feedback UI.

**Modified runtime code:**
- `lib/models/recommendation.dart` — add fields + `RecommendationState` enum.
- `lib/models/recommendation.freezed.dart` / `.g.dart` — regenerated via `build_runner`.
- `lib/repositories/recommendation_repository.dart` — add `updateFeedback`; filter hidden in `fetchByUserId`.
- `lib/providers/recommendation_provider.dart` — add `setRecommendationState` + `setDislikeComment` methods.
- `lib/screens/recommendations/recommendations_screen.dart` — drop `RecommendationFeedbackView` at the end of `_RecommendationPage`'s ListView.

**Tests:**
- `test/models/recommendation_test.dart` — round-trip the new fields; default state is `unrated`.
- `test/models/dislike_category_test.dart` — DB string + label mappings.
- `test/repositories/recommendation_repository_test.dart` — existing file; add cases for `updateFeedback` + hidden filter.
- `test/providers/recommendation_provider_test.dart` — existing file; add cases for `setRecommendationState` (liked / disliked+category / hidden / error-rollback) and `setDislikeComment`.
- `test/screens/recommendations/widgets/recommendation_feedback_view_test.dart` — unrated / liked / disliked renders; tap thumbs / chips / hide triggers the right notifier calls; error SnackBar on failure.

**Backend:**
- Hand the Lovable prompt from the spec (`docs/superpowers/specs/2026-04-22-recommendation-feedback-design.md`, "Backend task for Lovable" section) over before merging the client-side PR, so the schema is live when the app ships.

---

## Task 1: Extend the `Recommendation` model + add `DislikeCategory` enum

**Files:**
- Modify: `lib/models/recommendation.dart`
- Create: `lib/models/dislike_category.dart`
- Test: `test/models/recommendation_test.dart` (create if absent)
- Test: `test/models/dislike_category_test.dart` (create)
- Generated: `lib/models/recommendation.freezed.dart`, `lib/models/recommendation.g.dart` (regenerated)

- [ ] **Step 1: Write failing tests for the new fields + enums**

Create `test/models/dislike_category_test.dart`:

```dart
import 'package:belly_buddy/models/dislike_category.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DislikeCategory', () {
    test('dbValue round-trips via fromDbValue', () {
      for (final c in DislikeCategory.values) {
        expect(DislikeCategory.fromDbValue(c.dbValue), c);
      }
    });

    test('fromDbValue returns null for unknown strings', () {
      expect(DislikeCategory.fromDbValue('nonsense'), isNull);
      expect(DislikeCategory.fromDbValue(null), isNull);
      expect(DislikeCategory.fromDbValue(''), isNull);
    });

    test('label is German and non-empty', () {
      for (final c in DislikeCategory.values) {
        expect(c.label, isNotEmpty);
      }
      expect(DislikeCategory.notRelevant.label, 'Nicht relevant');
      expect(DislikeCategory.dontLikeIngredient.label, 'Zutat gefällt mir nicht');
      expect(DislikeCategory.dontLikeRecipe.label, 'Rezept gefällt mir nicht');
      expect(DislikeCategory.tooComplicated.label, 'Zu kompliziert');
      expect(DislikeCategory.other.label, 'Anderer Grund');
    });

    test('dbValue strings match the backend contract', () {
      expect(DislikeCategory.notRelevant.dbValue, 'not_relevant');
      expect(DislikeCategory.dontLikeIngredient.dbValue, 'dont_like_ingredient');
      expect(DislikeCategory.dontLikeRecipe.dbValue, 'dont_like_recipe');
      expect(DislikeCategory.tooComplicated.dbValue, 'too_complicated');
      expect(DislikeCategory.other.dbValue, 'other');
    });
  });
}
```

Create or extend `test/models/recommendation_test.dart` with cases that exercise the new fields:

```dart
import 'package:belly_buddy/models/recommendation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Recommendation.fromJson', () {
    test('defaults state to unrated when absent', () {
      final rec = Recommendation.fromJson({
        'id': 'rec-1',
        'user_id': 'user-1',
        'summary': 'test',
        'recommendations': [],
        'created_at': '2026-04-22T12:00:00Z',
      });
      expect(rec.state, RecommendationState.unrated);
      expect(rec.dislikeCategory, isNull);
      expect(rec.dislikeComment, isNull);
      expect(rec.ratedAt, isNull);
    });

    test('parses all four states from the DB string', () {
      for (final (dbValue, expected) in const [
        ('unrated', RecommendationState.unrated),
        ('liked', RecommendationState.liked),
        ('disliked', RecommendationState.disliked),
        ('hidden', RecommendationState.hidden),
      ]) {
        final rec = Recommendation.fromJson({
          'id': 'rec-1',
          'user_id': 'user-1',
          'summary': '',
          'recommendations': [],
          'state': dbValue,
        });
        expect(rec.state, expected);
      }
    });

    test('parses dislike_category, dislike_comment, rated_at', () {
      final rec = Recommendation.fromJson({
        'id': 'rec-1',
        'user_id': 'user-1',
        'summary': '',
        'recommendations': [],
        'state': 'disliked',
        'dislike_category': 'not_relevant',
        'dislike_comment': 'Kein Kommentar',
        'rated_at': '2026-04-22T13:00:00Z',
      });
      expect(rec.dislikeCategory, 'not_relevant');
      expect(rec.dislikeComment, 'Kein Kommentar');
      expect(rec.ratedAt, DateTime.utc(2026, 4, 22, 13));
    });
  });
}
```

Run: `flutter test test/models/dislike_category_test.dart test/models/recommendation_test.dart`
Expected: FAIL (types don't exist yet).

- [ ] **Step 2: Create `DislikeCategory`**

Create `lib/models/dislike_category.dart`:

```dart
/// Why the user downvoted a recommendation. The DB column (`dislike_category`
/// on `public.recommendations`) is free-text; we keep this enum as the
/// client's source of truth for the known values and only allow the client
/// to write these exact strings.
enum DislikeCategory {
  notRelevant('not_relevant', 'Nicht relevant'),
  dontLikeIngredient('dont_like_ingredient', 'Zutat gefällt mir nicht'),
  dontLikeRecipe('dont_like_recipe', 'Rezept gefällt mir nicht'),
  tooComplicated('too_complicated', 'Zu kompliziert'),
  other('other', 'Anderer Grund');

  const DislikeCategory(this.dbValue, this.label);

  /// Stored in Supabase — do not rename without a migration.
  final String dbValue;

  /// German display label for chips / read-out.
  final String label;

  static DislikeCategory? fromDbValue(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final c in DislikeCategory.values) {
      if (c.dbValue == value) return c;
    }
    return null;
  }
}
```

- [ ] **Step 3: Extend `Recommendation` + add `RecommendationState` enum**

Replace `lib/models/recommendation.dart` with:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'recommendation_item.dart';

part 'recommendation.freezed.dart';
part 'recommendation.g.dart';

/// One of four user-feedback states for a recommendation. Stored on the DB
/// row as the `state` column (TEXT with a CHECK constraint).
enum RecommendationState {
  unrated('unrated'),
  liked('liked'),
  disliked('disliked'),
  hidden('hidden');

  const RecommendationState(this.dbValue);

  final String dbValue;

  static RecommendationState fromDbValue(String? value) {
    if (value == null) return RecommendationState.unrated;
    for (final s in RecommendationState.values) {
      if (s.dbValue == value) return s;
    }
    return RecommendationState.unrated;
  }
}

List<RecommendationItem> _parseItems(List<dynamic>? items) {
  if (items == null) return [];
  return items
      .whereType<Map<String, dynamic>>()
      .map((e) => RecommendationItem.fromJson(e))
      .toList();
}

RecommendationState _stateFromJson(String? v) =>
    RecommendationState.fromDbValue(v);
String _stateToJson(RecommendationState s) => s.dbValue;

@freezed
abstract class Recommendation with _$Recommendation {
  const factory Recommendation({
    required String id,
    @JsonKey(name: 'user_id') String? userId,
    String? summary,
    @JsonKey(fromJson: _parseItems)
    @Default([])
    List<RecommendationItem> recommendations,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(
      fromJson: _stateFromJson,
      toJson: _stateToJson,
    )
    @Default(RecommendationState.unrated)
    RecommendationState state,
    @JsonKey(name: 'dislike_category') String? dislikeCategory,
    @JsonKey(name: 'dislike_comment') String? dislikeComment,
    @JsonKey(name: 'rated_at') DateTime? ratedAt,
  }) = _Recommendation;

  factory Recommendation.fromJson(Map<String, dynamic> json) =>
      _$RecommendationFromJson(json);
}
```

- [ ] **Step 4: Regenerate Freezed / JSON code**

Run: `dart run build_runner build --delete-conflicting-outputs`.
Expected: `lib/models/recommendation.freezed.dart` and `lib/models/recommendation.g.dart` updated in place. No errors.

- [ ] **Step 5: Run the new model tests**

Run: `flutter test test/models/dislike_category_test.dart test/models/recommendation_test.dart`.
Expected: all pass.

- [ ] **Step 6: Run the full suite + analyze**

Run: `flutter test` and `flutter analyze`.
Expected: all tests pass, 0 analyze issues.

- [ ] **Step 7: Commit**

```bash
git add lib/models/recommendation.dart \
        lib/models/recommendation.freezed.dart \
        lib/models/recommendation.g.dart \
        lib/models/dislike_category.dart \
        test/models/recommendation_test.dart \
        test/models/dislike_category_test.dart
git commit -m "feat(recommendations): model support for feedback state + categories"
```

---

## Task 2: Repository — `updateFeedback` + hidden filter

**Files:**
- Modify: `lib/repositories/recommendation_repository.dart`
- Test: `test/repositories/recommendation_repository_test.dart`

- [ ] **Step 1: Read the current repository + test file**

Read `lib/repositories/recommendation_repository.dart` and `test/repositories/recommendation_repository_test.dart` in full. The existing `fetchByUserId` uses the Supabase client's `.from('recommendations').select(...).eq('user_id', userId).order('created_at', ascending: false)`. Mirror that pattern when adding `.neq('state', 'hidden')`.

- [ ] **Step 2: Write failing tests**

Add to `test/repositories/recommendation_repository_test.dart`:

```dart
group('fetchByUserId', () {
  test('excludes rows with state = "hidden"', () async {
    // Adapt to the existing Supabase mock pattern in this file. Stub the
    // query chain so the .neq('state', 'hidden') call is observable — either
    // via a chainable mock (mocktail verify) or by returning different
    // canned results depending on whether the neq was called.
  });
});

group('updateFeedback', () {
  test('writes state, dislike_category, dislike_comment, rated_at', () async {
    final repo = RecommendationRepository(/* client */);
    await repo.updateFeedback(
      id: 'rec-1',
      state: RecommendationState.disliked,
      dislikeCategory: DislikeCategory.notRelevant,
      dislikeComment: 'Nein',
    );
    // Verify the Supabase .update({...}).eq('id', 'rec-1') was called with:
    //  - state: 'disliked'
    //  - dislike_category: 'not_relevant'
    //  - dislike_comment: 'Nein'
    //  - rated_at: (a timestamp — can be asserted with any() or isA<String>())
  });

  test('omits null category and comment from the payload', () async {
    // updateFeedback(state: liked) should write only state + rated_at,
    // not dislike_category or dislike_comment.
  });

  test('state: hidden writes only state + rated_at, no category/comment', () async {
    // same shape as above.
  });
});
```

The exact mocktail wiring depends on how the repo test is already structured — read the file first and follow the existing Supabase-mock pattern verbatim.

Run: `flutter test test/repositories/recommendation_repository_test.dart`
Expected: FAIL (`updateFeedback` doesn't exist, the `.neq` isn't in place).

- [ ] **Step 3: Implement the repo changes**

In `lib/repositories/recommendation_repository.dart`:

1. Import `RecommendationState` and `DislikeCategory`.
2. Add `.neq('state', 'hidden')` in `fetchByUserId` — place it right before `.order(...)`.
3. Add the `updateFeedback` method:

```dart
Future<void> updateFeedback({
  required String id,
  required RecommendationState state,
  DislikeCategory? dislikeCategory,
  String? dislikeComment,
}) async {
  final payload = <String, dynamic>{
    'state': state.dbValue,
    'rated_at': DateTime.now().toIso8601String(),
  };
  if (dislikeCategory != null) {
    payload['dislike_category'] = dislikeCategory.dbValue;
  }
  if (dislikeComment != null) {
    payload['dislike_comment'] = dislikeComment;
  }

  try {
    await _client.from('recommendations').update(payload).eq('id', id);
  } catch (e, st) {
    _log.error('updateFeedback failed for id=$id', e, st);
    rethrow;
  }
}
```

(Use the logger the file already declares. Adapt the `_client` field name to match the existing code.)

- [ ] **Step 4: Run tests + analyze**

Run: `flutter test test/repositories/recommendation_repository_test.dart` → pass.
Run: `flutter analyze` → 0 issues.

- [ ] **Step 5: Commit**

```bash
git add lib/repositories/recommendation_repository.dart \
        test/repositories/recommendation_repository_test.dart
git commit -m "feat(recommendations): repo.updateFeedback + filter hidden rows"
```

---

## Task 3: Notifier — `setRecommendationState` + `setDislikeComment`

**Files:**
- Modify: `lib/providers/recommendation_provider.dart`
- Test: `test/providers/recommendation_provider_test.dart`

- [ ] **Step 1: Write failing tests**

Add to `test/providers/recommendation_provider_test.dart`:

```dart
group('setRecommendationState', () {
  test('liked → replaces the recommendation with state=liked', () async {
    // Seed the notifier with three recommendations.
    // Call setRecommendationState(id: rec1.id, state: liked).
    // Assert repo.updateFeedback was called with state=liked, no category/comment.
    // Assert the in-memory list has the matching rec with state = liked.
  });

  test('disliked + category + comment → repo receives all three', () async {
    // Call setRecommendationState(id, disliked, category: notRelevant, comment: 'Text').
    // Assert repo.updateFeedback called with all three.
    // Assert the in-memory rec has state=disliked, dislikeCategory='not_relevant', dislikeComment='Text'.
  });

  test('hidden → removes the recommendation from the list', () async {
    // Start with 3 recs. Hide rec1.
    // Assert list length 2; rec1 is not in it.
  });

  test('on repo error, the list is reverted and the exception rethrows', () async {
    // Seed 3 recs. Mock repo.updateFeedback to throw.
    // Expect setRecommendationState to throw.
    // Assert list is unchanged from the seed.
  });
});

group('setDislikeComment', () {
  test('updates only the comment locally + on repo', () async {
    // Seed a rec with state=disliked, no comment.
    // Call setDislikeComment(id, 'hallo').
    // Assert repo.updateFeedback called with state=disliked (unchanged) and comment='hallo'.
    // Assert the in-memory rec now has dislikeComment='hallo'.
  });
});
```

Run: `flutter test test/providers/recommendation_provider_test.dart` → FAIL (methods don't exist).

- [ ] **Step 2: Implement the notifier changes**

Add to `RecommendationNotifier` in `lib/providers/recommendation_provider.dart`:

```dart
Future<void> setRecommendationState({
  required String id,
  required RecommendationState state,
  DislikeCategory? category,
  String? comment,
}) async {
  final previous = this.state;
  final currentList = previous.valueOrNull;
  if (currentList == null) return;

  // Optimistic update.
  final List<Recommendation> next;
  if (state == RecommendationState.hidden) {
    next = currentList.where((r) => r.id != id).toList();
  } else {
    next = currentList
        .map(
          (r) => r.id == id
              ? r.copyWith(
                  state: state,
                  dislikeCategory: category?.dbValue,
                  dislikeComment: comment,
                  ratedAt: DateTime.now(),
                )
              : r,
        )
        .toList();
  }
  this.state = AsyncValue.data(next);

  try {
    await ref
        .read(recommendationRepositoryProvider)
        .updateFeedback(
          id: id,
          state: state,
          dislikeCategory: category,
          dislikeComment: comment,
        );
  } catch (e, st) {
    _log.error('setRecommendationState failed for id=$id', e, st);
    this.state = previous;
    rethrow;
  }
}

Future<void> setDislikeComment({
  required String id,
  String? comment,
}) async {
  final previous = this.state;
  final currentList = previous.valueOrNull;
  if (currentList == null) return;

  final target = currentList.where((r) => r.id == id).firstOrNull;
  if (target == null) return;

  final next = currentList
      .map(
        (r) => r.id == id
            ? r.copyWith(
                dislikeComment: comment,
                ratedAt: DateTime.now(),
              )
            : r,
      )
      .toList();
  this.state = AsyncValue.data(next);

  try {
    await ref
        .read(recommendationRepositoryProvider)
        .updateFeedback(
          id: id,
          state: target.state,
          dislikeCategory: DislikeCategory.fromDbValue(target.dislikeCategory),
          dislikeComment: comment,
        );
  } catch (e, st) {
    _log.error('setDislikeComment failed for id=$id', e, st);
    this.state = previous;
    rethrow;
  }
}
```

(Import `DislikeCategory` + `RecommendationState`. `firstOrNull` is from `package:collection/collection.dart` — if it's not already imported, add the import.)

- [ ] **Step 3: Run tests + analyze**

Run: `flutter test test/providers/recommendation_provider_test.dart` → pass.
Run: `flutter analyze` → 0 issues.

- [ ] **Step 4: Commit**

```bash
git add lib/providers/recommendation_provider.dart \
        test/providers/recommendation_provider_test.dart
git commit -m "feat(recommendations): notifier.setRecommendationState + setDislikeComment"
```

---

## Task 4: `RecommendationFeedbackView` widget

**Files:**
- Create: `lib/screens/recommendations/widgets/recommendation_feedback_view.dart`
- Test: `test/screens/recommendations/widgets/recommendation_feedback_view_test.dart` (create)

- [ ] **Step 1: Write failing widget tests**

Create `test/screens/recommendations/widgets/recommendation_feedback_view_test.dart`:

```dart
// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/src/internals.dart' show Override;

import 'package:belly_buddy/models/dislike_category.dart';
import 'package:belly_buddy/models/recommendation.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/recommendation_provider.dart';
import 'package:belly_buddy/repositories/recommendation_repository.dart';
import 'package:belly_buddy/screens/recommendations/widgets/recommendation_feedback_view.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/mocks.dart';
import '../../../helpers/riverpod_helpers.dart';

Future<void> _pump(
  WidgetTester tester, {
  required Recommendation rec,
  required List<Override> overrides,
}) async {
  await tester.pumpWithProviders(
    Scaffold(body: RecommendationFeedbackView(recommendation: rec)),
    overrides: overrides,
  );
  await tester.pumpAndSettle();
}

void main() {
  group('RecommendationFeedbackView', () {
    testWidgets('unrated shows heading + thumbs, no category chips', (tester) async {
      final rec = testRecommendation(id: 'r1');
      await _pump(tester, rec: rec, overrides: [
        recommendationRepositoryProvider.overrideWithValue(
          MockRecommendationRepository(),
        ),
        currentUserIdProvider.overrideWithValue('test-user'),
      ]);

      expect(find.text('War diese Empfehlung hilfreich?'), findsOneWidget);
      expect(find.byIcon(Icons.thumb_up_outlined), findsOneWidget);
      expect(find.byIcon(Icons.thumb_down_outlined), findsOneWidget);
      expect(find.text('Nicht relevant'), findsNothing);
      expect(find.text('Diese Empfehlung ausblenden'), findsNothing);
    });

    testWidgets('tapping 👍 on unrated calls setRecommendationState(liked)', (tester) async {
      final repo = MockRecommendationRepository();
      when(() => repo.fetchByUserId(any())).thenAnswer((_) async => [testRecommendation(id: 'r1')]);
      when(() => repo.updateFeedback(
            id: any(named: 'id'),
            state: any(named: 'state'),
            dislikeCategory: any(named: 'dislikeCategory'),
            dislikeComment: any(named: 'dislikeComment'),
          )).thenAnswer((_) async {});

      final container = createContainer(overrides: [
        recommendationRepositoryProvider.overrideWithValue(repo),
        currentUserIdProvider.overrideWithValue('test-user'),
      ]);
      addTearDown(container.dispose);
      await container.read(recommendationProvider.notifier).fetchRecommendations();

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: RecommendationFeedbackView(
              recommendation: container.read(recommendationProvider).value!.first,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.thumb_up_outlined));
      await tester.pumpAndSettle();

      verify(() => repo.updateFeedback(
            id: 'r1',
            state: RecommendationState.liked,
            dislikeCategory: null,
            dislikeComment: null,
          )).called(1);
    });

    testWidgets('disliked shows categories + Ausblenden button', (tester) async {
      final rec = testRecommendation(id: 'r1').copyWith(
        state: RecommendationState.disliked,
      );
      await _pump(tester, rec: rec, overrides: [
        recommendationRepositoryProvider.overrideWithValue(
          MockRecommendationRepository(),
        ),
        currentUserIdProvider.overrideWithValue('test-user'),
      ]);

      expect(find.text('Schade! Warum nicht?'), findsOneWidget);
      for (final c in DislikeCategory.values) {
        expect(find.text(c.label), findsOneWidget);
      }
      expect(find.text('Diese Empfehlung ausblenden'), findsOneWidget);
    });

    testWidgets('tapping a category chip in disliked state calls setRecommendationState with the category', (tester) async {
      // Set up the container with a disliked rec; tap "Nicht relevant";
      // verify repo.updateFeedback called with dislikeCategory: DislikeCategory.notRelevant.
    });

    testWidgets('tapping Ausblenden calls setRecommendationState(hidden)', (tester) async {
      // Same pattern — verify updateFeedback called with state: hidden.
    });

    testWidgets('liked shows filled thumb-up + Danke!', (tester) async {
      final rec = testRecommendation(id: 'r1').copyWith(
        state: RecommendationState.liked,
      );
      await _pump(tester, rec: rec, overrides: [
        recommendationRepositoryProvider.overrideWithValue(
          MockRecommendationRepository(),
        ),
        currentUserIdProvider.overrideWithValue('test-user'),
      ]);

      expect(find.byIcon(Icons.thumb_up), findsOneWidget); // filled
      expect(find.byIcon(Icons.thumb_down_outlined), findsOneWidget); // still tappable
      expect(find.text('Danke!'), findsOneWidget);
    });

    testWidgets('on repo error, a SnackBar with the fallback copy appears', (tester) async {
      // Mock repo.updateFeedback to throw. Tap 👍. After pumpAndSettle, a
      // SnackBar with "Konnte nicht gespeichert werden." is in the tree.
    });
  });
}
```

The tests above skip a few with pseudocode comments — fill them in mirroring the patterns already shown. Read `test/screens/recommendations/recommendations_screen_test.dart` for the established `MockRecommendationRepository` + `createContainer` conventions used in this codebase.

Run: `flutter test test/screens/recommendations/widgets/recommendation_feedback_view_test.dart` → FAIL (widget doesn't exist).

- [ ] **Step 2: Implement the widget**

Create `lib/screens/recommendations/widgets/recommendation_feedback_view.dart`:

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../models/dislike_category.dart';
import '../../../models/recommendation.dart';
import '../../../providers/recommendation_provider.dart';

class RecommendationFeedbackView extends ConsumerStatefulWidget {
  const RecommendationFeedbackView({super.key, required this.recommendation});

  final Recommendation recommendation;

  @override
  ConsumerState<RecommendationFeedbackView> createState() =>
      _RecommendationFeedbackViewState();
}

class _RecommendationFeedbackViewState
    extends ConsumerState<RecommendationFeedbackView> {
  late final TextEditingController _commentController;
  Timer? _commentDebounce;

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController(
      text: widget.recommendation.dislikeComment ?? '',
    );
  }

  @override
  void didUpdateWidget(covariant RecommendationFeedbackView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Resync the text controller when the underlying recommendation's comment
    // changes (e.g. if the server state arrived after an optimistic update).
    final serverComment = widget.recommendation.dislikeComment ?? '';
    if (serverComment != _commentController.text &&
        oldWidget.recommendation.dislikeComment !=
            widget.recommendation.dislikeComment) {
      _commentController.text = serverComment;
    }
  }

  @override
  void dispose() {
    _commentDebounce?.cancel();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _setState(
    RecommendationState target, {
    DislikeCategory? category,
    String? comment,
  }) async {
    try {
      await ref
          .read(recommendationProvider.notifier)
          .setRecommendationState(
            id: widget.recommendation.id,
            state: target,
            category: category,
            comment: comment,
          );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Konnte nicht gespeichert werden.'),
        ),
      );
    }
  }

  void _onCommentChanged(String value) {
    _commentDebounce?.cancel();
    _commentDebounce = Timer(const Duration(seconds: 1), () async {
      if (!mounted) return;
      try {
        await ref.read(recommendationProvider.notifier).setDislikeComment(
              id: widget.recommendation.id,
              comment: value.isEmpty ? null : value,
            );
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Konnte nicht gespeichert werden.'),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.recommendation.state;
    return switch (state) {
      RecommendationState.unrated || RecommendationState.liked =>
        _buildRatedOrUnrated(state),
      RecommendationState.disliked => _buildDisliked(),
      RecommendationState.hidden => const SizedBox.shrink(),
    };
  }

  Widget _buildRatedOrUnrated(RecommendationState state) {
    final isLiked = state == RecommendationState.liked;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'War diese Empfehlung hilfreich?',
            style: TextStyle(
              fontSize: AppTheme.fontSizeBody,
              fontWeight: FontWeight.w600,
              color: AppTheme.foreground,
            ),
          ),
          AppConstants.gap8,
          Row(
            children: [
              IconButton(
                icon: Icon(isLiked ? Icons.thumb_up : Icons.thumb_up_outlined),
                color: isLiked ? AppTheme.primary : AppTheme.foreground,
                onPressed: () => _setState(RecommendationState.liked),
              ),
              IconButton(
                icon: const Icon(Icons.thumb_down_outlined),
                color: AppTheme.foreground,
                onPressed: () => _setState(RecommendationState.disliked),
              ),
              const Spacer(),
              if (isLiked)
                const Text(
                  'Danke!',
                  style: TextStyle(
                    fontSize: AppTheme.fontSizeBody,
                    color: AppTheme.mutedForeground,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDisliked() {
    final selectedCategory = DislikeCategory.fromDbValue(
      widget.recommendation.dislikeCategory,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Schade! Warum nicht?',
            style: TextStyle(
              fontSize: AppTheme.fontSizeBody,
              fontWeight: FontWeight.w600,
              color: AppTheme.foreground,
            ),
          ),
          AppConstants.gap8,
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.thumb_up_outlined),
                color: AppTheme.foreground,
                onPressed: () => _setState(RecommendationState.liked),
              ),
              IconButton(
                icon: const Icon(Icons.thumb_down),
                color: AppTheme.destructive,
                onPressed: () => _setState(RecommendationState.unrated),
              ),
            ],
          ),
          AppConstants.gap8,
          Wrap(
            spacing: AppConstants.spacingSm,
            runSpacing: AppConstants.spacingSm,
            children: [
              for (final c in DislikeCategory.values)
                ChoiceChip(
                  label: Text(c.label),
                  selected: selectedCategory == c,
                  onSelected: (_) => _setState(
                    RecommendationState.disliked,
                    category: c,
                    comment: _commentController.text.isEmpty
                        ? null
                        : _commentController.text,
                  ),
                ),
            ],
          ),
          AppConstants.gap12,
          TextField(
            controller: _commentController,
            onChanged: _onCommentChanged,
            maxLines: null,
            decoration: const InputDecoration(
              labelText: 'Noch etwas? (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          AppConstants.gap8,
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.destructive,
              ),
              onPressed: () => _setState(RecommendationState.hidden),
              child: const Text('Diese Empfehlung ausblenden'),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Run tests + analyze**

Run: `flutter test test/screens/recommendations/widgets/recommendation_feedback_view_test.dart` → pass.
Run: `flutter analyze` → 0 issues.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/recommendations/widgets/recommendation_feedback_view.dart \
        test/screens/recommendations/widgets/recommendation_feedback_view_test.dart
git commit -m "feat(recommendations): RecommendationFeedbackView widget"
```

---

## Task 5: Wire into `_RecommendationPage`

**Files:**
- Modify: `lib/screens/recommendations/recommendations_screen.dart`
- Test: `test/screens/recommendations/recommendations_screen_test.dart`

- [ ] **Step 1: Add the widget to `_RecommendationPage`'s ListView**

In `lib/screens/recommendations/recommendations_screen.dart`, at the bottom of `_RecommendationPage`'s `ListView.children` — after the `...recommendation.recommendations.map(...)` items, before the trailing `AppConstants.gap24` — insert:

```dart
AppConstants.gap16,
RecommendationFeedbackView(recommendation: recommendation),
```

Add the import: `import 'widgets/recommendation_feedback_view.dart';`.

- [ ] **Step 2: Add an integration-style widget test**

Add to `test/screens/recommendations/recommendations_screen_test.dart`:

```dart
testWidgets('each page renders RecommendationFeedbackView', (tester) async {
  await tester.pumpWithProviders(
    const RecommendationsScreen(),
    overrides: _overridesFor([_rec('1')]),
  );
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pumpAndSettle();

  expect(find.text('War diese Empfehlung hilfreich?'), findsOneWidget);
  expect(find.byIcon(Icons.thumb_up_outlined), findsOneWidget);
});
```

- [ ] **Step 3: Run all tests + analyze**

Run: `flutter test` → all pass (590+ tests).
Run: `flutter analyze` → 0 issues.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/recommendations/recommendations_screen.dart \
        test/screens/recommendations/recommendations_screen_test.dart
git commit -m "feat(recommendations): wire feedback view into RecommendationsScreen"
```

---

## Task 6: Manual smoke test (user performs, after Lovable backend migration lands)

- [ ] Hand the Lovable prompt from the spec's "Backend task for Lovable" section over; wait for the migration + RLS policy to be live.
- [ ] Cold-start the app, open **Für dich** → recommendations.
- [ ] Verify the feedback row appears at the bottom of the current page ("War diese Empfehlung hilfreich?" + thumbs).
- [ ] Tap 👍 — thumb-up fills, "Danke!" text appears. Swipe to previous recommendation and back; state persists (via Supabase).
- [ ] Cold-restart the app and confirm the liked state survives.
- [ ] On a different recommendation, tap 👎 — categories + Ausblenden appear. Tap "Nicht relevant". Type a comment; wait a second; verify it persists on cold-restart.
- [ ] Tap "Diese Empfehlung ausblenden" — the recommendation disappears from the list; the AppBar count decreases by one. Cold-restart; it stays hidden.
- [ ] Disable network (airplane mode) and try to rate — verify the SnackBar "Konnte nicht gespeichert werden." appears and the UI reverts.
