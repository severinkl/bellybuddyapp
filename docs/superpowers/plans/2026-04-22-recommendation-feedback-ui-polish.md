# Recommendation Feedback UI Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor `RecommendationFeedbackView` to use segmented "Hilfreich / Nicht hilfreich" pills; move the category chips + comment textarea + "Empfehlung ausblenden" button into a new `RecommendationDislikeSheet` bottom sheet launched when the user taps the "Nicht hilfreich" pill.

**Architecture:** Widget refactor only — model, repository, notifier, and backend stay exactly as they are (see commit `808419b`). New private `_FeedbackPill` widget for the two tappable pills; new public `RecommendationDislikeSheet` widget launched via `showModalBottomSheet`.

**Tech Stack:** Existing Flutter + Riverpod. No new dependencies. Reuses `setRecommendationState`, `setDislikeComment` on the existing `RecommendationNotifier`.

---

## File Structure

**New runtime code:**
- `lib/screens/recommendations/widgets/recommendation_dislike_sheet.dart` — bottom sheet widget + `showRecommendationDislikeSheet` helper.

**Modified runtime code:**
- `lib/screens/recommendations/widgets/recommendation_feedback_view.dart` — rewritten around pills; inline disliked layout removed.

**Tests:**
- Rewrite: `test/screens/recommendations/widgets/recommendation_feedback_view_test.dart`.
- New: `test/screens/recommendations/widgets/recommendation_dislike_sheet_test.dart`.

---

## Task 1: `RecommendationDislikeSheet` + helper

**Files:**
- Create: `lib/screens/recommendations/widgets/recommendation_dislike_sheet.dart`
- Create: `test/screens/recommendations/widgets/recommendation_dislike_sheet_test.dart`

- [ ] **Step 1: Write failing tests**

Create `test/screens/recommendations/widgets/recommendation_dislike_sheet_test.dart`:

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
import 'package:belly_buddy/screens/recommendations/widgets/recommendation_dislike_sheet.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/mocks.dart';
import '../../../helpers/riverpod_helpers.dart';

