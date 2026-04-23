# Recommendation Feedback UI Polish — Design

**Date:** 2026-04-22
**Status:** Approved, ready for implementation plan.
**Parent:** Builds on top of `2026-04-22-recommendation-feedback-design.md` (data model + notifier + repo unchanged). Modifies only the client-side UI layer of `RecommendationFeedbackView`.

## Goal

Replace the thumb-IconButton + inline chips layout with:
- **Main page:** two wide **segmented pills** ("👍 Hilfreich" / "👎 Nicht hilfreich") at the bottom of each `_RecommendationPage`.
- **Disliked flow:** tapping the "Nicht hilfreich" pill opens a **bottom-sheet modal** (`RecommendationDislikeSheet`) that contains the category chips, optional comment textarea, and "Empfehlung ausblenden" button. No inline expansion.

## Non-goals

- No changes to the data model, `RecommendationRepository`, `RecommendationService`, notifier methods, or Supabase schema. All were defined in the parent spec and are staying exactly as they are.
- No changes to the hidden-row SQL filter.
- No new German copy — reuses existing strings plus two new hint lines.

## Main widget layout

`RecommendationFeedbackView` becomes:

- **Heading row:** "War diese Empfehlung hilfreich?" — `AppTheme.fontSizeBody`, semi-bold, `AppTheme.mutedForeground`.
- **Pills row:** two equal-width `_FeedbackPill`s side-by-side via `Row` + `Expanded`s with `AppConstants.spacingSm` spacing.
  - `_FeedbackPill` props: `icon`, `label`, `selected`, `selectedColor`, `onTap`.
  - Unselected: `AppTheme.card` background, 1.5 px `AppTheme.border` outline, 14 px radius, 12 px vertical padding. Icon + label centered.
  - Selected: filled `selectedColor` (primary for liked, destructive for disliked), white foreground, no outline. Uses `AnimatedContainer(duration: AppConstants.animFast)` for the color/border transition.
- **Hint line** (only when state is liked or disliked):
  - Liked → "✓ Danke für dein Feedback" in `AppTheme.primary`, 12 px.
  - Disliked → "✓ Wird berücksichtigt" in `AppTheme.destructive`, 12 px, followed by a small "Bearbeiten" text button that re-opens the sheet.

The inline chip grid, textarea, and hide button from the previous version are all removed.

## Disliked bottom sheet

New widget: `lib/screens/recommendations/widgets/recommendation_dislike_sheet.dart`, a `ConsumerStatefulWidget` launched via `showModalBottomSheet<void>(isScrollControlled: true, useSafeArea: true, shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))), builder: ...)`.

