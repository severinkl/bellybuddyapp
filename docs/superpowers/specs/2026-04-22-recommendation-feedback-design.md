# Recommendation Feedback — Design

**Date:** 2026-04-22
**Status:** Approved, ready for implementation plan.

## Goal

Let users tell us whether a recommendation was helpful. Each recommendation carries one of four states — `unrated`, `liked`, `disliked`, `hidden` — plus an optional dislike category and free-text comment when they downvote. Hidden recommendations disappear from the list. Ratings (liked/disliked) are reversible; hiding is one-way.

## Non-goals

- No multi-user/per-rater history. Belly Buddy is single-user; the rating lives on the recommendation row itself.
- No offline queue. On network failure the optimistic update reverts and a snackbar surfaces. v2 if users complain.
- No analytics dashboard. The collected data sits in Supabase for later export.
- No un-hide surface. Hidden rows stay in the DB for analytics; the client has no UI to resurface them.

## Backend

### Schema

Add columns to `public.recommendations`:

| Column | Type | Nullable | Default |
|---|---|---|---|
| `state` | `TEXT` with `CHECK (state IN ('unrated','liked','disliked','hidden'))` | no | `'unrated'` |
| `dislike_category` | `TEXT` | yes | `null` |
| `dislike_comment` | `TEXT` | yes | `null` |
| `rated_at` | `TIMESTAMPTZ` | yes | `null` |

`dislike_category` is a free-text column, not an enum — the client sends one of a known set (`not_relevant`, `dont_like_ingredient`, `dont_like_recipe`, `too_complicated`, `other`). Keeping it a string means adding a new category later is client-only (no migration).

### RLS

Current policy on `public.recommendations` lets authenticated users `SELECT` their own rows. This spec adds an `UPDATE` policy so owners can write the four new columns and nothing else.

```sql
CREATE POLICY "Users can update their own recommendations feedback"
ON public.recommendations
FOR UPDATE
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);
```

(Column-level restriction isn't strictly enforced by RLS — a malicious client could UPDATE any column. If that's a concern, wrap the write in a `SECURITY DEFINER` function. v1 accepts the ergonomic UPDATE.)

### Backend task for Lovable

Paste this verbatim into Lovable:

```text
Task: extend public.recommendations with feedback columns.

Schema migration:
- Add column `state` TEXT NOT NULL DEFAULT 'unrated' with CHECK constraint:
    CHECK (state IN ('unrated', 'liked', 'disliked', 'hidden'))
- Add column `dislike_category` TEXT (nullable).
- Add column `dislike_comment` TEXT (nullable).
- Add column `rated_at` TIMESTAMPTZ (nullable).

RLS:
- Add UPDATE policy allowing authenticated users to update their own rows:
    CREATE POLICY "Users can update their own recommendations feedback"
      ON public.recommendations
      FOR UPDATE
      TO authenticated
      USING (auth.uid() = user_id)
      WITH CHECK (auth.uid() = user_id);

Existing policies (SELECT) are unchanged.

No new tables, no edge functions needed.
```

## Client flow

### Data model

Extend `Recommendation` (Freezed) with:

- `state: RecommendationState` — new enum with values `unrated`, `liked`, `disliked`, `hidden`. Defaults to `unrated` when the JSON field is absent (for backward compatibility during the migration window).
- `dislikeCategory: String?`
- `dislikeComment: String?`
- `ratedAt: DateTime?`

Add a sibling enum `DislikeCategory` with values `notRelevant`, `dontLikeIngredient`, `dontLikeRecipe`, `tooComplicated`, `other`. Each value has:
- A DB string (`not_relevant`, `dont_like_ingredient`, `dont_like_recipe`, `too_complicated`, `other`).
- A German display label ("Nicht relevant", "Zutat gefällt mir nicht", "Rezept gefällt mir nicht", "Zu kompliziert", "Anderer Grund").

### Repository

Extend `RecommendationRepository`:

- `fetchByUserId(userId)` gains `.neq('state', 'hidden')` so hidden rows never reach the client.
- New method `updateFeedback({required String id, required RecommendationState state, String? dislikeCategory, String? dislikeComment})` — issues a Supabase `UPDATE` on `recommendations` with the four columns + `rated_at = now()`. Returns `void`; throws on network error.

### Notifier

`RecommendationNotifier` gains `setRecommendationState({required String id, required RecommendationState state, DislikeCategory? category, String? comment})`:

1. Capture the previous list snapshot.
2. Optimistic update:
   - Find the recommendation by id.
   - If new state is `hidden`, remove it from the list.
   - Otherwise, replace it with `recommendation.copyWith(state: ..., dislikeCategory: ..., dislikeComment: ..., ratedAt: DateTime.now())`.
3. `await repo.updateFeedback(...)`.
4. On error: restore the snapshot and rethrow (or surface via a snackbar — the widget wrapping this call handles user-facing feedback).

Separate method for the debounced comment save: `setDislikeComment({required String id, required String? comment})` — same pattern, only updates `dislike_comment` + `rated_at`. Optimistic.

### Widget

New widget `RecommendationFeedbackView` at `lib/screens/recommendations/widgets/recommendation_feedback_view.dart`. A `ConsumerStatefulWidget` taking `Recommendation recommendation`.