// Helper: pump a host widget that opens the sheet on a button tap.
Future<void> _openSheet(
  WidgetTester tester, {
  required Recommendation rec,
  required List<Override> overrides,
}) async {
  await tester.pumpWithProviders(
    Builder(
      builder: (ctx) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => showRecommendationDislikeSheet(ctx, rec),
            child: const Text('open'),
          ),
        ),
      ),
    ),
    overrides: overrides,
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    registerFallbackValue(RecommendationState.unrated);
  });

  group('RecommendationDislikeSheet', () {
    testWidgets('renders all 5 chips + textarea + buttons', (tester) async {
      final repo = MockRecommendationRepository();
      when(() => repo.fetchByUserId(any())).thenAnswer((_) async => []);
      when(() => repo.markAllAsSeen(any())).thenAnswer((_) async {});
      when(() => repo.updateFeedback(
            id: any(named: 'id'),
            state: any(named: 'state'),
            dislikeCategory: any(named: 'dislikeCategory'),
            dislikeComment: any(named: 'dislikeComment'),
          )).thenAnswer((_) async {});

      final rec = testRecommendation(id: 'r1').copyWith(
        state: RecommendationState.disliked,
      );

      await _openSheet(tester, rec: rec, overrides: [
        recommendationRepositoryProvider.overrideWithValue(repo),
        currentUserIdProvider.overrideWithValue('test-user'),
      ]);

      expect(find.text('Was hat dir nicht gefallen?'), findsOneWidget);
      for (final c in DislikeCategory.values) {
        expect(find.text(c.label), findsOneWidget);
      }
      expect(find.text('Empfehlung ausblenden'), findsOneWidget);
      expect(find.text('Fertig'), findsOneWidget);
    });

    testWidgets('tapping a chip calls setRecommendationState with that category', (tester) async {
      final repo = MockRecommendationRepository();
      when(() => repo.fetchByUserId(any())).thenAnswer((_) async => []);
      when(() => repo.markAllAsSeen(any())).thenAnswer((_) async {});
      when(() => repo.updateFeedback(
            id: any(named: 'id'),
            state: any(named: 'state'),
            dislikeCategory: any(named: 'dislikeCategory'),
            dislikeComment: any(named: 'dislikeComment'),
          )).thenAnswer((_) async {});

      final rec = testRecommendation(id: 'r1').copyWith(
        state: RecommendationState.disliked,
      );
      final container = createContainer(overrides: [
        recommendationRepositoryProvider.overrideWithValue(repo),
        currentUserIdProvider.overrideWithValue('test-user'),
      ]);
      addTearDown(container.dispose);
      // Seed the provider with this rec so setRecommendationState has a target.
      await container.read(recommendationProvider.notifier).fetchRecommendations();
      // Stub fetch to return the rec once we re-run.
      when(() => repo.fetchByUserId(any())).thenAnswer((_) async => [rec]);
      await container.read(recommendationProvider.notifier).fetchRecommendations();

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showRecommendationDislikeSheet(ctx, rec),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nicht relevant'));
      await tester.pumpAndSettle();

      verify(() => repo.updateFeedback(
            id: 'r1',
            state: RecommendationState.disliked,
            dislikeCategory: DislikeCategory.notRelevant.dbValue,
            dislikeComment: null,
          )).called(1);
    });

    testWidgets('Fertig pops without calling the repo', (tester) async {
      final repo = MockRecommendationRepository();
      when(() => repo.fetchByUserId(any())).thenAnswer((_) async => []);
      when(() => repo.markAllAsSeen(any())).thenAnswer((_) async {});

      final rec = testRecommendation(id: 'r1').copyWith(
        state: RecommendationState.disliked,
      );

      await _openSheet(tester, rec: rec, overrides: [
        recommendationRepositoryProvider.overrideWithValue(repo),
        currentUserIdProvider.overrideWithValue('test-user'),
      ]);

      await tester.tap(find.text('Fertig'));
      await tester.pumpAndSettle();

      expect(find.byType(RecommendationDislikeSheet), findsNothing);
      verifyNever(() => repo.updateFeedback(
            id: any(named: 'id'),
            state: any(named: 'state'),
            dislikeCategory: any(named: 'dislikeCategory'),
            dislikeComment: any(named: 'dislikeComment'),
          ));
    });

    testWidgets('Ausblenden calls setRecommendationState(hidden) and pops', (tester) async {
      final repo = MockRecommendationRepository();
      when(() => repo.fetchByUserId(any())).thenAnswer((_) async => [
            testRecommendation(id: 'r1').copyWith(
              state: RecommendationState.disliked,
            ),
          ]);
      when(() => repo.markAllAsSeen(any())).thenAnswer((_) async {});
      when(() => repo.updateFeedback(
            id: any(named: 'id'),
            state: any(named: 'state'),
            dislikeCategory: any(named: 'dislikeCategory'),
            dislikeComment: any(named: 'dislikeComment'),
          )).thenAnswer((_) async {});

      final rec = testRecommendation(id: 'r1').copyWith(
        state: RecommendationState.disliked,
      );
      final container = createContainer(overrides: [
        recommendationRepositoryProvider.overrideWithValue(repo),
        currentUserIdProvider.overrideWithValue('test-user'),
      ]);
      addTearDown(container.dispose);
      await container.read(recommendationProvider.notifier).fetchRecommendations();

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showRecommendationDislikeSheet(ctx, rec),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Empfehlung ausblenden'));
      await tester.pumpAndSettle();

      expect(find.byType(RecommendationDislikeSheet), findsNothing);
      verify(() => repo.updateFeedback(
            id: 'r1',
            state: RecommendationState.hidden,
            dislikeCategory: null,
            dislikeComment: null,
          )).called(1);
    });

    testWidgets('pre-fills selected chip when rec has a category', (tester) async {
      final repo = MockRecommendationRepository();
      when(() => repo.fetchByUserId(any())).thenAnswer((_) async => []);
      when(() => repo.markAllAsSeen(any())).thenAnswer((_) async {});

      final rec = testRecommendation(id: 'r1').copyWith(
        state: RecommendationState.disliked,
        dislikeCategory: DislikeCategory.tooComplicated.dbValue,
        dislikeComment: 'zu lang',
      );

      await _openSheet(tester, rec: rec, overrides: [
        recommendationRepositoryProvider.overrideWithValue(repo),
        currentUserIdProvider.overrideWithValue('test-user'),
      ]);

      // The textarea should be pre-filled.
      final tf = tester.widget<TextField>(find.byType(TextField).first);
      expect(tf.controller?.text, 'zu lang');
      // The selected ChoiceChip should be the one labelled "Zu kompliziert".
      final chips = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip));
      expect(
        chips.firstWhere((c) => (c.label as Text).data == 'Zu kompliziert').selected,
        isTrue,
      );
    });
  });
}
```

Run: `flutter test test/screens/recommendations/widgets/recommendation_dislike_sheet_test.dart`
Expected: FAIL (file / widget don't exist yet).

- [ ] **Step 2: Implement `RecommendationDislikeSheet`**

Create `lib/screens/recommendations/widgets/recommendation_dislike_sheet.dart`:

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../models/dislike_category.dart';
import '../../../models/recommendation.dart';
import '../../../providers/recommendation_provider.dart';

/// Opens the "Warum nicht hilfreich?" bottom sheet for the given
/// recommendation. Callers do not await the returned Future unless they
/// want to know when the user dismisses the sheet — all data is persisted
/// before the sheet closes.
Future<void> showRecommendationDislikeSheet(
  BuildContext context,
  Recommendation recommendation,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    backgroundColor: AppTheme.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => RecommendationDislikeSheet(recommendation: recommendation),
  );
}

class RecommendationDislikeSheet extends ConsumerStatefulWidget {
  const RecommendationDislikeSheet({super.key, required this.recommendation});

  final Recommendation recommendation;

  @override
  ConsumerState<RecommendationDislikeSheet> createState() =>
      _RecommendationDislikeSheetState();
}

class _RecommendationDislikeSheetState
    extends ConsumerState<RecommendationDislikeSheet> {
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
  void dispose() {
    _commentDebounce?.cancel();
    _commentController.dispose();
    super.dispose();
  }

  void _showSaveError() {
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(content: Text('Konnte nicht gespeichert werden.')),
    );
  }

  Future<void> _selectCategory(DislikeCategory category) async {
    try {
      await ref
          .read(recommendationProvider.notifier)
          .setRecommendationState(
            id: widget.recommendation.id,
            state: RecommendationState.disliked,
            category: category,
            comment: _commentController.text.isEmpty
                ? null
                : _commentController.text,
          );
    } catch (_) {
      if (!mounted) return;
      _showSaveError();
    }
  }

  void _onCommentChanged(String value) {
    _commentDebounce?.cancel();
    _commentDebounce = Timer(AppConstants.debounceDuration, () async {
      if (!mounted) return;
      try {
        await ref
            .read(recommendationProvider.notifier)
            .setDislikeComment(
              id: widget.recommendation.id,
              comment: value.isEmpty ? null : value,
            );
      } catch (_) {
        if (!mounted) return;
        _showSaveError();
      }
    });
  }

  Future<void> _hide() async {
    try {
      await ref
          .read(recommendationProvider.notifier)
          .setRecommendationState(
            id: widget.recommendation.id,
            state: RecommendationState.hidden,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      _showSaveError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = DislikeCategory.fromDbValue(
      widget.recommendation.dislikeCategory,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppConstants.spacingMd,
        AppConstants.spacingSm,
        AppConstants.spacingMd,
        MediaQuery.viewInsetsOf(context).bottom + AppConstants.spacingMd,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          AppConstants.gap12,
          const Text(
            'Was hat dir nicht gefallen?',
            style: TextStyle(
              fontSize: AppTheme.fontSizeSubtitle,
              fontWeight: FontWeight.w600,
              color: AppTheme.foreground,
            ),
          ),
          AppConstants.gap4,
          const Text(
            'Deine Antwort hilft uns, bessere Tipps zu finden.',
            style: TextStyle(
              fontSize: AppTheme.fontSizeBody,
              color: AppTheme.mutedForeground,
            ),
          ),
          AppConstants.gap12,
          Wrap(
            spacing: AppConstants.spacingSm,
            runSpacing: AppConstants.spacingSm,
            children: [
              for (final c in DislikeCategory.values)
                ChoiceChip(
                  label: Text(c.label),
                  selected: selected == c,
                  selectedColor: AppTheme.destructive,
                  labelStyle: TextStyle(
                    color: selected == c
                        ? Colors.white
                        : AppTheme.foreground,
                    fontSize: AppTheme.fontSizeBody,
                  ),
                  onSelected: (_) => _selectCategory(c),
                ),
            ],
          ),
          AppConstants.gap12,
          TextField(
            controller: _commentController,
            onChanged: _onCommentChanged,
            minLines: 2,
            maxLines: null,
            decoration: const InputDecoration(
              labelText: 'Noch etwas? (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          AppConstants.gap16,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: _hide,
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.destructive,
                ),
                child: const Text('Empfehlung ausblenden'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.foreground,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Fertig'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Run tests + analyze**

Run: `flutter test test/screens/recommendations/widgets/recommendation_dislike_sheet_test.dart` → pass.
Run: `flutter analyze` → 0 issues.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/recommendations/widgets/recommendation_dislike_sheet.dart \
        test/screens/recommendations/widgets/recommendation_dislike_sheet_test.dart
git commit -m "feat(recommendations): dislike bottom sheet"
```