**Layout** (inside `SafeArea` + `Padding(EdgeInsets.fromLTRB(spacingMd, spacingSm, spacingMd, MediaQuery.viewInsetsOf(context).bottom + spacingMd))` so the keyboard doesn't cover the content):

1. Centered drag handle: 40 × 4, 2 px radius, `AppTheme.border`, 12 px bottom margin.
2. Title "Was hat dir nicht gefallen?" — 17 px, semi-bold, `AppTheme.foreground`.
3. Subtitle "Deine Antwort hilft uns, bessere Tipps zu finden." — 13 px, `AppTheme.mutedForeground`, 14 px bottom margin.
4. `Wrap` of 5 `ChoiceChip`s, one per `DislikeCategory` value, single-select. Selected chip: `AppTheme.destructive` background, white label. Spacing `AppConstants.spacingSm`.
5. 12 px gap.
6. `TextField` labeled "Noch etwas? (optional)", `minLines: 2`, `maxLines: null`, outlined 10 px border.
7. 14 px gap.
8. Footer `Row` with `MainAxisAlignment.spaceBetween`:
   - Left: `TextButton` "Empfehlung ausblenden" with `AppTheme.destructive` foreground.
   - Right: `FilledButton` "Fertig" with `AppTheme.foreground` background, white label, 12 px radius, 10 px vertical padding.

## Behavior

- **Tap "👍 Hilfreich":** `notifier.setRecommendationState(state: liked)`. Pill fills; hint "Danke" appears. No modal.
- **Tap "👎 Nicht hilfreich":**
  1. Optimistic state transition to `disliked` (via notifier).
  2. Open the `RecommendationDislikeSheet` passing the recommendation.
  3. If the recommendation already had a category / comment (from a prior session), pre-select the chip and pre-fill the textarea.
- **Chip tap in sheet:** calls `notifier.setRecommendationState(state: disliked, category: c, comment: currentCommentOrNull)`. Single-select — the tapped chip becomes the new selection (no way to unselect; to switch, tap a different chip).
- **Typing in comment field:** 800 ms debounce (`AppConstants.debounceDuration`), then `notifier.setDislikeComment(comment: text)`. Empty string saves as `null`.
- **Tap "Empfehlung ausblenden":** `notifier.setRecommendationState(state: hidden)` then `Navigator.pop(context)`. The recommendation vanishes from the parent PageView on the next rebuild.
- **Tap "Fertig":** `Navigator.pop(context)`. No additional work — all data already persisted.
- **Dismiss via scrim / swipe-down / grabber:** identical to Fertig (data already persisted).
- **Re-open via the main page's "Bearbeiten" text button:** same sheet with prefilled values.

## Dispose-safety

- The sheet owns a `TextEditingController` and a debounce `Timer`. Both are cancelled/disposed in the sheet's `dispose`.
- If the debounce callback fires after the sheet is popped (rare): the sheet's `mounted` guard returns early. Worst case, an in-flight Supabase write completes against the current recommendation — which is fine because that's exactly what the user typed.

## Error handling

Reused from the previous version: every notifier call is wrapped in a `try/catch`. On failure the widget (or the sheet) calls a shared `_showSaveError(context)` that calls `hideCurrentSnackBar` before showing "Konnte nicht gespeichert werden." Prevents snack pile-ups when a comment fails repeatedly during offline typing.

## Files

**New:**
- `lib/screens/recommendations/widgets/recommendation_dislike_sheet.dart` — the modal.

**Modified:**
- `lib/screens/recommendations/widgets/recommendation_feedback_view.dart` — rewrite around pills + hint line; remove the inline disliked build path.
- `test/screens/recommendations/widgets/recommendation_feedback_view_test.dart` — rewrite tests to match the new shape (pills, hint line, sheet launch).

**Tests added:**
- `test/screens/recommendations/widgets/recommendation_dislike_sheet_test.dart` (new).

## Testing

**`RecommendationFeedbackView`:**
- Unrated: heading + two unselected pills rendered. No hint line. No chips. No textarea.
- Tapping 👍 Hilfreich → `notifier.setRecommendationState(state: liked)` called. Liked hint visible.
- Tapping 👎 Nicht hilfreich → `notifier.setRecommendationState(state: disliked)` called AND `showModalBottomSheet` invoked (assertable via `find.byType(RecommendationDislikeSheet)` after `pumpAndSettle`).
- Disliked state renders "✓ Wird berücksichtigt" + "Bearbeiten" text button.
- Tapping "Bearbeiten" re-opens the sheet.
- Error in notifier.setRecommendationState → SnackBar with "Konnte nicht gespeichert werden." shown.

**`RecommendationDislikeSheet`:**
- Renders the 5 chips, textarea, Ausblenden button, Fertig button.
- Chip tap → `notifier.setRecommendationState(state: disliked, category: c, comment: anyComment)`.
- Chip switch (tap A then B) fires two calls, second with the new category.
- Typing in textarea then waiting 800 ms → `notifier.setDislikeComment` called once. No call during the debounce window.
- Tapping Ausblenden → `notifier.setRecommendationState(state: hidden)` + `Navigator.pop`.
- Tapping Fertig → `Navigator.pop`, no notifier call.
- Pre-fill: opened on a disliked recommendation with existing category/comment → chip is selected and textarea contains the comment.

## Risks / open items

- **Category switch semantics.** If the user is on "Nicht relevant" and taps "Zu kompliziert", the new category is written and the old is lost (single-select). No prompt. Acceptable — matches the simple chip-selector pattern.
- **Sheet + keyboard overlap.** We use `MediaQuery.viewInsetsOf(context).bottom` to pad the sheet when the keyboard is up. Verified across iOS + Android during manual smoke.
- **"Bearbeiten" discoverability.** If the user dislikes and closes without picking a category, the main page shows only the hint. "Bearbeiten" is a small text button; OK for discoverability because the modal already ran once and the user is unlikely to need it frequently.

## Out of scope

- Un-dislike path via re-tapping the filled 👎 pill. If the user wants to switch back to liked, they tap the 👍 pill — which runs `setRecommendationState(state: liked)` and clears category/comment per the parent spec.
- Animations beyond the pill color transition. No sliding, no hero, no confetti.