Renders one of three sub-layouts based on `recommendation.state`:

**`unrated`:**
- "War diese Empfehlung hilfreich?" heading.
- Row with two `IconButton`s (thumbs-up / thumbs-down, outlined).

**`liked`:**
- Same heading.
- Thumbs row: 👍 filled, 👎 outlined (tappable — switches to disliked).
- Trailing "Danke!" text.

**`disliked`:**
- "Schade! Warum nicht?" heading.
- Thumbs row: 👍 outlined (tappable — switches to liked), 👎 filled.
- `Wrap` of `ChoiceChip`s — one per `DislikeCategory`, single-select. Tapping a chip immediately calls `setRecommendationState(..., state: disliked, category: <value>, comment: currentComment)`.
- Optional `TextField` labelled "Noch etwas? (optional)". On typing, start a 1 s debounce; when the debounce fires (or on blur), call `setDislikeComment(...)`.
- Text button at the bottom: "Diese Empfehlung ausblenden". Tapping calls `setRecommendationState(..., state: hidden)`. After the optimistic update, the recommendation vanishes from the parent list and this widget is gone.

**`hidden`:** unreachable in the widget tree (filter happens upstream).

### Wiring

Drop `RecommendationFeedbackView(recommendation: latest)` at the end of the latest-recommendation detail section in `RecommendationsScreen._buildDataState` (before the `RecommendationHistory` collapsible). Inside `RecommendationHistory`'s expanded-item rendering, also render `RecommendationFeedbackView(recommendation: rec)` below each expanded item's content.

If PR #48 (swipe layout) lands later, its `_RecommendationPage` gets the same widget at the bottom of its ListView.

### Error handling

Repository throws → notifier rolls back → widget catches and shows a SnackBar ("Konnte nicht gespeichert werden"). Widget-level try/catch wrapping each `setRecommendationState` / `setDislikeComment` call.

### UI copy (German)

- Heading (unrated / liked): "War diese Empfehlung hilfreich?"
- Heading (disliked): "Schade! Warum nicht?"
- Thanks text: "Danke!"
- Category labels: "Nicht relevant", "Zutat gefällt mir nicht", "Rezept gefällt mir nicht", "Zu kompliziert", "Anderer Grund"
- Comment field label: "Noch etwas? (optional)"
- Hide button: "Diese Empfehlung ausblenden"
- Error SnackBar: "Konnte nicht gespeichert werden."

## Testing

**Model:**
- Round-trip `fromJson` / `toJson` for the new fields (all 4 state values, null/non-null categories).
- Default state is `unrated` when the column is absent in the JSON.

**Repository:**
- `updateFeedback` sends the right Supabase payload including `rated_at`.
- `fetchByUserId` filters `state = 'hidden'` at the DB boundary.

**Notifier (`RecommendationNotifier`):**
- `setRecommendationState(id, liked)` replaces the matching recommendation with state=liked.
- `setRecommendationState(id, disliked, category: notRelevant)` updates state + category; other recommendations unchanged.
- `setRecommendationState(id, hidden)` removes the recommendation from the list.
- On repo error, the list is reverted to the pre-call snapshot and the error rethrows.
- `setDislikeComment(id, "...")` updates only the comment field.

**Widget (`RecommendationFeedbackView`):**
- Unrated state renders heading + both thumbs, no categories.
- Tapping 👍 in unrated → notifier.setRecommendationState called with `state: liked`.
- Tapping 👎 in unrated → categories + "Ausblenden" appear.
- Tapping a category chip when disliked → notifier called with that category.
- Tapping "Diese Empfehlung ausblenden" → notifier called with `state: hidden`; widget is expected to disappear on next rebuild.
- Liked renders filled 👍 + "Danke!".
- Repo error path: SnackBar "Konnte nicht gespeichert werden." appears.

**Integration (optional):**
- Cold-start with three recommendations, tap 👎 on the first, pick "Nicht relevant", then "Ausblenden". List shrinks to two, remaining recommendations visible.

## Risks / open items

- **Category drift.** `dislike_category` is a TEXT column, not an enum table. If someone runs the wrong version of the client and writes an unknown category, the aggregation breaks silently. Acceptable: client is the single source of truth for category set, and unknown-category rows can be queried out later.
- **Column-level RLS.** The UPDATE policy allows owners to update any column, not just the feedback columns. A malicious client could rewrite `summary` / `recommendations`. If that's a concern, move writes to a `SECURITY DEFINER` function that checks the column set. Deferred to v2.
- **Debounced comment save race.** If the user types a comment, then taps Ausblenden before the debounce fires, the hide-update wins and the in-flight comment save will write to a hidden row (harmless — the row is hidden but the comment lands for analytics). Acceptable.
- **Hidden recommendation count.** The AppBar "Empfehlungen (N von M)" (from the swipe layout, when it lands) counts only visible items. A refresh brings hidden ones back if the filter misses them — verified via the repository-level `.neq('state','hidden')`.

## Out of scope

- Un-hide UI / hidden-recommendations review screen.
- Offline feedback queue.
- Per-category recommendation-generation tuning (the model endpoint consumes the feedback eventually; out of scope for this client work).
