# Recipes tutorial step copy update — design

**Date:** 2026-04-26
**Status:** Approved, ready for implementation plan
**Scope:** Replace the `TutorialKeys.rezepte` dashboard-tutorial step's copy to reflect the now-shipped recipes feature (user-saved recipes, save-from-meal, prefill meal tracker from recipe).

## Problem

The 7th tutorial step on the dashboard (anchored to the Rezepte tab card) currently reads:

> "Auf deine Bedürfnisse angepasste Rezepte findest du (sehr bald) hier."

This was written when recipes were vaporware. The feature has now shipped: users can save their own recipes, search/filter them, save from a tracked meal, build from scratch, and tap a recipe to prefill the meal tracker. The "(sehr bald)" qualifier is wrong, and the framing ("auf deine Bedürfnisse angepasste") implies a curated/recommendation system that doesn't match the actual user-owned library.

## Goal

The step:

1. Names what the user finds on the screen (their own saved recipes).
2. Explains the save-loop in one sentence: track a meal, save it as a recipe, re-track later.
3. Drops the "(sehr bald)" qualifier.
4. Keeps the existing single-bold-emphasis style consistent with the other tutorial steps.

## Approach

### Component layout

**Modify (1 file):**
- `lib/screens/dashboard/widgets/tutorial/dashboard_tutorial_steps.dart` — replace the `richText` list in the `TutorialKeys.rezepte` step.

The step's `targetKey`, `targetRadius`, and `preferredAnchor` stay unchanged. No new files, no new tutorial keys, no re-ordering.

### The diff

Current `richText` (1 plain `TextSpan`):

```dart
richText: [
  _t(
    'Auf deine Bedürfnisse angepasste Rezepte findest du (sehr bald) hier.',
  ),
],
```

New `richText` (2 plain + 1 bold `TextSpan`):

```dart
richText: [
  _t('Hier findest du '),
  _b('deine gespeicherten Rezepte'),
  _t(
    '. Speicher Mahlzeiten als Rezept, um sie später schneller wieder einzutragen.',
  ),
],
```

The bold lands on the surface name (`deine gespeicherten Rezepte`); the second sentence explains the save-loop without competing for attention. Pattern matches existing steps (e.g. `bauchgefuehl`, `klo`, `essenTracken`) which use a single `_b` for the most important phrase.

## Tests

No new test. The dashboard tutorial copy isn't pinned by any existing test, and adding a snapshot for one step's literal string would invent test infrastructure for a copy change. The change is verifiable manually by replaying the dashboard tutorial.

## Acceptance

- Step 7 of the dashboard tutorial (anchored to the Rezepte tab card) now reads: **"Hier findest du deine gespeicherten Rezepte. Speicher Mahlzeiten als Rezept, um sie später schneller wieder einzutragen."** with `deine gespeicherten Rezepte` rendered bold.
- The "(sehr bald)" qualifier is gone.
- All other tutorial steps are unchanged.
- `flutter analyze` clean. `dart format` clean.

## Out of scope

- Adding a screenshot or illustration to the tooltip — the tutorial's visual treatment is uniform across all 10 steps.
- Re-ordering tutorial steps — preserves the 1-10 sequence the mockups document in `Anleitung Homescreen/`.
- Updating the reference mockups in `Anleitung Homescreen/` — those are frozen documentation assets, not code.
- A second emphasis bold on the save-loop phrase ("später schneller wieder einzutragen"). Single-bold is the codebase convention.

## Risks

- The new copy is one line longer than the original. The tooltip's bubble reflows automatically for longer steps (verified by inspection of `klo` and `tagebuch` steps, which carry similarly long copy without truncation), so no layout change is expected. Confirm during manual smoke.
