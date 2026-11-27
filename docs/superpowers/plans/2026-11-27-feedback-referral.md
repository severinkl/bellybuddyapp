# Feedback in der App und Freund:innen einladen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Users send categorised feedback from an in-app form that Severin reads and ticks off in the admin SPA, and can invite friends from „Ich" through the system share sheet.

**Architecture:** Core gets a `feedback` table (admin-only read and `done_at` update via RLS), an authenticated api route `feedback` that validates, rate-limits in the database and stores, a 24-month delete in the existing retention job, and an admin tab. The app replaces the Mailchimp link with a `FeedbackScreen` that posts through `FeedbackService`, and adds an invite row that reuses stage 1's `shareLauncherProvider` with a shared `shareOriginOf` helper.

**Tech Stack:** core: FastAPI, SQLAlchemy async, alembic, pytest; React + Vite + TypeScript + vitest (bun). App: Flutter, Riverpod, GoRouter, supabase_flutter, share_plus (exists), `device_info_plus` (new: OS version).

**Spec:** `docs/superpowers/specs/2026-11-27-feedback-referral-design.md` (app repo, branch `docs/plan-feedback-referral`).

## Repos and commands

| | Core (tasks FC1–FC4) | App (tasks FA1–FA4) |
|---|---|---|
| Repo | `~/projects/bellybuddy-core` | `~/projects/bellybuddy` (new worktree `.worktrees/feedback-referral`) |
| Branch | `feat/feedback-referral` from `feat/share-link` (needs `share_retention.py`, migration `0016`) | `feat/feedback-referral` from `feat/share-link` (needs `shareLauncherProvider`) |
| PR target | `feat/share-link` while it is unmerged, else `develop` | same |
| Stack | `sg docker -c "docker compose up -d --wait"`, then `sg docker -c "docker compose stop worker"`; api 18000, admin 18001, DB 54322 | — |
| Tests | `cd backend && TEST_DATABASE_URL=… uv run pytest <path>` · `cd frontend && bun run test` | `flutter test <path>` |
| Gates | `uv run ruff check . && uv run black --check . && uv run mypy --strict app` · `bun run lint && bun run typecheck && bun run build` | `dart format --set-exit-if-changed . && flutter analyze` |

