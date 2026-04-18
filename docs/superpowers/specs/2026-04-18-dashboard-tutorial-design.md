# Dashboard Tutorial — Design Spec

**Date:** 2026-04-18
**Status:** Approved design — ready for implementation plan
**Scope:** Guided, first-time tour of the dashboard that highlights 10 features in a fixed order, with replay from Settings.

## Motivation

Users who finish the 7-step registration wizard land on a feature-rich dashboard (two tracker cards, four "Für dich erstellt" cards, a central meal-tracker FAB, and two header icons) without any in-app guidance about what each element does. The user has provided 10 mockups in `Anleitung Homescreen/` showing a coach-mark / spotlight pattern: the dashboard dims, one element stays fully visible, and a speech-bubble with a hairline connector explains what that feature is for. The tutorial walks through all 10 elements in a fixed order.

## Goals

- Teach new users what each dashboard element is for, in a low-effort, skippable way.
- Match the mockup aesthetic precisely (rounded speech bubble + thin connector line) so the tutorial feels bespoke, not generic.
- Let returning users replay the tour on demand from Settings.
- Persist the "seen" state per-user (not per-device) so reinstalls or device switches don't force a repeat.

## Non-Goals

- Per-step deep linking into the feature being highlighted (users can't tap the highlighted card to open it during the tour — tap anywhere advances).
- Multiple tour variants (one tour, one order, for every user).
- Contextual/inline tooltips elsewhere in the app.
- Analytics on completion rate (not requested; can be added later).

## User-facing decisions

| Question | Decision |
|---|---|
| Trigger | Auto on first dashboard load for any user (fresh install or app update); also a manual "Tour neu starten" button in Settings. |
| Coexistence with notification opt-in modal | Tutorial first, notification modal afterwards. |
| Advance interaction | Tap anywhere → next step. Small "Überspringen" link top-right exits early. |
| Persistence | `profiles.tutorial_seen_at` (Supabase). No local cache. |
| Highlighted-element tap behavior | Advances the tour (same as tapping elsewhere); does NOT open the feature. |

## Step order (fixed, from the mockups)

The 10 steps run in the numeric order of the filenames in `Anleitung Homescreen/`:

1. **Bauchgefühl-Tracker** (top-left tracker tile) — "Tracke deine **Beschwerden und deine Befindlichkeit** hier, um uns zu helfen, einen Zusammenhang zwischen deiner Ernährung und deinem Wohlbefinden herauszufinden."
2. **Klo-Tracker** (top-right tracker tile) — "Wann, wie oft und in welcher Form du auf's Klo gehst, ist ebenfalls eine sehr wichtige Information. Hier kannst du **deinen Stuhlgang tracken**."
3. **Essen tracken** (center FAB in bottom nav) — "Tracke **Speisen und Getränke**, die du zu dir nimmst. Je regelmäßiger du das tust, desto besser können wir dir Tipps für mehr Wohlbefinden geben."
4. **Für dich** (top-left feature card) — "Hol dir 1 x pro Tag Feedback zu **deinen Speisen und Getränken** und erfahre, was du in Zukunft anders machen kannst, um dich wohler zu fühlen."
5. **Alternativen** (top-right feature card) — "Alle besser **verträglichen Lebensmittel-Alternativen** basierend auf deinen Speisen findest du hier."
6. **Wissen** (bottom-right feature card) — "Du willst mehr über die Themen Verdauung, ungeniert Pupsen und Co erfahren? **Hier geht's zum Blog!**"
7. **Rezepte** (bottom-left feature card) — "Auf deine Bedürfnisse angepasste Rezepte findest du (sehr bald) hier."
8. **Tagebuch** (bottom nav, right) — "Was hast du wann gegessen und wie ist es dir dabei gegangen? Eine **Übersicht** über alle deine erfassten Daten findest du hier."
9. **Feedback-Icon** (dashboard header, top-right) — "**Fragen und Feedback zur App** kannst du uns hier ganz einfach schicken."
10. **Einstellungen / Settings-Gear** (dashboard header, top-right) — "Alle **Einstellungen** zu deinem Profil kannst du hier einsehen und bearbeiten."

The bold segments in each string are rendered bold via `TextSpan`; the rest is regular weight. Copy is taken verbatim from the mockups.

## Architecture

```
┌────────────────────────────────────────────┐
│ DashboardScreen / BbBottomNav              │
│  ├─ attach 10 GlobalKeys via TutorialKeys  │
│  └─ in initState: maybeStart() after load  │
│                                            │
│ tutorialProvider (Riverpod AsyncNotifier)  │
│  ├─ reads profileProvider (SSOT)           │
│  ├─ hasSeen, markSeen(), reset()           │
│  └─ writes profiles.tutorial_seen_at       │
│                                            │
│ DashboardTutorialOverlay (Overlay entry)   │
│  ├─ SpotlightPainter (dim + cutout)        │
│  ├─ TooltipBubble (speech bubble)          │
│  ├─ ConnectorLine (hairline to target)     │
│  ├─ GestureDetector → advance              │
│  └─ "Überspringen" link → finish           │
│                                            │
│ SettingsScreen                             │
│  └─ "Tour neu starten" row → reset()       │
└────────────────────────────────────────────┘
```

**Trade-off note:** The existing codebase (`lib/providers/profile_provider.dart`) does not use an explicit Repository layer — providers access Supabase either directly or via thin `lib/services/` classes. The tutorial follows that existing pattern: `tutorialProvider` talks to `profileProvider` rather than introducing a `ProfileRepository`. A dedicated Repository layer may be appropriate later as a cross-cutting refactor, but is out of scope here.

## Data model

### Supabase migration

```sql
ALTER TABLE profiles
ADD COLUMN tutorial_seen_at TIMESTAMPTZ NULL;
```

- Nullable: `NULL` means never seen; a timestamp means seen at that moment.
- Timestamp (not bool) so we can tell when the user first saw it — useful later for bumping users through a revised tour if copy or order changes.

### Dart model changes

`Profile` (freezed) gains `DateTime? tutorialSeenAt`, JSON key `tutorial_seen_at`. Regenerate with `dart run build_runner build --delete-conflicting-outputs`.

## Components

### `tutorialProvider` (Riverpod `AsyncNotifier<TutorialState>`)

State:
```dart
sealed class TutorialState {
  const factory TutorialState.unseen() = TutorialUnseen;
  const factory TutorialState.seen(DateTime at) = TutorialSeen;
}
```

Methods:
- `maybeStart()` — returns `true` if the current profile has `tutorialSeenAt == null`, signaling the dashboard should insert the overlay. Pure query; does not mutate.
- `markSeen()` — updates `profiles.tutorial_seen_at = now()` for the current user via Supabase, then calls `ref.refresh(profileProvider)`. Called both on normal finish and on "Überspringen".
- `reset()` — sets `tutorial_seen_at = null`, then refreshes the profile provider.

Reads the existing `profileProvider` as the source of truth. No SharedPreferences cache — the profile is already loaded on dashboard init (`dashboard_screen.dart:35`), so the flag is available without an extra round-trip.

### `DashboardTutorialOverlay` (StatefulWidget, inserted via `Overlay.of(context).insert(...)`)

Responsibilities:
- Hold the current step index (0..9).
- Measure the current step's target `Rect` after each step change using `WidgetsBinding.instance.addPostFrameCallback` + `GlobalKey.currentContext.findRenderObject()`.
- If the target is not fully in the viewport, call `Scrollable.ensureVisible(targetContext)`, wait one more frame, then re-measure before painting.
- Render the spotlight, bubble, and connector line.
- Handle tap-to-advance and skip.
- Call `onFinish` when index reaches the end OR when the user taps "Überspringen".

Structure:
```
Stack
├─ GestureDetector (advance)             // catches taps everywhere
│   └─ CustomPaint (SpotlightPainter)     // dim + cutout
├─ Positioned (bubble + connector)
│   └─ Column
│       ├─ TooltipBubble
│       └─ ConnectorLine (above OR below bubble, toward target)
└─ Positioned (top-right, inside safe-area)
    └─ TextButton "Überspringen"
```

The "Überspringen" button sits above the advance `GestureDetector` in the Stack so its tap target wins.

Animations: 150ms fade-in on initial insert; 150ms fade-out on finish. No per-step transition — steps snap.

### `SpotlightPainter` (`CustomPainter`)

Paints a full-screen rounded-rect semi-transparent black layer (~55% opacity) with a cutout over the target rect. Cutout uses `Path.combine(PathOperation.difference, screenPath, targetPath)` where `targetPath` is the target rect inflated by `AppConstants.spacingSm` padding and with `AppConstants.radiusLg` corner radius to match the tile styling. Repaints only when the target rect changes.

### `TooltipBubble` (StatelessWidget)

- Rounded white container, `AppConstants.radiusLg` corners, `AppTheme.shadow` elevation.
- Padding: `AppConstants.paddingMd`.
- Content: `RichText` built from the step's `List<InlineSpan>`, with bold spans styled via `FontWeight.w700` and the same base `AppTheme.fontSizeBody` size.
- Max width: 80% of screen width, `LayoutBuilder`-derived. Text centered.

### `ConnectorLine` (`CustomPainter`)

- 1.2-logical-pixel stroke in `AppTheme.foreground`.
- Two endpoints: attached to the bubble edge nearest the target, and to a point just outside the target's spotlight cutout. Drawn as a single straight `Path`.
- Repaints with the spotlight.

### Layout positioning (`_anchorBubble(targetRect, screenSize, safeArea)`)

Small pure function: given the target rect and screen metrics, choose **above** or **below** the target, then compute the bubble's top-left offset so its horizontal center aligns with the target's horizontal center (clamped to stay on-screen with `AppConstants.spacingLg` margin). Falls back to the opposite side if the chosen side has less than 120px of vertical space after accounting for safe-area insets. All magic numbers live in `AppConstants`.

### `TutorialKeys` (shared keys)

`lib/screens/dashboard/widgets/tutorial/tutorial_keys.dart`:

```dart
class TutorialKeys {
  TutorialKeys._();
  static final bauchgefuehl = GlobalKey(debugLabel: 'tutorial.bauchgefuehl');
  static final klo           = GlobalKey(debugLabel: 'tutorial.klo');
  static final essenTracken  = GlobalKey(debugLabel: 'tutorial.essenTracken');
  static final fuerDich      = GlobalKey(debugLabel: 'tutorial.fuerDich');
  static final alternativen  = GlobalKey(debugLabel: 'tutorial.alternativen');
  static final wissen        = GlobalKey(debugLabel: 'tutorial.wissen');
  static final rezepte       = GlobalKey(debugLabel: 'tutorial.rezepte');
  static final tagebuch      = GlobalKey(debugLabel: 'tutorial.tagebuch');
  static final feedback      = GlobalKey(debugLabel: 'tutorial.feedback');
  static final settings      = GlobalKey(debugLabel: 'tutorial.settings');
}
```

A single static-keys class is the simplest bridge between the dashboard tree and the bottom-nav tree (which live in different subtrees because of `StatefulShellRoute`).

### `TutorialStep` (data class)

```dart
class TutorialStep {
  final GlobalKey targetKey;
  final List<InlineSpan> richText;     // bold keywords as TextSpan with FontWeight.w700
  final double targetRadius;           // corner radius for the spotlight cutout
  const TutorialStep({
    required this.targetKey,
    required this.richText,
    this.targetRadius = AppConstants.radiusMd,
  });
}
```

The 10 steps are declared as a single `const List<TutorialStep>` in `dashboard_tutorial_steps.dart`, in the fixed order above.

## Wiring changes

### Attaching keys (no structural changes)

| Key | File | Widget |
|---|---|---|
| `bauchgefuehl` | `lib/screens/dashboard/dashboard_screen.dart` | left `TrackerCard` in `_TrackerCards` |
| `klo` | `lib/screens/dashboard/dashboard_screen.dart` | right `TrackerCard` in `_TrackerCards` |
| `fuerDich` | `lib/screens/dashboard/dashboard_screen.dart` | "Für dich" `FeatureCard` |
| `alternativen` | `lib/screens/dashboard/dashboard_screen.dart` | "Alternativen" `FeatureCard` |
| `rezepte` | `lib/screens/dashboard/dashboard_screen.dart` | "Rezepte" `FeatureCard` |
| `wissen` | `lib/screens/dashboard/dashboard_screen.dart` | "Wissen" `FeatureCard` |
| `feedback` | `lib/screens/dashboard/dashboard_screen.dart` | feedback `CircleIconButton` |
| `settings` | `lib/screens/dashboard/dashboard_screen.dart` | settings `CircleIconButton` |
| `essenTracken` | `lib/widgets/common/bb_bottom_nav.dart` | `_CenterButton` |
| `tagebuch` | `lib/widgets/common/bb_bottom_nav.dart` | Tagebuch `_NavItem` |

### Orchestration in `DashboardScreen`

- `_DashboardScreenState.initState`:
  1. `await _loadData()` (unchanged).
  2. `if (ref.read(tutorialProvider.notifier).maybeStart())` → insert overlay via `Overlay.of(context).insert(...)`. The overlay's `onFinish` callback calls `_maybeShowNotificationModal()`.
  3. `else` → call `_maybeShowNotificationModal()` directly (current behavior).

### Settings replay

- `lib/screens/settings/settings_screen.dart`: add a `ListTile` "Tour neu starten" near the bottom of the general section.
- Tap → show `AlertDialog` ("Möchtest du die Einführung erneut starten?" / "Abbrechen" / "Neu starten").
- On confirm: `await ref.read(tutorialProvider.notifier).reset()` → `if (mounted) context.pop()` — returning to the dashboard, where the normal init path re-triggers the overlay.

## Data flow

```
[User finishes registration] → [navigate to /dashboard]
       ↓
DashboardScreen.initState → _loadData() → profile loaded
       ↓
tutorialProvider.maybeStart() reads profile.tutorialSeenAt
       ↓
[null?] ─yes→ insert overlay → walk 10 steps → markSeen() → onFinish() → notification modal
       ↓
[null?] ─no→  skip overlay → notification modal check (existing logic)
```

```
[Settings: "Tour neu starten"] → confirm dialog → reset() → pop to dashboard
       ↓
Profile refresh causes tutorialSeenAt = null → overlay re-inserts
```

## Error handling

- **Supabase write fails in `markSeen()`:** log via `AppLogger`, still close the overlay. On the next dashboard load the user may see the tour again — acceptable; it's a UX annoyance, not a data loss. We do not block the UI on the write.
- **Supabase write fails in `reset()`:** log, show a `SnackBar` with a German message ("Konnte die Tour nicht zurücksetzen. Bitte versuche es später erneut."), keep the user on Settings.
- **Target key has no `RenderObject` (e.g., widget not yet laid out):** skip that step, log, move to the next. Defensive; shouldn't fire given the post-frame guard.
- **Screen rotation mid-tour:** the overlay listens for `MediaQuery` changes and re-measures. Acceptable even if slightly jumpy.

## Testing strategy

### Unit tests — `test/providers/tutorial_provider_test.dart`
- `hasSeen` returns `false` when `profile.tutorialSeenAt` is null; `true` otherwise.
- `markSeen()` calls the Supabase update with a non-null timestamp and invalidates `profileProvider`.
- `reset()` calls the Supabase update with `null`.
- Uses a `FakeProfileNotifier` and a fake Supabase client (no network).

### Widget tests — `test/screens/dashboard/tutorial_overlay_test.dart`
- Pumps the overlay with 3 fake steps and pre-placed keys in a minimal widget tree.
- Tapping the background advances from step 0 → 1 → 2 → finish (callback invoked).
- Tapping "Überspringen" on step 0 calls `onFinish` immediately.
- The spotlight rect matches the target key's global rect (verified via `tester.getRect`).
- Bubble anchors above when the target is near the bottom; below when near the top.

### Integration test — `integration_test/tutorial_flow_test.dart`
- Fresh-install path: open app → sign in → finish registration → dashboard shows step 1 → tap through all 10 → notification opt-in modal appears.
- Replay path: from dashboard (already seen) → Settings → "Tour neu starten" → confirm → tutorial reappears on dashboard.

## File inventory

**New:**
- `lib/providers/tutorial_provider.dart`
- `lib/screens/dashboard/widgets/tutorial/tutorial_keys.dart`
- `lib/screens/dashboard/widgets/tutorial/dashboard_tutorial_overlay.dart`
- `lib/screens/dashboard/widgets/tutorial/spotlight_painter.dart`
- `lib/screens/dashboard/widgets/tutorial/tooltip_bubble.dart`
- `lib/screens/dashboard/widgets/tutorial/connector_line.dart`
- `lib/screens/dashboard/widgets/tutorial/tutorial_step.dart`
- `lib/screens/dashboard/widgets/tutorial/dashboard_tutorial_steps.dart`
- `test/providers/tutorial_provider_test.dart`
- `test/screens/dashboard/tutorial_overlay_test.dart`
- `integration_test/tutorial_flow_test.dart`
- `supabase/migrations/<timestamp>_add_tutorial_seen_at.sql`

**Modified:**
- `lib/models/profile.dart` (+ regenerated `.freezed.dart` / `.g.dart`)
- `lib/screens/dashboard/dashboard_screen.dart` (attach 8 keys, integrate overlay)
- `lib/widgets/common/bb_bottom_nav.dart` (attach 2 keys)
- `lib/screens/settings/settings_screen.dart` (replay row + dialog)
- Any German copy for dialog strings added to existing i18n tables if present.

## Rollout

- No feature flag. Ship with the next app update.
- Users who already have the app installed have `tutorial_seen_at = NULL` (new column default) and will see the tutorial once on next dashboard open — acceptable and intentional.
- If we later change the tour (copy, order, new steps), we can bump a tour version by adding a `tutorial_version_seen` column or clearing `tutorial_seen_at` for all users in a migration.

## Open questions

None. Design is fully specified for implementation.