---

## Task 2: Rewrite `RecommendationFeedbackView` around pills

**Files:**
- Modify: `lib/screens/recommendations/widgets/recommendation_feedback_view.dart`
- Rewrite: `test/screens/recommendations/widgets/recommendation_feedback_view_test.dart`

- [ ] **Step 1: Rewrite the widget test file**

Replace the entire contents of `test/screens/recommendations/widgets/recommendation_feedback_view_test.dart` with tests that cover the new shape:

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
import 'package:belly_buddy/screens/recommendations/widgets/recommendation_dislike_sheet.dart';
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
  setUpAll(() {
    registerFallbackValue(RecommendationState.unrated);
  });

  group('RecommendationFeedbackView', () {
    testWidgets('unrated: heading + two pills, no hint', (tester) async {
      final rec = testRecommendation(id: 'r1');
      await _pump(tester, rec: rec, overrides: [
        recommendationRepositoryProvider.overrideWithValue(
          MockRecommendationRepository(),
        ),
        currentUserIdProvider.overrideWithValue('test-user'),
      ]);

      expect(find.text('War diese Empfehlung hilfreich?'), findsOneWidget);
      expect(find.text('Hilfreich'), findsOneWidget);
      expect(find.text('Nicht hilfreich'), findsOneWidget);
      expect(find.text('Danke für dein Feedback', skipOffstage: false),
          findsNothing);
      expect(find.text('Wird berücksichtigt', skipOffstage: false),
          findsNothing);
    });

    testWidgets('tapping Hilfreich calls notifier with liked', (tester) async {
      final repo = MockRecommendationRepository();
      when(() => repo.fetchByUserId(any())).thenAnswer((_) async => [testRecommendation(id: 'r1')]);
      when(() => repo.markAllAsSeen(any())).thenAnswer((_) async {});
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

      await tester.tap(find.text('Hilfreich'));
      await tester.pumpAndSettle();

      verify(() => repo.updateFeedback(
            id: 'r1',
            state: RecommendationState.liked,
            dislikeCategory: null,
            dislikeComment: null,
          )).called(1);
    });

    testWidgets('liked: renders "Danke für dein Feedback" hint', (tester) async {
      final rec = testRecommendation(id: 'r1').copyWith(
        state: RecommendationState.liked,
      );
      await _pump(tester, rec: rec, overrides: [
        recommendationRepositoryProvider.overrideWithValue(
          MockRecommendationRepository(),
        ),
        currentUserIdProvider.overrideWithValue('test-user'),
      ]);

      expect(find.textContaining('Danke'), findsOneWidget);
    });

    testWidgets('tapping Nicht hilfreich opens the dislike sheet', (tester) async {
      final repo = MockRecommendationRepository();
      final rec = testRecommendation(id: 'r1');
      when(() => repo.fetchByUserId(any())).thenAnswer((_) async => [rec]);
      when(() => repo.markAllAsSeen(any())).thenAnswer((_) async {});
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

      await tester.tap(find.text('Nicht hilfreich'));
      await tester.pumpAndSettle();

      expect(find.byType(RecommendationDislikeSheet), findsOneWidget);
      // Also: the notifier was called with disliked before the sheet opened.
      verify(() => repo.updateFeedback(
            id: 'r1',
            state: RecommendationState.disliked,
            dislikeCategory: null,
            dislikeComment: null,
          )).called(1);
    });

    testWidgets('disliked: renders hint + Bearbeiten; tapping Bearbeiten re-opens the sheet', (tester) async {
      final rec = testRecommendation(id: 'r1').copyWith(
        state: RecommendationState.disliked,
        dislikeCategory: DislikeCategory.notRelevant.dbValue,
      );
      await _pump(tester, rec: rec, overrides: [
        recommendationRepositoryProvider.overrideWithValue(
          MockRecommendationRepository(),
        ),
        currentUserIdProvider.overrideWithValue('test-user'),
      ]);

      expect(find.textContaining('Wird berücksichtigt'), findsOneWidget);
      expect(find.text('Bearbeiten'), findsOneWidget);

      await tester.tap(find.text('Bearbeiten'));
      await tester.pumpAndSettle();
      expect(find.byType(RecommendationDislikeSheet), findsOneWidget);
    });

    testWidgets('repo error shows SnackBar', (tester) async {
      final repo = MockRecommendationRepository();
      when(() => repo.fetchByUserId(any())).thenAnswer((_) async => [testRecommendation(id: 'r1')]);
      when(() => repo.markAllAsSeen(any())).thenAnswer((_) async {});
      when(() => repo.updateFeedback(
            id: any(named: 'id'),
            state: any(named: 'state'),
            dislikeCategory: any(named: 'dislikeCategory'),
            dislikeComment: any(named: 'dislikeComment'),
          )).thenThrow(Exception('boom'));

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

      await tester.tap(find.text('Hilfreich'));
      await tester.pumpAndSettle();

      expect(find.text('Konnte nicht gespeichert werden.'), findsOneWidget);
    });
  });
}
```

Run: `flutter test test/screens/recommendations/widgets/recommendation_feedback_view_test.dart` — expected FAIL (widget hasn't been refactored yet; old chips + textarea still present).

- [ ] **Step 2: Rewrite `recommendation_feedback_view.dart`**

Replace the entire file with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../models/recommendation.dart';
import '../../../providers/recommendation_provider.dart';
import 'recommendation_dislike_sheet.dart';

/// Feedback row shown at the bottom of a single recommendation page. Two
/// segmented pills ("Hilfreich" / "Nicht hilfreich"); tapping the latter
/// opens the [RecommendationDislikeSheet] for the category + comment flow.
/// Hidden state is unreachable here (hidden recommendations are filtered
/// upstream in the repository).
class RecommendationFeedbackView extends ConsumerWidget {
  const RecommendationFeedbackView({super.key, required this.recommendation});

  final Recommendation recommendation;

  Future<void> _setLiked(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(recommendationProvider.notifier)
          .setRecommendationState(
            id: recommendation.id,
            state: RecommendationState.liked,
          );
    } catch (_) {
      if (!context.mounted) return;
      _showSaveError(context);
    }
  }

  Future<void> _setDislikedAndOpenSheet(
    BuildContext context,
    WidgetRef ref,
  ) async {
    if (recommendation.state != RecommendationState.disliked) {
      try {
        await ref
            .read(recommendationProvider.notifier)
            .setRecommendationState(
              id: recommendation.id,
              state: RecommendationState.disliked,
              // Preserve any existing category/comment from an earlier session.
              category: null,
              comment: recommendation.dislikeComment,
            );
      } catch (_) {
        if (!context.mounted) return;
        _showSaveError(context);
        return;
      }
    }
    if (!context.mounted) return;
    await showRecommendationDislikeSheet(context, recommendation);
  }

  void _showSaveError(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(content: Text('Konnte nicht gespeichert werden.')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = recommendation.state;
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
              color: AppTheme.mutedForeground,
            ),
          ),
          AppConstants.gap8,
          Row(
            children: [
              Expanded(
                child: _FeedbackPill(
                  icon: '👍',
                  label: 'Hilfreich',
                  selected: state == RecommendationState.liked,
                  selectedColor: AppTheme.primary,
                  onTap: () => _setLiked(context, ref),
                ),
              ),
              const SizedBox(width: AppConstants.spacingSm),
              Expanded(
                child: _FeedbackPill(
                  icon: '👎',
                  label: 'Nicht hilfreich',
                  selected: state == RecommendationState.disliked,
                  selectedColor: AppTheme.destructive,
                  onTap: () => _setDislikedAndOpenSheet(context, ref),
                ),
              ),
            ],
          ),
          if (state == RecommendationState.liked) ...[
            AppConstants.gap8,
            const Text(
              '✓ Danke für dein Feedback',
              style: TextStyle(
                fontSize: AppTheme.fontSizeCaptionLG,
                color: AppTheme.primary,
              ),
            ),
          ] else if (state == RecommendationState.disliked) ...[
            AppConstants.gap8,
            Row(
              children: [
                const Text(
                  '✓ Wird berücksichtigt',
                  style: TextStyle(
                    fontSize: AppTheme.fontSizeCaptionLG,
                    color: AppTheme.destructive,
                  ),
                ),
                const SizedBox(width: AppConstants.spacingSm),
                TextButton(
                  onPressed: () =>
                      showRecommendationDislikeSheet(context, recommendation),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: AppTheme.foreground,
                  ),
                  child: const Text(
                    'Bearbeiten',
                    style: TextStyle(
                      fontSize: AppTheme.fontSizeCaptionLG,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _FeedbackPill extends StatelessWidget {
  const _FeedbackPill({
    required this.icon,
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  final String icon;
  final String label;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: AppConstants.animFast,
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? selectedColor : AppTheme.card,
          border: Border.all(
            color: selected ? selectedColor : AppTheme.border,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: AppConstants.spacingSm),
            Text(
              label,
              style: TextStyle(
                fontSize: AppTheme.fontSizeBody,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppTheme.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Run tests + analyze**

Run: `flutter test` → all pass (model + repo + notifier + widget tests).
Run: `flutter analyze` → 0 issues.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/recommendations/widgets/recommendation_feedback_view.dart \
        test/screens/recommendations/widgets/recommendation_feedback_view_test.dart
git commit -m "feat(recommendations): segmented pills + hint line on feedback view"
```