Order: FC1–FC4, then FA1–FA4 (FA2 needs FC2's contract). The app repo's pre-commit hook fails inside git worktrees: run the app gates by hand and commit with `--no-verify`. No simulator on the dev box: device-only checks are in the spec, §9.

## Global Constraints

- App UI German, „du"; colours only `static const Color` in `AppTheme`; font sizes only `AppTheme.fontSize*`; spacing/radii only `AppConstants`; Riverpod `AsyncNotifier`/providers; GoRouter paths in `lib/router/`; `AppLogger`, never `print()`.
- `test/utils/vocabulary_test.dart` must stay green: no „Empfehlung", „Stuhlgang", „tracken", „erfassen", „Serie", „Speise(n)" in app strings. Mascot is „Belly Buddy" / „Buddy".
- Feedback text, category and reply address never appear in a log line, exception message or Sentry event, in app or core. Log status codes and outcome words only.
- Feedback carries no diary or health data from the app: only category, the user's text, `reply_wanted`, app version, platform, OS version.
- Category keys `idea`, `problem`, `praise`, `other` ↔ labels „Idee", „Problem", „Lob", „Sonstiges". Text: 1–2,000 characters in the app (`AppConstants.feedbackMaxLength = 2000`, grapheme clusters, trimmed); the server accepts 1–4,000 code points (`MESSAGE_MAX_CODE_POINTS = 4000`).
- Limit: 5 feedback rows per user per rolling 24 hours. Retention: 24 months. Account deletion cascades.
- Invite URL `https://bellybuddy.at`; no counting, no analytics, no data about the invited person.
- Core: `mypy --strict`; synthetic test data only; fixtures delete the `profiles` row as well as `auth.users`; German user-facing text.
- No privacy-policy version bump and no policy text change in this plan: the German text is in the spec §5 for the controller's shared „policy text" task.
- Migration number `0017` — renumber (file, `revision`, `down_revision`) if another track's migration lands first.
- Nothing here touches a production host, DNS, secrets or store consoles. Conventional commits; never merge or auto-merge; stop at `gh pr create`.

## Review Focus

1. **Emoji-heavy text at the limit.** 2,000 emoji (incl. ZWJ sequences) pass the app counter and must be stored, not refused with 400. Test in FC2 (`test_feedback_accepts_4000_code_points_refuses_4001`) and FA2 (`feedbackMaxLength counts characters a person sees`).
2. **Six submits in a day, two at once.** The sixth is 429 with `Retry-After`; two parallel fifth-and-sixth submits store exactly five. Test in FC2 (`test_feedback_limit_holds_under_parallel_submits`).
3. **Whitespace-only text or NUL / invalid UTF-8.** Refused with `INVALID_MESSAGE` / `INVALID_CONTEXT`, nothing stored; the app keeps „Senden" disabled for blank text. Tests in FC2 and FA2.
4. **A non-admin (app user, nutritionist) reading or updating feedback through PostgREST.** Zero rows, update denied, insert denied for everyone. Test in FC1 (`test_feedback_rls`).
5. **Submit fails (offline, 429, 500).** The form keeps category and text, shows the right message, stays on screen; no SnackBar „Danke". Test in FA2 (`keeps the text and shows the server message on 429`, `shows the generic message when offline`).

---

## Part 1: Core

### Task FC1: Migration `0017_feedback`

**Files:**
- Create: `backend/migrations/versions/0017_feedback.py`
- Test: `backend/tests/db/test_feedback.py`

**Interfaces — Produces:** table `public.feedback` exactly as spec §4.2 (columns, checks, two indexes, RLS, grants `select, update (done_at)` to `authenticated`, policies „Admins can view feedback" and „Admins can mark feedback done" with `public.has_role(auth.uid(), 'admin')`). Docstring in the style of `0016_data_shares.py` (what, who writes, grants, why).

- [ ] **Step 1: Write the failing tests** (pattern of `tests/db/test_data_shares.py`, synthetic users from `make_user`, rolled back):
  - `test_feedback_checks`: as superuser, a valid insert works; each of `category='bug'`, `message=''`, `message='   '`, `message='x'*4001`, `platform='web'`, `app_version=''`, `os_version='x'*65`, `reply_email='a'` raises a check violation.
  - `test_feedback_rls`: with one row inserted as superuser — as anon `select` is denied; as the row's own user `select count(*)` is 0 and `insert` is denied (`denied(...)` returns a permission error); as an admin (`user_roles` row `admin`) `select` returns the row and `update public.feedback set done_at = now()` hits 1 row, while `update … set message = 'x'` is denied (column grant); as a nutritionist the count is 0.
  - `test_feedback_cascades_with_the_user`: deleting the `auth.users` row removes the user's feedback.
- [ ] **Step 2: Run** `uv run pytest tests/db/test_feedback.py` — expected: FAIL (relation does not exist).
- [ ] **Step 3: Implement** the migration (`revision = "0017"`, `down_revision = "0016"`, `downgrade` drops the table). Message check: `char_length(message) between 1 and 4000 and message ~ '\S'`.
- [ ] **Step 4: Run** the tests — expected: PASS.
- [ ] **Step 5: Commit** `feat(feedback): feedback table, admin-only read and done flag`.

### Task FC2: Route `feedback`

**Files:**
- Create: `backend/app/routes/feedback.py`
- Test: `backend/tests/routes/test_feedback.py`

**Interfaces:**
- Consumes: `app.auth.User` (`.id`, `.email`), `current_user`, `app.body.json_object`, `is_clean_text`, `service_session`, `ApiError`, `fallback_500`.
- Produces: `NAME = "feedback"`; `POST /functions/v1/feedback` with body `{"category": "idea"|"problem"|"praise"|"other", "message": str, "reply_wanted": bool, "app_version": str, "platform": "ios"|"android", "os_version": str}` → `200 {"ok": true}`. Errors `{"error": "<German>"}`: 400 `INVALID_CATEGORY` „Bitte wähle aus, worum es geht.", `INVALID_MESSAGE` „Deine Nachricht muss 1 bis 2000 Zeichen lang sein.", `INVALID_CONTEXT` „Die Anfrage ist ungültig.", `NO_EMAIL` „Für eine Antwort braucht dein Konto eine E-Mail-Adresse."; 429 `TOO_MANY` „Du hast heute schon 5-mal Feedback geschickt. Morgen geht's wieder." with `Retry-After`. Module constants `DAILY_LIMIT = 5`, `MESSAGE_MAX_CODE_POINTS = 4000`, `LOCK_NAMESPACE = 7_160_003`.

- [ ] **Step 1: Write the failing tests** (`api_client`, `seed_user`, JWT with an `email` claim; fixture deletes the test users' `feedback`, `profiles` and `auth.users` rows):
  - `test_feedback_stores_a_row`: a valid body with `reply_wanted: false` → `(200, {"ok": True})`; the row has the category, the trimmed message, `reply_email is None`, the three context values, `done_at is None`.
  - `test_feedback_reply_wanted_stores_the_token_email`: `reply_wanted: true` → `reply_email` equals the JWT's `email`; a JWT without `email` → `(400, {"error": NO_EMAIL})`, no row.
  - `test_feedback_validates`: each of category `"bug"`/`None`, message `""`/`"   "`/`5`, `reply_wanted` `"yes"`, platform `"web"`, `app_version` `""` or 33 chars, `os_version` 65 chars, a message holding `"\x00"`, a non-object body → 400 with the matching constant; no rows.
  - `test_feedback_accepts_4000_code_points_refuses_4001`: `"👍" * 4000` → 200; `"👍" * 4001` → `(400, {"error": INVALID_MESSAGE})`.
  - `test_feedback_limit_is_five_per_day`: five posts → 200; the sixth → 429 with `TOO_MANY` and an integer `Retry-After` between 1 and 86400; a row of the same user aged 25 hours (inserted directly) does not count.
  - `test_feedback_limit_holds_under_parallel_submits`: with four rows stored, two posts via `asyncio.gather` → one 200, one 429, five rows.
  - `test_feedback_requires_auth`: no token → 401.
  - `test_feedback_logs_no_text` (`caplog`): after a stored and a refused post, no record contains the message, the address or the category key.
- [ ] **Step 2: Run** `uv run pytest tests/routes/test_feedback.py` — expected: FAIL (404).
- [ ] **Step 3: Implement** `async def submit_feedback(request: Request, user: Annotated[User, Depends(current_user)]) -> JSONResponse` and a pure `_validated(body: dict[str, Any], email: str | None) -> dict[str, Any]` (mirrors the table checks, trims the message, `len()` counts code points). In one `service_session`: advisory lock `(LOCK_NAMESPACE, hashtext(:uid))`, `select count(*), min(created_at)` of the last 24 hours, 429 at `DAILY_LIMIT` (`Retry-After` = ceil seconds until `min + 24 h`), else insert. Module docstring in the style of `portal_interest.py`. Logs: `"feedback stored"` / `"feedback refused: <reason>"`.
- [ ] **Step 4: Run** the tests — expected: PASS.
- [ ] **Step 5: Commit** `feat(feedback): authenticated feedback route with a daily limit`.

### Task FC3: Retention and admin tab

**Files:**
- Modify: `backend/app/jobs/share_retention.py` (docstring, `DELETE_FEEDBACK_SQL`, `ShareRetentionRun.feedback_deleted: int`, log line `"share retention: %d shares, %d sign-up addresses, %d feedback deleted"`)
- Modify: `backend/tests/jobs/test_share_retention.py`
- Create: `frontend/src/pages/admin/FeedbackTab.tsx`, `frontend/src/pages/admin/FeedbackTab.test.tsx`
- Modify: `frontend/src/pages/admin/index.ts`, `frontend/src/pages/admin/types.ts` (`FeedbackRow`, `FEEDBACK_CATEGORY_LABELS`, `ITEMS_PER_PAGE.feedback = 50`), `frontend/src/App.tsx` (route `feedback`), `frontend/src/pages/Admin.tsx` (nav item), `frontend/src/integrations/supabase/types.ts` (`feedback` table Row/Insert/Update)

**Interfaces:**
- Consumes: FC1's table; `useAdminListQuery`, `PaginationBar`, `fmtDate`, ui `select`, `checkbox`, `badge`.
- Produces: `export function FeedbackTab(): JSX.Element`; `export interface FeedbackRow { id: string; category: 'idea'|'problem'|'praise'|'other'; message: string; reply_email: string | null; app_version: string; platform: 'ios'|'android'; os_version: string; created_at: string; done_at: string | null }`; `FEEDBACK_CATEGORY_LABELS = { idea: 'Idee', problem: 'Problem', praise: 'Lob', other: 'Sonstiges' }`.

- [ ] **Step 1: Write the failing tests:**
  - `test_share_retention.py::test_feedback_older_than_24_months_is_deleted`: rows aged `24 months 1 day` and `23 months` for a synthetic user → the run reports `feedback_deleted == 1`, the younger row remains.
  - `FeedbackTab.test.tsx` (supabase mocked as in `Admin.test.tsx`): renders message text, „Idee" badge and date; „Antwort an: dana@example.com" as a `mailto:` link only on the row with `reply_email`; choosing „Lob" in the filter queries `eq('category', 'praise')`; ticking „Erledigt" calls `update({ done_at: <ISO string> })` with `eq('id', …)`, unticking sends `done_at: null`; an update error shows the toast „Konnte nicht gespeichert werden." and restores the box; a message `<b>x</b>` renders as literal text.
  - `Admin.test.tsx`: the nav shows „Feedback (2)" when the open-count query returns 2, and „Feedback" for 0.
- [ ] **Step 2: Run** `uv run pytest tests/jobs/test_share_retention.py` and `bun run test` — expected: FAIL.
- [ ] **Step 3: Implement** the job change and the tab per spec §4.2 (filter „Alle" = no filter; done rows muted; user id not shown). Admin nav count: `select('id', { count: 'exact', head: true }).is('done_at', null)` on mount and after the tab marks a row (a small callback or event; builder's choice).
- [ ] **Step 4: Run** the tests — expected: PASS.
- [ ] **Step 5: Commit** `feat(feedback): delete after 24 months, admin feedback tab`.

### Task FC4: Core gates and PR

- [ ] **Step 1:** `uv run ruff check . && uv run black --check . && uv run mypy --strict app`; the full `uv run pytest` with the worker stopped; `bun run lint && bun run typecheck && bun run build && bun run test`. Expected: all green.
- [ ] **Step 2:** Against the local stack: `curl` a feedback with a minted user JWT to `localhost:18000/functions/v1/feedback` → `{"ok":true}`; open `localhost:18001/admin/feedback` as the dev admin, see it, tick „Erledigt", reload, still ticked.
- [ ] **Step 3:** After the owner's routine (simplify → code review → fix), push and open a PR `feat: in-app feedback with admin list` to `feat/share-link` (or `develop` if merged), linking the spec and noting the policy text pending in the shared task. Stop there.

---

## Part 2: App

### Task FA1: `device_info_plus`, context provider and `FeedbackService`

**Files:**
- Modify: `pubspec.yaml` (add `device_info_plus`, current major — reason: OS version; `Platform.operatingSystemVersion` is a kernel string on Android)
- Create: `lib/models/feedback.dart` (plain Dart, no Freezed), `lib/services/feedback_service.dart`, `lib/providers/feedback_context_provider.dart`
- Test: `test/services/feedback_service_test.dart`, `test/providers/feedback_context_provider_test.dart`

**Interfaces — Produces:**
- `enum FeedbackCategory { idea, problem, praise, other }` with `String get jsonValue` (`'idea'` …) and `String get label` (`'Idee'`, `'Problem'`, `'Lob'`, `'Sonstiges'`).
- `class FeedbackContext { const FeedbackContext({required this.appVersion, required this.platform, required this.osVersion}); final String appVersion; final String platform; /* 'ios' | 'android' */ final String osVersion; String get systemLabel; /* 'iOS 18.1' | 'Android 14' */ }`
- `final feedbackContextProvider = FutureProvider<FeedbackContext>` — version from `currentVersionProvider`, OS from `device_info_plus` (`IosDeviceInfo.systemVersion`, `AndroidDeviceInfo.version.release`); any failure yields `'unbekannt'` for that value. The device-info read sits behind `final osVersionReaderProvider = Provider<Future<String> Function()>` so tests replace it.
- `class FeedbackException implements Exception { const FeedbackException({this.status, this.message}); final int? status; final String? message; }`
- `class FeedbackService { Future<void> send({required FeedbackCategory category, required String message, required bool replyWanted, required FeedbackContext context}); }` → `functions.invoke('feedback', body: {...})` with the FC2 body; `FunctionException` → `FeedbackException(status, message from details['error'])`; any other error → `const FeedbackException()`. `final feedbackServiceProvider = Provider<FeedbackService>`.
- `AppConstants.feedbackMaxLength = 2000`.

- [ ] **Step 1: Write the failing tests:**
  - `send posts the contract body`: a fake `SupabaseClient`/functions client records `('feedback', {'category': 'praise', 'message': 'Super App', 'reply_wanted': true, 'app_version': '1.3.0', 'platform': 'ios', 'os_version': '18.1'})`.
  - `send maps a 429 to FeedbackException with the server message`: `status == 429`, `message == "Du hast heute schon 5-mal Feedback geschickt. Morgen geht's wieder."`.
  - `send maps a socket error to FeedbackException without message`.
  - `systemLabel`: `ios`/`18.1` → `'iOS 18.1'`; `android`/`14` → `'Android 14'`.
  - `context falls back to unbekannt` when the OS reader throws.
  - `send never logs the message` (capture `AppLogger` output; the text `Super App` is absent).
- [ ] **Step 2: Run** `flutter test test/services/feedback_service_test.dart test/providers/feedback_context_provider_test.dart` — expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the tests and both app gates — expected: PASS.
- [ ] **Step 5: Commit** `feat(feedback): feedback service and device context`.

### Task FA2: `FeedbackScreen`, route, Ich row

**Files:**
- Create: `lib/screens/me/feedback_screen.dart`
- Modify: `lib/router/route_names.dart` (`RouteNames.feedback = 'feedback'`, `RoutePaths.feedback = '/me/feedback'`), `lib/router/app_router.dart`, `lib/screens/me/me_screen.dart` (row pushes the route; drop `_openFeedback`; keep `openUrl` only if still used, else remove the parameter), `lib/config/constants.dart` (remove `feedbackFormUrl`)
- Delete: `test/config/feedback_url_test.dart`
- Test: `test/screens/me/feedback_screen_test.dart`, `test/screens/me/me_screen_test.dart` (replace the Mailchimp-launch tests)

**Interfaces — Consumes:** FA1's `FeedbackCategory`, `feedbackContextProvider`, `feedbackServiceProvider`, `FeedbackException`; the signed-in user's e-mail from `currentUserProvider` (`User?.email`). Keys: `FeedbackScreen.categoryKey(FeedbackCategory)`, `messageKey`, `replyKey`, `sendKey`.

Copy (exact): spec §4.1 — „Worum geht es?", „Deine Nachricht", hint „Was ist dir aufgefallen, was wünschst du dir?", „Bitte schreib hier keine Gesundheitsdaten hinein, die du nicht teilen möchtest.", „Antwort erwünscht", „Wir antworten an <address>.", „Das wird mitgeschickt:", „App-Version <v>", „System: <label>", „Keine Tagebuch- oder Gesundheitsdaten.", „Senden", success SnackBar „Danke! Dein Feedback ist angekommen.", generic error „Das hat nicht geklappt. Versuch es später nochmal."

- [ ] **Step 1: Write the failing tests** (`feedback_screen_test.dart`, service and context overridden):
  - `Senden is disabled until a category and non-blank text`: none → disabled; category only → disabled; category + `'   '` → disabled; category + `'Idee!'` → enabled.
  - `shows the context lines`: „App-Version 1.3.0", „System: iOS 18.1", „Keine Tagebuch- oder Gesundheitsdaten." and the warning line.
  - `reply switch shows the account address and is hidden without one`.
  - `feedbackMaxLength counts characters a person sees`: entering 2,001 `👨‍👩‍👧` leaves 2,000 in the field; counter „2000 / 2000".
  - `sends trimmed text with category, reply flag and context, then pops with the thanks SnackBar` (pushed from a host route; after send the host is visible with „Danke! Dein Feedback ist angekommen.").
  - `keeps the text and shows the server message on 429`.
  - `shows the generic message when offline` (`FeedbackException()`), text and category kept, no thanks SnackBar.
  - `locks the form while sending` (second tap on „Senden" sends nothing more).
  - `me_screen_test.dart`: tapping „Feedback geben" pushes `RoutePaths.feedback`; no URL launch happens.
- [ ] **Step 2: Run** `flutter test test/screens/me` — expected: FAIL.
- [ ] **Step 3: Implement** per spec §4.1; category choice uses the segmented style of „Zeitraum" in `share_create_screen.dart`; `TextField(maxLength: AppConstants.feedbackMaxLength)` (Flutter counts grapheme clusters); logs carry status and outcome only.
- [ ] **Step 4: Run** the tests, `flutter test test/utils/vocabulary_test.dart test/router`, and both gates — expected: PASS.
- [ ] **Step 5: Commit** `feat(feedback): in-app feedback form replaces the Mailchimp survey`.

### Task FA3: `shareOriginOf` and the invite row

**Files:**
- Create: `lib/utils/share_origin.dart`
- Modify: `lib/screens/shares/widgets/share_created_sheet.dart` (`_send` uses the helper), `lib/screens/me/me_screen.dart` (invite row, `MeScreen.inviteKey = Key('me_invite')`, class doc lists the row), `lib/config/constants.dart`
- Test: `test/utils/share_origin_test.dart`, `test/screens/me/me_screen_test.dart`, `test/config/invite_text_test.dart`

**Interfaces:**
- Consumes: `shareLauncherProvider` (`Future<void> Function(String text, Rect origin)`).
- Produces: `Rect shareOriginOf(BuildContext? context)`; `AppConstants.inviteUrl = 'https://bellybuddy.at'`; `AppConstants.inviteShareText = 'Schau dir mal Belly Buddy an: Damit schreibst du auf, was du isst und wie es deinem Bauch geht, und ein kleiner Buddy begleitet dich dabei. $inviteUrl'`.

- [ ] **Step 1: Write the failing tests:**
  - `shareOriginOf`: a `SizedBox(100×40)` at offset (20, 300) → `Rect.fromLTWH(20, 300, 100, 40)`; `null` → `Rect.zero`.
  - `invite_text_test.dart`: `inviteShareText` ends with `https://bellybuddy.at` and contains „Belly Buddy".
  - `me_screen_test.dart`: the row „Freund:innen einladen" / „Erzähl anderen von Belly Buddy" is the last row, after „Feedback geben"; tapping it calls the launcher once with `inviteShareText` and a non-zero origin inside the row's rect; a throwing launcher shows „Das Teilen hat nicht geklappt." and the screen stays usable.
  - Existing `share_created_sheet_test.dart` still passes unchanged.
- [ ] **Step 2: Run** `flutter test test/utils/share_origin_test.dart test/screens/me test/config/invite_text_test.dart test/screens/shares` — expected: FAIL on the new tests.
- [ ] **Step 3: Implement.** The row's origin comes from a `GlobalKey` on the `BbSettingsItem` (or a `Builder` context) passed to `shareOriginOf`.
- [ ] **Step 4: Run** the tests and both gates — expected: PASS.
- [ ] **Step 5: Commit** `feat(me): invite friends from Ich via the share sheet`.

### Task FA4: App gates and PR

- [ ] **Step 1:** `dart format --set-exit-if-changed .`, `flutter analyze`, full `flutter test`. Expected: all green.
- [ ] **Step 2:** If the rating-prompt branch merged first, place „Freund:innen einladen" after „Feedback geben" and keep „Belly Buddy bewerten" above „Feedback geben" (spec decision 18); resolve the `me_screen.dart` conflict accordingly.
- [ ] **Step 3:** After the owner's routine (simplify → code review → fix), push and open a PR `feat: in-app feedback form and invite friends` to `feat/share-link` (or `develop` if merged), linking the spec, the core PR, and spec §8/§9 (needs from Severin, device checks). App and core ship together. Stop there.
