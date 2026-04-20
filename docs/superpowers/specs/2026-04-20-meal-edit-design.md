# Meal Edit from Diary — Design

**Date:** 2026-04-20
**Status:** Approved, ready for implementation plan.

## Goal

Allow users to edit an existing meal entry from the diary. Today, tapping a meal opens a read-only detail sheet (image + ingredients + delete button). There is no way to correct a title typo, add a missed ingredient, swap the photo, or fix the timestamp without deleting and re-creating the meal.

## Non-goals

- Bulk edit (multi-select) — out of scope.
- Editing fields that aren't captured by the existing meal model (`MealEntry` stays unchanged).
- Changing the create-mode UX.

## Architecture

Reuse the existing `MealTrackerScreen` in a second "edit" mode rather than building a second full form inside the detail sheet. The screen becomes the single source of meal-form UI; the detail sheet stays a lightweight preview surface.

### Tracker screen

- `MealTrackerScreen` gains an optional `MealEntry? initial` constructor parameter.
  - `initial == null` → today's create path. Unchanged.
  - `initial != null` → edit mode. Form state seeds from `initial`; AppBar title switches to "Mahlzeit bearbeiten"; the save button calls `EntriesNotifier.updateMeal(...)` with `initial.copyWith(...form state)` instead of `addMeal(...)`.
- The underlying state notifier for the tracker is initialized with the seed values in `initState` (one-shot seed — subsequent image replacements, ingredient edits, etc. follow the exact same mutation paths as create).
- Save flow: `await updateMeal(...)`, then `ref.invalidate(diaryEntriesProvider(trackedAt))`; if the timestamp was moved to a different calendar day, also invalidate the original day's provider so the meal disappears from the old diary view and appears on the new one. Then `context.pop()` back to the diary.

### Routing

- Add route `RoutePaths.mealTrackerEdit = '/meal-tracker/:id'` alongside the existing `RoutePaths.mealTracker = '/meal-tracker'`.
- The edit route's builder reads the meal by ID from the current diary entries (fall back to `entriesProvider` if needed). If the entry can't be found (stale deep link, user got here from a race), render a simple error scaffold with "Mahlzeit nicht gefunden" + a back button — no crash, no blank screen.

### Diary detail sheet

- `meal_detail_sheet.dart` stays read-only (`canEdit: false` on `DetailSheetScaffold`, so the scaffold's inline-edit pencil does not appear).
- Add a full-width "Bearbeiten" button inside the sheet body above the delete button. Tap: `context.push('/meal-tracker/${meal.id}')`. The sheet does not need to close itself — navigation pushes a new screen on top; after the user saves or discards, returning to the diary drops back to the sheet's underlying route.

### Image replacement in edit mode

Matches create behavior exactly — no edit-mode branch in the ingredient/AI logic:

- Tapping the image in edit mode opens the same camera/gallery picker used in create.
- Once a new image is selected, the existing AI analysis runs.
- AI-returned ingredients **replace** the current ingredient list. A user who has hand-curated ingredients and then replaces the photo will lose those edits. This is an accepted tradeoff for implementation simplicity and UX consistency with create.

### Save / discard flow

- Save button (AppBar action): only active when the form has unsaved changes (reuses the dirty flag). Persists via `updateMeal`, invalidates, pops.
- Back button: if `hasUnsavedChanges == false`, silent pop (normal back). If `true`, intercept via `PopScope` and show a German `AlertDialog`:
  - Title: "Änderungen verwerfen?"
  - Body: "Deine Änderungen gehen verloren."
  - Cancel action: "Weiter bearbeiten" (keeps the user on the edit screen).
  - Destructive action: "Verwerfen" (pops without saving).
- Dirty tracking: compare each form field against the seed `MealEntry`. Flag dirty on any inequality. Seed = the `initial` constructor parameter captured once; current state = live `title`, `ingredients`, `imageUrl` / pending-upload bytes, `notes`, `trackedAt` from the tracker's notifier.
  - Note: comparing `ingredients` is a set-equality comparison (list order is not user-visible).
  - Note: if the user picked a new image but hasn't saved yet, `imageBytes != null` counts as dirty even if `imageUrl` is unchanged.

### Delete

Delete stays exclusively on the detail sheet. No delete affordance on the tracker edit screen — keeps the edit screen focused on editing and matches the "sheet is the entry-type management surface" pattern.

## UI copy (German)

- AppBar title (edit mode): "Mahlzeit bearbeiten" (create mode unchanged).
- Edit button in detail sheet: "Bearbeiten".
- Discard dialog: title "Änderungen verwerfen?", body "Deine Änderungen gehen verloren.", buttons "Weiter bearbeiten" / "Verwerfen".
- Error scaffold on missing meal: "Mahlzeit nicht gefunden".

## Test strategy

**Widget tests — meal detail sheet:**
- Renders the new "Bearbeiten" button alongside delete.
- Tapping "Bearbeiten" navigates to `/meal-tracker/:id` (use a mock GoRouter).

**Widget tests — MealTrackerScreen in edit mode:**
- Seeds all form fields from the passed `MealEntry` (title, ingredients, image URL, notes, timestamp).
- AppBar title is "Mahlzeit bearbeiten".
- Save button is disabled when nothing has changed.
- Changing title → save enabled → tapping save calls `updateMeal` with the new title, pops the route.
- Replacing the image → AI re-analysis runs → ingredient list is replaced → save persists the new list.
- Back button with unsaved changes shows the discard dialog; "Weiter bearbeiten" keeps the user on the screen; "Verwerfen" pops.
- Back button with no unsaved changes pops silently.

**Provider test:**
- `EntriesNotifier.updateMeal` already has coverage (verify at plan time).

**Integration test:**
- Optional: swipe to the meal entry's day, tap entry, tap "Bearbeiten", change title, tap save, verify the new title appears in the diary list for that day.

## Risks / open items

- AI re-analysis wiping hand-curated ingredients is a known footgun. Mitigation: document in the release notes; if users complain, revisit with a confirm-prompt variant (Q3 option C in brainstorming).
- Timestamp moves: editing the timestamp to a different calendar day makes the meal "jump" between diary days. Acceptable — the diary is date-scoped and this matches how the data model already behaves.
- `_DiaryPage` in the PageView will automatically rebuild when `diaryEntriesProvider(date)` is invalidated post-save. No extra wiring needed.

## Out of scope / deferred

- Editing other entry types (gut feeling, toilet, drink) already have inline edit in their detail sheets via `DetailSheetScaffold`. Not touched by this work.
- Version history / undo of meal edits.
- Concurrent-edit conflict resolution (single-device app).