---

## Task 3: Manual smoke test (user)

- [ ] Cold-start the app, open **Für dich** → an unrated recommendation.
- [ ] Verify: heading + two pills ("Hilfreich" / "Nicht hilfreich"). No chips, no textarea.
- [ ] Tap **Hilfreich** → pill fills primary, "✓ Danke für dein Feedback" appears. No modal.
- [ ] Swipe to another recommendation. Swipe back — liked state persists.
- [ ] Tap **Nicht hilfreich** → pill fills destructive, bottom sheet slides up with the 5 chips, textarea, Ausblenden, Fertig.
- [ ] Tap a chip (e.g. "Zu kompliziert") → chip fills destructive; no modal close.
- [ ] Type a comment, wait 800 ms — no visible change, but a subsequent cold-start should show the comment pre-filled.
- [ ] Tap **Fertig** → sheet closes. Main page shows "✓ Wird berücksichtigt" + "Bearbeiten".
- [ ] Tap **Bearbeiten** → sheet re-opens with the chip and comment pre-filled.
- [ ] Tap **Empfehlung ausblenden** → sheet closes, recommendation disappears from the PageView, "Empfehlungen (N von M)" count decreases by one.
- [ ] Cold-restart the app — hidden stays hidden.
- [ ] In airplane mode, tap **Hilfreich** — SnackBar "Konnte nicht gespeichert werden." appears; UI reverts.
