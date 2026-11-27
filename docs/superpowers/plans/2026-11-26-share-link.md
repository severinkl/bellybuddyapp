# Tagebuch per Link teilen (Stufe 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A client creates a code-protected, live, read-only share of their diary in the app, and a dietitian opens it in a browser.

**Architecture:** Core gets a `data_shares` table, an authenticated `shares` route (create, end) and a public `share-view` route (open with token + code, load data with a short view session). A new repo, `bellybuddy-connect`, holds the dietitian-facing web page `/teilen`, served by core's Caddy at `connect.bellybuddy.at`. The app lists shares through PostgREST, creates and ends them through the api, and keeps link and code on the device. Patterns in the view come from core's existing `insights.py`.

**Tech Stack:** core: FastAPI, SQLAlchemy async, alembic, PyJWT, pytest; React + Vite + TypeScript + vitest (bun). App: Flutter, Riverpod, GoRouter, Freezed, supabase_flutter.

**Spec:** `docs/superpowers/specs/2026-11-26-share-link-design.md` (this repo, branch `feat/share-link`). Mockups: https://claude.ai/artifact/P1iJWvSx1AsFkCyD5rJMYo, screens 1–5 (`project/Main|Teilen|Link|Code|Bericht.dc.html`).

## Repos and commands

| | Core (tasks C1–C8) | Connect (tasks W1–W4) | App (tasks A1–A4) |
|---|---|---|---|
| Repo | `severinkl/bellybuddy-core`, clone to `~/projects/bellybuddy-core` if absent | `severinkl/bellybuddy-connect` (**new**, private), at `~/projects/bellybuddy-connect` | `~/projects/bellybuddy/.worktrees/share-link` |
| Branch | `feat/share-link` from `origin/develop` | `feat/share-view` from `develop` | `feat/share-link` (exists) |
| Tests | `cd backend && TEST_DATABASE_URL=… uv run pytest <path>` against the dev stack (`scripts/dev-env.sh`, `docker compose up -d --wait`, `docker compose stop worker`; see core `README.md`) · `cd frontend && bun run test` | `bun run test` · `bunx playwright test` | `flutter test <path>` |
| Gates | `uv run ruff check . && uv run black --check . && uv run mypy --strict app` · `bun run lint && bun run typecheck && bun run build` | `bun run lint && bun run typecheck && bun run build` | `dart format --set-exit-if-changed . && flutter analyze` |

Order: C1–C5, then C6–C8 and W1–W4 (W2 needs C5's contract, W4 needs nothing running), then A1–A4.

The app repo's pre-commit hook fails inside a worktree (Flutter reports version `0.0.0-unknown` there). Run the two app gates by hand before each commit and commit with `--no-verify`; Severin approved this on 2026-11-26.

## Global Constraints

- User-facing text is German. App: „du". Web view `/teilen`: formal „Sie".
- Core: per-user CRUD through PostgREST + RLS; secrets and cross-user logic through the api. `mypy --strict`. Synthetic test data only.
- App: colours, font sizes, spacing only from `AppTheme` / `AppConstants`; Riverpod `AsyncNotifier`; GoRouter paths in `lib/router/`; `AppLogger`, never `print()`.
- Token, code, view session and diary content never appear in a log line, a Sentry event or an exception message. Log the share id and an outcome word only.
- The view shows nothing that identifies the client beyond the display name: no email, birth year, gender, height, weight, user id.
- Period values: `14d`, `30d`, `all`. Validity values: 7, 30, 90 days. At most 5 active shares per user. 5 wrong codes lock a share. View session: 15 minutes.
- Do not touch `nutritionist_*` tables, their policies or the admin „Nutritionists" tab.
- `PRIVACY_POLICY_VERSION` becomes `"2026-11-27"` in all three places together: core `app/domain/privacy.py` and `frontend/src/pages/legal/privacyPolicy.ts` (Task C7), app `AppConstants.privacyPolicyVersion` (Task A3).
- The share link is `https://connect.bellybuddy.at/teilen#<token>`. Nothing in this plan changes the production host or DNS; those steps are listed for Severin.
- Conventional commits. PRs target `develop` in both repos. Never arm auto-merge; stop at `gh pr create`.

## Review Focus

1. **A share ended while the view is open.** The next data request must fail and the page must switch to the neutral „nicht mehr gültig" page. Tests in C5 and W3.
2. **A client with no gut-feeling entries, or no entries at all, in the period.** The view must render with „noch nicht genug Einträge" and empty-day cells, not crash or show `0 von 0`. Tests in C4 and W3.
3. **Wrong codes from several browsers at once.** The count is per share, not per browser; the fifth wrong code locks; a correct code after the lock is refused. Test in C5.
4. **Period boundaries in the client's time zone.** An entry at 23:30 wall clock on the first day of a 14-day period is included; one at 23:30 the day before is not, also across the October clock change. Test in C4.
5. **A display name with markup, emoji or surrounding spaces.** It is trimmed, limited to 40 characters, stored as typed and rendered as text. Tests in C3 and W3.

---

## Part 1: Core

### Task C1: Migration `0016_data_shares`

**Files:**
- Create: `backend/migrations/versions/0016_data_shares.py`
- Test: `backend/tests/db/test_data_shares.py`
- Modify: `backend/tests/conftest.py` (`USER_TABLES`: add `data_shares`), `backend/tests/db/test_rls.py` and `test_schema_parity.py` only as far as their generic checks require the new tables.

**Interfaces — Produces:**

`public.data_shares`: `id uuid pk`, `user_id uuid not null references auth.users on delete cascade`, `display_name text not null` (trimmed, 1–40 chars), `period text not null check in ('14d','30d','all')`, `share_meals`, `share_drinks`, `share_gut`, `share_toilet`, `share_patterns`, `share_photos` (`boolean not null`), `token_hash bytea not null unique`, `code_hash bytea not null`, `failed_codes integer not null default 0 check between 0 and 5`, `locked_at`, `revoked_at`, `last_opened_at` (`timestamptz`), `open_count integer not null default 0`, `expires_at timestamptz not null`, `consented_at timestamptz not null`, `created_at timestamptz not null default now()`.
Checks: at least one of the five non-photo switches is true; `not share_photos or share_meals`; `not share_patterns or share_gut`.
Index on `(user_id, created_at desc)`.

`public.portal_interest`: `id uuid pk`, `email text not null` (3–254 chars, contains `@`), `created_at timestamptz not null default now()`.

Access: RLS on for both. `data_shares`: revoke all from `anon, authenticated`; grant `authenticated` **column-level select** on every column except `token_hash` and `code_hash`; one policy, select where `auth.uid() = user_id`. No insert, update or delete for clients. `portal_interest`: revoke all from `anon, authenticated`, no policy.

- [ ] **Step 1: Write the failing tests** in `test_data_shares.py`, following `test_buddy_state.py`:

```python
async def test_owner_reads_own_share_without_hashes(...):   # select id, display_name works; select token_hash raises permission denied
async def test_other_user_sees_no_rows(...)
async def test_client_cannot_insert_update_or_delete(...)
async def test_anon_has_no_access(...)
@pytest.mark.parametrize("bad", [
    {"display_name": ""}, {"display_name": " Anna"}, {"display_name": "x" * 41}, {"period": "7d"},
    {"share_photos": True, "share_meals": False}, {"share_patterns": True, "share_gut": False},
    {"share_meals": False, "share_drinks": False, "share_gut": False, "share_toilet": False, "share_patterns": False},
    {"failed_codes": 6},
])
async def test_checks_reject(bad): ...
async def test_share_goes_with_the_user(...)                 # deleting auth.users row cascades
async def test_portal_interest_is_closed_to_clients(...)
```

- [ ] **Step 2: Run** `uv run pytest tests/db/test_data_shares.py` — expected: FAIL, relation does not exist.
- [ ] **Step 3: Write the migration** (`revision = "0016"`, `down_revision = "0015"`), in the style and with a docstring like `0008_buddy_state.py`. `downgrade` drops both tables.
- [ ] **Step 4: Run** `uv run pytest tests/db` — expected: PASS, including the generic RLS and parity tests.
- [ ] **Step 5: Commit** `feat(db): data_shares and portal_interest (0016)`.

### Task C2: Share secrets, state and period (`app/domain/shares.py`)

**Files:**
- Create: `backend/app/domain/shares.py`
- Test: `backend/tests/domain/test_shares.py`

**Interfaces — Produces:**

```python
MAX_ACTIVE: Final = 5
MAX_WRONG_CODES: Final = 5
VIEW_SESSION_S: Final = 15 * 60
VALIDITY_DAYS: Final = (7, 30, 90)

class ShareState(StrEnum): ACTIVE, ENDED, EXPIRED, LOCKED

def new_token() -> str                      # URL-safe, >= 128 bits (secrets.token_urlsafe(24))
def hash_token(token: str) -> bytes         # sha256
def new_code() -> str                       # six digits, zero-padded, from secrets
def hash_code(token: str, code: str) -> bytes   # sha256 over token + ":" + digits of code
def code_matches(token: str, code: str, code_hash: bytes) -> bool   # constant-time; ignores spaces in `code`
def state_of(*, revoked_at: datetime | None, locked_at: datetime | None, expires_at: datetime, now: datetime) -> ShareState
    # precedence: ENDED, then LOCKED, then EXPIRED, else ACTIVE
def period_first_day(period: str, now: datetime, zone: ZoneInfo) -> date | None
    # '14d' -> now's local day minus 13, '30d' -> minus 29, 'all' -> None
def issue_view_session(share_id: uuid.UUID, now: datetime) -> str
def read_view_session(session: str, now: datetime) -> uuid.UUID | None   # None if invalid or older than VIEW_SESSION_S
```

View sessions are HS256 JWTs signed with `settings.jwt_secret`, audience `share-view`, so a user JWT is never accepted as a view session and the reverse.

- [ ] **Step 1: Write the failing tests:** token length and uniqueness over 1,000 draws; `new_code()` matches `^\d{6}$`; `code_matches(t, "482 913", hash_code(t, "482913"))` is true and false for another token; the four states and their precedence (a revoked and expired share is `ENDED`); `period_first_day("14d", datetime(2026,11,26,0,30,tzinfo=UTC), ZoneInfo("Europe/Vienna")) == date(2026,11,13)`; a view session is read back within 15 minutes, `None` at 15 min + 1 s, `None` for a tampered string, `None` for a JWT made with `tests.conftest.make_jwt`.
- [ ] **Step 2: Run** — expected: FAIL, module not found.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `uv run pytest tests/domain/test_shares.py` — expected: PASS.
- [ ] **Step 5: Commit** `feat(shares): tokens, codes, state and view sessions`.

### Task C3: Route `shares` (create and end) and account deletion

**Files:**
- Create: `backend/app/routes/shares.py`
- Modify: `backend/app/routes/delete_account.py` (delete the user's `data_shares` rows explicitly, with the other per-user tables)
- Test: `backend/tests/routes/test_shares.py`, `backend/tests/routes/test_delete_account.py`

**Interfaces — Consumes:** C1 table, C2 functions, `app.auth.current_user`, `app.domain.privacy.has_current_consent`, `settings.public_connect_url` (added in C6; until then use `public_app_url` and switch in C6).
**Produces:** `NAME = "shares"`.

`POST /functions/v1/shares` with JSON `{"display_name": str, "period": "14d"|"30d"|"all", "valid_days": 7|30|90, "meals": bool, "drinks": bool, "gut": bool, "toilet": bool, "patterns": bool, "photos": bool}` → `200 {"id": str, "link": "<connect url>/teilen#<token>", "code": "482913", "expires_at": iso}`.
`POST /functions/v1/shares/{id}/end` → `200 {"ok": true}`; idempotent; `404` for another user's or an unknown id.

Errors (`ApiError`, German message): `400` invalid body (the same rules as C1's checks; `display_name` is trimmed first), `403` „Bitte stimme zuerst der Datenschutzerklärung zu." without current consent, `409` „Du hast schon 5 aktive Freigaben. Beende eine, um eine neue zu erstellen." when 5 are active as `state_of` sees them.

- [ ] **Step 1: Write the failing tests:**

```python
async def test_create_returns_link_and_code_and_stores_only_hashes(...)
    # link ends with "/teilen#<token>"; code ^\d{6}$; row.token_hash == hash_token(token); no column holds token or code
async def test_display_name_is_trimmed_and_kept_as_typed(...)      # "  <b>Anna</b> 🫶 " -> "<b>Anna</b> 🫶"
@pytest.mark.parametrize("body_change", [...])                     # every C1 check, valid_days 14, name of 41 chars -> 400
async def test_create_needs_current_health_consent(...)            # 403, no row
async def test_sixth_active_share_is_refused_but_ended_and_expired_do_not_count(...)
async def test_end_is_idempotent_and_only_for_the_owner(...)
async def test_no_secret_in_logs(caplog, ...)                      # neither token nor code in caplog.text
async def test_delete_account_removes_shares(...)                  # in test_delete_account.py
```

- [ ] **Step 2: Run** — expected: FAIL, 404 route not found.
- [ ] **Step 3: Implement** the route module in the style of `refresh_ingredient_suggestions.py` (`@fallback_500(NAME)`, `service_session()`); add `data_shares` to `delete_account.py`'s per-user deletion.
- [ ] **Step 4: Run** `uv run pytest tests/routes/test_shares.py tests/routes/test_delete_account.py tests/routes/test_mounting.py` — expected: PASS.
- [ ] **Step 5: Commit** `feat(api): shares route (create, end)`.

### Task C4: The view payload (`app/domain/share_view.py`)

**Files:**
- Create: `backend/app/domain/share_view.py`
- Modify: `backend/app/domain/insights.py` (add the public `classify_days` below; no behaviour change to `compute_insights`), `backend/app/storage.py` (add `StorageClient.sign`)
- Test: `backend/tests/domain/test_share_view.py`, `backend/tests/domain/test_insights.py` (one test for `classify_days`)

**Interfaces — Produces:**

```python
# insights.py
def classify_days(gut_feelings: Iterable[GutFeeling], zone: ZoneInfo) -> dict[date, DayClass]
    # per local day: the same mean-of-scores rule `compute_insights` uses (`_class_of`); days without entries are absent

# storage.py
async def sign(self, bucket: str, path: str, expires_s: int) -> str     # storage-api POST /object/sign/<bucket>/<path>; returns an absolute public URL

# share_view.py
async def build_view(session: AsyncSession, share: Row[Any], now: datetime) -> dict[str, Any]
```

`build_view` returns exactly this JSON-ready shape; keys of switched-off categories are **absent**, not null:

```json
{
  "display_name": "Anna", "expires_at": "2026-12-26T10:00:00Z",
  "period": {"kind": "30d", "first_day": "2026-10-28", "last_day": "2026-11-26"},
  "profile": {"diet": "vegetarisch", "intolerances": ["Laktose"], "symptoms": ["Blähungen"]},
  "summary": {"days_with_entries": 24, "good": 11, "medium": 7, "hard": 6, "meals": 68},
  "course": [{"day": "2026-10-28", "class": "good"}],
  "patterns": {"enough": true,
               "hard": {"days": 6, "items": [{"name": "Zwiebel", "count": 5, "fodmaps": ["Fruktane"]}]},
               "good": {"days": 11, "items": [{"name": "Reis", "count": 8, "fodmaps": []}]}},
  "days": [{"day": "2026-11-24", "class": "hard", "entries": [
     {"time": "07:40", "kind": "meal", "title": "Porridge mit Apfel", "notes": null, "photo_url": null,
      "ingredients": [{"name": "Apfel", "fodmaps": ["Fruktose", "Sorbit"]}]},
     {"time": "09:10", "kind": "drink", "name": "Kaffee", "amount_ml": 250, "notes": null},
     {"time": "15:20", "kind": "gut", "level": "Schlecht", "symptoms": [{"name": "Blähungen", "strength": 6}],
      "mood": {"stress": 5, "happiness": 2, "energy": 3, "focus": 3, "body_feel": 2}, "notes": null},
     {"time": "17:05", "kind": "toilet", "stool_type": 6, "stool_label": "Typ 6: weich, breiig", "notes": null}]}]
}
```

Rules:
- `profile`: only with `share_patterns`. `summary.meals` only with `share_meals`; `good/medium/hard`, `course` and every `class` only with `share_gut`. `patterns`: only with `share_patterns` **and** `share_meals` (`share_gut` is implied by C1's check).
- `period`: `last_day` is `now`'s local day in the client's zone (`wall_clock.user_zone(profiles.timezone)`); `first_day` from `period_first_day`, or for `all` the local day of the oldest entry (today if none). `tracked_at` is wall clock in the UTC slot: compare and format it with `app.domain.wall_clock`, never `astimezone` it.
- `course`: one item per day of the period, oldest first, `class` one of `good|medium|hard|none`; for `all`, the last 90 days only. `days`: every day of the period that has an entry of a shared category, newest first, entries by time.
- `patterns`: from `compute_insights` over its own fixed 30-day window as of `now` (build the `InsightSource` the way `tips_context.py` does). `enough` is `insights.unlocked`; when false, `hard` and `good` are absent. `items` are `hard_days.often` / `good_days.often`, `days` their `.days`. An empty `often` gives `"items": []`.
- `fodmaps`: short German labels via `app.domain.fodmap.flagged_labels`, looked up by trimmed, case-insensitive name in the ingredients visible to the client (shared rows and their own, as `ingredient_suggestions.load_catalog` selects them). Unknown ingredient: `[]`.
- `gut.level`: the words the app uses for the entry's score (worst of the four gut symptoms): „Sehr gut", „Gut", „Mittel", „Schlecht", with the thresholds of `lib/utils/gut_feeling_rating.dart` in the app repo. `symptoms`: German names of the four gut symptoms whose value is above 1, with `strength` 2–7.
- `stool_label`: „Typ N: …" for Bristol types 1–7, wording from the app's toilet tracker.
- `photo_url`: only with `share_photos` and a stored image: `StorageClient.sign("meal-images", path, VIEW_SESSION_S)`, with the stored value reduced to a path the way the app's `extractStoragePath` does.
- Free-text `notes` travel with their entry.

- [ ] **Step 1: Write the failing tests** (seed with `tests.conftest` helpers and `wall()`):

```python
def test_classify_days_matches_compute_insights_calendar()            # test_insights.py: same classes as Insights.calendar for the shared vectors' days
async def test_shape_with_everything_on(...)                           # the keys above, exactly; no key named email, birth_year, gender, weight, height, user_id anywhere
@pytest.mark.parametrize("off, absent", [("share_meals", ["patterns"]), ("share_gut", ["course"]), ("share_patterns", ["profile", "patterns"]), ...])
async def test_switched_off_categories_are_absent(...)                 # and no entry of that kind in days[].entries
async def test_period_14d_boundary_in_client_zone(...)                 # wall 23:30 on first_day included, 23:30 the day before excluded; repeat with now = 2026-10-27 (after the clock change)
async def test_period_all_starts_at_oldest_entry_and_course_is_capped_at_90_days(...)
async def test_no_entries_at_all(...)                                  # summary zeros, course all "none", days == [], patterns == {"enough": False}
async def test_patterns_use_the_30_day_window_for_a_14d_share(...)     # a hard day 20 days ago still counts in patterns.hard.days, but is not in days[]
async def test_fodmap_labels_and_unknown_ingredient(...)
async def test_photo_url_only_when_shared(...)                         # StorageClient.sign mocked with respx
```

- [ ] **Step 2: Run** — expected: FAIL, module not found.
- [ ] **Step 3: Implement** `classify_days`, `StorageClient.sign`, `build_view`.
- [ ] **Step 4: Run** `uv run pytest tests/domain/test_share_view.py tests/domain/test_insights.py` — expected: PASS (the shared insight vectors still pass unchanged).
- [ ] **Step 5: Commit** `feat(shares): view payload from the diary`.

### Task C5: Route `share-view` (open, data) and `portal-interest`

**Files:**
- Create: `backend/app/routes/share_view.py`, `backend/app/routes/portal_interest.py`
- Modify: `backend/app/http.py` (add `client_address`)
- Test: `backend/tests/routes/test_share_view.py`, `backend/tests/routes/test_portal_interest.py`

**Interfaces — Consumes:** C2, C4. **Produces:**

```python
def client_address(request: Request) -> str    # http.py: first address of X-Forwarded-For (Caddy sets it), else request.client.host, else "unknown"
```

`NAME = "share-view"`, no user authentication:
- `POST /functions/v1/share-view/open` `{"token": str, "code": str}` →
  `200 {"session": str, "display_name": str, "expires_at": iso}` and `open_count + 1`, `last_opened_at = now`, `failed_codes = 0`;
  `401 {"error": "Der Code stimmt nicht.", "tries_left": n}` and `failed_codes + 1` (at 5: `locked_at = now`, and the answer is the `410` below);
  `410 {"error": "Diese Freigabe ist nicht mehr gültig."}` for an unknown token, an ended, expired or locked share, or an owner without current health consent — the same body for all;
  `429` when `Throttle(limit=20, window_s=600)` keyed by `client_address` is exceeded.
- `POST /functions/v1/share-view/data` `{"session": str}` → `200 {"session": <fresh view session>, "view": build_view(...)}` (each successful call renews the 15 minutes); `410` (same body) when the session is invalid or too old, or the share is no longer active, or consent is gone. Every call re-reads the share row.
- The wrong-code increment is one atomic `update … set failed_codes = failed_codes + 1 … returning`, so parallel requests cannot exceed 5.

`NAME = "portal-interest"`: `POST` `{"email": str}` → `200 {"ok": true}` and one row; `400` for an invalid address; `Throttle(limit=5, window_s=3600)` by `client_address`. A repeated address is stored once.

- [ ] **Step 1: Write the failing tests:**

```python
async def test_open_with_right_code_returns_session_and_records_the_opening(...)
async def test_wrong_code_counts_down_and_fifth_locks_even_from_different_addresses(...)   # tries_left 4,3,2,1 then 410; right code afterwards -> 410
async def test_parallel_wrong_codes_never_exceed_five(...)                                 # asyncio.gather of 10
@pytest.mark.parametrize("case", ["unknown_token", "ended", "expired", "locked", "consent_withdrawn", "older_policy_version"])
async def test_every_dead_share_answers_the_same_410(case): ...                            # identical status and body
async def test_data_returns_the_view_and_stops_when_the_share_is_ended_meanwhile(...)      # Review Focus 1
async def test_data_refuses_a_user_jwt_and_an_expired_session(...)
async def test_data_renews_the_session(...)                                                # the returned session works 10 minutes after the first one would have run out
async def test_open_is_throttled_per_address(...)
async def test_nothing_secret_is_logged(caplog, ...)                                       # token, code, session, a meal title: none in caplog.text
async def test_portal_interest_stores_one_row_per_address_and_validates(...)
```

- [ ] **Step 2: Run** — expected: FAIL, 404.
- [ ] **Step 3: Implement** both modules and `client_address`. Catch `build_view` failures with `fallback_500(NAME)` and a message that names nothing from the diary.
- [ ] **Step 4: Run** `uv run pytest tests/routes/test_share_view.py tests/routes/test_portal_interest.py tests/routes/test_mounting.py` — expected: PASS.
- [ ] **Step 5: Commit** `feat(api): public share-view and portal-interest routes`.

### Task C6: Edge and settings for `connect.bellybuddy.at`

**Files:**
- Modify: `Caddyfile`, `docker-compose.yml`, `docker-compose.prod.yml`, `environment/ci/config.env`, `environment/production/config.env`, `scripts/dev-env.sh`, `scripts/smoke.sh`, `backend/app/settings.py`, `backend/app/routes/shares.py`, `docs/needs-from-severin.md`, `CLAUDE.md` (one line naming the new repo)
- Test: `backend/tests/routes/test_shares.py` (link host), the existing settings tests, `scripts/test-deploy.sh` rehearsal

**Interfaces — Produces:**
- `Settings.public_connect_url: str` (env `PUBLIC_CONNECT_URL`; prod `https://connect.bellybuddy.at`, local `http://localhost:8002`). C3's link becomes `f"{settings.public_connect_url}/teilen#{token}"`.
- Caddy site `{$CONNECT_HOST}` (prod `connect.bellybuddy.at`, local `http://localhost:8002`): a static SPA from `/srv/connect` (`try_files {path} /index.html`), hashed `/assets/*` cached for good, and on every response `Content-Security-Policy "frame-ancestors 'none'"`, `X-Frame-Options DENY`, `X-Content-Type-Options nosniff`, `X-Robots-Tag "noindex, nofollow"`, `Referrer-Policy no-referrer`.
- Compose mounts `${CONNECT_WEB_DIR}:/srv/connect:ro` into Caddy (prod `/opt/bellybuddy-connect/dist`; local default `../bellybuddy-connect/dist`). When the directory is empty, Caddy answers 404 and the stack still starts.
- `CORS_ORIGINS` gains the Connect origin in both environments.
- `docs/needs-from-severin.md`: the DNS record `connect.bellybuddy.at` → the production host, and creating `/opt/bellybuddy-connect` on it.

- [ ] **Step 1: Write the failing test:** `test_create_returns_link…` expects the link to start with `f"{settings.public_connect_url}/teilen#"`; a settings test expects `public_connect_url` to be required.
- [ ] **Step 2: Run** — expected: FAIL.
- [ ] **Step 3: Implement.** Validate the Caddyfile with the pinned Caddy image (`caddy validate`). Add one line to `scripts/smoke.sh`: the Connect host answers (200 with a build present, 404 without).
- [ ] **Step 4: Run** the backend tests, bring the local stack up and run `scripts/smoke.sh`; rehearse with `scripts/test-deploy.sh` — expected: every line OK.
- [ ] **Step 5: Commit** `feat(edge): serve Belly Buddy Connect at its own host`.

### Task C7: Privacy policy: sharing section and version bump

**Files:**
- Modify: `frontend/src/pages/legal/privacyPolicy.ts`, `docs/legal/` (the same text where the policy source lives), `backend/app/domain/privacy.py`
- Test: `frontend/src/pages/legal/PrivacyPolicyPage.test.tsx`, `backend/tests/domain/test_privacy.py`

Section „Tagebuch teilen", in the policy's existing voice, covering: what a share contains (the chosen categories and the display name), that only the user starts it and can end it at any time, that link and code are stored as hashes, that the time and number of openings are recorded, the validity limits, that the view is served at `connect.bellybuddy.at`, and that its sign-up box stores an email address for one message and deletes it after that or after 12 months.

`PRIVACY_POLICY_VERSION` becomes `"2026-11-27"` in `privacyPolicy.ts` and `privacy.py` (and in the app, Task A3). Every user then passes the consent screen once; until they do, their shares answer 410 (C5).

- [ ] **Step 1: Write the failing test:** the page test expects the heading „Tagebuch teilen" and the version line for 27.11.2026.
- [ ] **Step 2: Run** — expected: FAIL.
- [ ] **Step 3: Write the section and bump both constants.**
- [ ] **Step 4: Run** `bun run test` in `frontend/` and `uv run pytest tests/domain/test_privacy.py` plus the full backend suite (tests that seed consent use the constant) — expected: PASS.
- [ ] **Step 5: Commit** `feat(legal)!: privacy section for sharing, policy version 2026-11-27`.

### Task C8: Core gates and PR

- [ ] **Step 1:** Run every core gate from the table at the top and the full `uv run pytest`. Expected: all green.
- [ ] **Step 2:** Push `feat/share-link` and open a PR to `develop` titled `feat: share a diary by link (Berater-Freigabe, stage 1)`, linking the spec. Stop there.

---

## Part 2: Connect (new repo `severinkl/bellybuddy-connect`)

### Task W1: Create and scaffold the repo

**Files (all new, in `~/projects/bellybuddy-connect`):** `package.json`, `bun.lock`, `vite.config.ts`, `tsconfig*.json`, `eslint.config.js`, `tailwind` setup, `index.html`, `src/main.tsx`, `src/App.tsx`, `src/vite-env.d.ts`, `src/test/setup.ts`, `src/App.test.tsx`, `.env.example`, `.gitignore`, `.gitleaks.toml`, `README.md`, `CLAUDE.md`, `.github/workflows/ci.yml`

**Interfaces — Produces:**
- A **private** GitHub repo `severinkl/bellybuddy-connect` with branches `main` and `develop` (default `develop` for PRs, as in core), created with `gh repo create severinkl/bellybuddy-connect --private`.
- The same stack and versions as core's `frontend/` (React, Vite, TypeScript, bun, Tailwind, vitest, eslint), copied from its config files where they apply. No Supabase client, no Sentry, no analytics.
- Scripts: `dev`, `build`, `lint`, `typecheck`, `test` (as in core's `frontend/package.json`).
- `VITE_API_URL` (local `http://localhost:8000`, prod `https://api.bellybuddy.at`), read in one place: `src/config.ts` → `export const API_URL: string`.
- `index.html`: `lang="de"`, title „Belly Buddy Connect", `<meta name="robots" content="noindex,nofollow">`.
- Routes: `/teilen` (placeholder in this task) and a not-found page for everything else, with the text „Diese Seite gibt es nicht."
- `CLAUDE.md`: what the project is, its relation to core and the app, the conventions (German, formal „Sie"; conventional commits; PRs to `develop`; never auto-merge; no secrets or diary content in logs), the commands.
- CI: lint, typecheck, test, build, gitleaks, on pushes and PRs.

- [ ] **Step 1: Write the failing test** `src/App.test.tsx`: `/teilen` renders the placeholder; `/anything` renders „Diese Seite gibt es nicht."
- [ ] **Step 2: Run** `bun run test` — expected: FAIL.
- [ ] **Step 3: Scaffold**, create the repo, push `main` and `develop`, branch `feat/share-view`.
- [ ] **Step 4: Run** `bun run lint && bun run typecheck && bun run test && bun run build` — expected: PASS. CI green on the pushed branch.
- [ ] **Step 5: Commit** `chore: scaffold Belly Buddy Connect`.

### Task W2: `/teilen` code page and invalid page

**Files:**
- Create: `src/pages/share/shareApi.ts`, `src/pages/share/SharePage.tsx`, `src/pages/share/CodeForm.tsx`, `src/pages/share/InvalidShare.tsx`, `src/pages/share/types.ts`
- Modify: `src/App.tsx`
- Test: `src/pages/share/SharePage.test.tsx`, `src/pages/share/shareApi.test.ts`

**Interfaces — Produces:**

```ts
// types.ts: `ShareView` mirrors C4's JSON exactly; every category key optional.
// shareApi.ts
export type OpenResult =
  | { kind: "ok"; session: string; displayName: string; expiresAt: string }
  | { kind: "wrong-code"; triesLeft: number }
  | { kind: "invalid" } | { kind: "busy" } | { kind: "offline" };
export function openShare(token: string, code: string): Promise<OpenResult>;        // 200 / 401 / 410 / 429 / network
export function loadShare(session: string): Promise<{ view: ShareView; session: string } | "invalid" | "offline">;   // keep the returned session for the next call
```

Behaviour:
- `SharePage` reads the token from `window.location.hash` once, then removes the hash from the address bar with `history.replaceState`. No hash → `InvalidShare`.
- Calls go by `fetch` to `${API_URL}/functions/v1/share-view/...` with `content-type: application/json` only.
- The session lives in React state only: not in `localStorage`, `sessionStorage` or the URL. A reload asks for the code again.
- `CodeForm` copy, exactly as mockup screen 4: heading „Jemand teilt ein Ernährungstagebuch mit Ihnen", the paragraph, label „Code", button „Tagebuch öffnen", the footer sentence. Wrong code: „Der Code stimmt nicht. Noch N Versuche." (N = 1: „Noch 1 Versuch."). Busy: „Zu viele Versuche. Bitte warten Sie ein paar Minuten." Offline: „Keine Verbindung. Bitte versuchen Sie es erneut."
- `InvalidShare`: „Diese Freigabe ist nicht mehr gültig. Bitten Sie Ihre Klientin oder Ihren Klienten um einen neuen Link."

- [ ] **Step 1: Write the failing tests:** renders the code form when a hash is present and clears the hash; `InvalidShare` without a hash and after a 410; the wrong-code line with 3 tries and with 1; the busy and offline lines; after a 200, `DiaryView` (a stub in this task) receives the loaded view; `shareApi` maps 200/401/410/429/network to the five kinds and sends only the `content-type` header; nothing is written to `localStorage` or `sessionStorage`.
- [ ] **Step 2: Run** `bun run test src/pages/share` — expected: FAIL.
- [ ] **Step 3: Implement.** Styling follows mockup screen 4 with the palette of `Bericht.dc.html`; one light theme.
- [ ] **Step 4: Run** `bun run test && bun run lint && bun run typecheck` — expected: PASS.
- [ ] **Step 5: Commit** `feat: /teilen code page`.

### Task W3: The diary view and print

**Files:**
- Create: `src/pages/share/DiaryView.tsx`, `src/pages/share/sections/{ShareHeader,Summary,Course,PatternLists,DayList,PortalBox}.tsx`, `src/pages/share/share-print.css`
- Modify: `src/pages/share/SharePage.tsx` (replace the stub; reload the view every 5 minutes and on window focus; an `"invalid"` answer switches to `InvalidShare`)
- Test: `src/pages/share/DiaryView.test.tsx`, `src/pages/share/sections/PortalBox.test.tsx`

**Interfaces — Consumes:** `ShareView`, `loadShare` from W2; `POST ${API_URL}/functions/v1/portal-interest` from C5.

Layout and copy follow mockup screen 5 top to bottom, usable from 360 px width (wide tables scroll inside their own box). Fixed points:
- Header: „Geteiltes Tagebuch, nur lesen", „Freigabe gültig bis <date>", button „Drucken / als PDF sichern" → `window.print()`.
- Title „Tagebuch von <display_name>" (rendered as text), then „<first_day> bis <last_day> · N Tage".
- A section renders only if its key exists in the view. No empty headings.
- Course legend: „G = guter Tag, M = mittel, S = schwer, leer = kein Eintrag. Die Einstufung kommt aus dem Bauchgefühl, das <Name> selbst erfasst hat."
- Pattern headings: „Vor schweren Tagen häufig gegessen" and „An guten Tagen häufig gegessen", each with the sub-line „aus den letzten 30 Tagen"; rows „Zwiebel · 5 von 6 schweren Tagen · Fruktane"; below both: „Das sind Häufigkeiten aus den Einträgen der 24 Stunden davor, keine Diagnose." With `enough: false`, or with empty `items` on both sides: „Für Muster gibt es noch nicht genug Einträge."
- Day list: the 7 newest days open, then a button „N weitere Tage anzeigen". Flagged ingredients are marked and carry their FODMAP labels. A day with `class` shows „Guter Tag" / „Mittlerer Tag" / „Schwerer Tag".
- With `days: []`: „In diesem Zeitraum gibt es noch keine Einträge."
- `share-print.css` (`@media print`): header button, portal box and the „weitere Tage" button hidden, every day expanded, a day block is not split across pages.
- `PortalBox`: copy from the mockup plus the line „Wir verwenden Ihre Adresse nur für eine Nachricht, sobald der Zugang verfügbar ist." After success the form is replaced by „Danke, wir melden uns." An invalid address or a failed request shows a line under the field and keeps the input.

- [ ] **Step 1: Write the failing tests** with fixtures built from C4's example: all sections render for a full view; a view without `patterns`, `course`, `profile` renders none of their headings; `enough: false` shows the not-enough sentence; `days: []` shows the no-entries sentence and no „weitere Tage" button; a `display_name` of `<img src=x onerror=alert(1)>` appears as visible text and creates no `img` element; 10 days → 7 open and „3 weitere Tage anzeigen"; when the timed reload returns `"invalid"`, `InvalidShare` replaces the diary; `PortalBox` success, invalid address and failure.
- [ ] **Step 2: Run** — expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `bun run test && bun run lint && bun run typecheck && bun run build` — expected: PASS.
- [ ] **Step 5: Commit** `feat: shared diary view with print`.

### Task W4: Browser test, deploy script, runbook, PR

**Files:**
- Create: `e2e/share.spec.ts`, `playwright.config.ts`, `deploy.sh`, `docs/runbooks/deploy.md`, `docs/needs-from-severin.md`
- Modify: `.github/workflows/ci.yml` (run the browser test), `README.md`

- `e2e/share.spec.ts` runs the built site against a **mocked** api (Playwright route interception, synthetic data): wrong code shows the tries line; the right code shows „Tagebuch von"; when the next data call answers 410 the invalid page appears; the print stylesheet hides the header button (`page.emulateMedia({ media: "print" })`).
- `deploy.sh`, run on the host from `/opt/bellybuddy-connect`: `git reset --hard origin/main`, `bun install --frozen-lockfile`, `VITE_API_URL=https://api.bellybuddy.at bun run build` into a fresh directory, then swap it into `dist/` in one move so Caddy never serves a half-written build. It refuses to run with a dirty tree and prints the deployed commit.
- `docs/runbooks/deploy.md`: first-time setup on the host (clone, deploy key), the deploy command, rollback (deploy the previous commit).
- `docs/needs-from-severin.md`: the DNS record, the first-time host setup, and running the first deploy. Nothing in this plan changes the production host.

- [ ] **Step 1: Write the browser test.** Run `bunx playwright test` — expected: PASS against the build from W3 (the test is new; a failure here is a defect in W2/W3 to fix in this task).
- [ ] **Step 2: Write `deploy.sh`** and check it with `shellcheck`; rehearse it locally into a temp directory with `VITE_API_URL=http://localhost:8000`.
- [ ] **Step 3: Write the runbook and the needs list.**
- [ ] **Step 4: Run** every gate and the browser test — expected: PASS, CI green.
- [ ] **Step 5: Commit** `test: browser test for /teilen; chore: deploy script and runbook`, push, and open a PR to `develop` titled `feat: shared diary view at /teilen`, linking the spec and the core PR. Stop there.

---

## Part 3: App

### Task A1: Model, service and device store

**Files:**
- Create: `lib/models/data_share.dart`, `lib/services/share_service.dart`, `lib/services/share_secrets_store.dart`
- Test: `test/models/data_share_test.dart`, `test/services/share_service_test.dart`, `test/services/share_secrets_store_test.dart`

**Interfaces — Produces:**

```dart
enum SharePeriod { days14, days30, all }            // json '14d' | '30d' | 'all'
enum ShareState { active, ended, expired, locked }

@freezed
class DataShare { id, displayName, period, shareMeals, shareDrinks, shareGut, shareToilet, sharePatterns, sharePhotos,
                  failedCodes, lockedAt, revokedAt, lastOpenedAt, openCount, expiresAt, createdAt;
  ShareState stateAt(DateTime now);                 // ended, then locked, then expired, else active (as core's state_of)
  String get description; }                         // „Letzte 30 Tage, ohne Fotos" / „Letzte 14 Tage, mit Fotos" / „Alle Einträge, ohne Fotos"

class NewShare { displayName, period, validDays, meals, drinks, gut, toilet, patterns, photos }
class CreatedShare { String id; String link; String code; DateTime expiresAt; }
class ShareSecret { String link; String code; }

class ShareService {
  Future<List<DataShare>> list();                                   // PostgREST `data_shares`, explicit column list (never `*`), created_at desc
  Future<CreatedShare> create(NewShare share);                      // functions.invoke('shares', body: …) with C3's keys
  Future<void> end(String id);                                      // functions.invoke('shares/$id/end')
}
class ShareException implements Exception { final int? status; final String? message; }   // 403, 409 carry core's German message

class ShareSecretsStore {                                           // shared_preferences
  Future<void> save(String shareId, ShareSecret secret);
  Future<ShareSecret?> read(String shareId);
  Future<void> remove(String shareId);
  Future<void> clear();                                             // on sign-out and account deletion
  Future<String?> lastDisplayName(); Future<void> rememberDisplayName(String name);
}
final shareServiceProvider, shareSecretsStoreProvider
```

- [ ] **Step 1: Write the failing tests:** JSON round trip with PostgREST's snake_case keys; `stateAt` for the four states and the precedence; the three `description` strings and „mit Fotos"; `list()` selects no hash column and never `*`; `create()` sends exactly C3's body keys and parses the answer; a 409 becomes `ShareException(status: 409, message: …)`; the store saves, reads, removes, clears, and remembers the display name.
- [ ] **Step 2: Run** `flutter test test/models/data_share_test.dart test/services/share_service_test.dart test/services/share_secrets_store_test.dart` — expected: FAIL.
- [ ] **Step 3: Implement**, then `dart run build_runner build`. Hook `ShareSecretsStore.clear()` into the existing sign-out and account-deletion paths.
- [ ] **Step 4: Run** the tests and both app gates — expected: PASS.
- [ ] **Step 5: Commit** `feat(shares): model, service and device store`.

### Task A2: Provider, routes, „Deine Freigaben" and the Ich row

**Files:**
- Create: `lib/providers/shares_provider.dart`, `lib/screens/shares/shares_screen.dart`, `lib/screens/shares/widgets/share_tile.dart`
- Modify: `lib/router/route_names.dart`, `lib/router/app_router.dart`, `lib/screens/me/me_screen.dart`, `lib/screens/screens.dart`, `lib/config/app_theme.dart` / `constants.dart` only for values not yet defined
- Test: `test/providers/shares_provider_test.dart`, `test/screens/shares/shares_screen_test.dart`, `test/screens/me/me_screen_test.dart`

**Interfaces — Produces:**

```dart
class SharesNotifier extends AsyncNotifier<List<DataShare>> {
  Future<CreatedShare> create(NewShare share);     // saves the secret, remembers the name, reloads
  Future<void> end(String id);                     // reloads; the secret is removed
}
final sharesProvider;
RouteNames.shares = 'shares', RoutePaths.shares = '/shares';
RouteNames.shareCreate = 'share-create', RoutePaths.shareCreate = '/shares/new';
MeScreen.shareKey
```

Behaviour:
- Ich row between „Streak & Ziel" and „Einstellungen": icon `Icons.person_add_alt_1_outlined`, title „Mit Berater:in teilen", subtitle „Tagebuch für Diätolog:in oder Ärzt:in freigeben", a „Neu" badge until the row was tapped once (a flag in shared preferences). Tap: with no share in the list (or while the list failed to load) push `/shares/new`, else `/shares`.
- `SharesScreen` „Deine Freigaben" as mockup screen 3, lower half: active shares first, then the others; ended, expired and locked ones older than 90 days are not shown. A tile shows `description`, the state word („Aktiv", „Beendet", „Abgelaufen", „Gesperrt"), „Erstellt am <date>" and „noch nicht geöffnet" / „zuletzt geöffnet <date>, <time>" / „N-mal geöffnet". An active tile has „Freigabe beenden" → confirmation dialog „Freigabe beenden?" / „Die Berater:in kann dein Tagebuch dann nicht mehr sehen." / „Beenden" / „Abbrechen". An active tile whose secret is on this device has „Link und Code anzeigen" (opens A3's sheet); without it, the line „Auf diesem Gerät nicht gespeichert" and „Neu erstellen".
- Empty state: „Teile dein Tagebuch mit deiner Diätolog:in oder Ärzt:in. Du entscheidest, was sie sehen, und kannst es jederzeit beenden." and the button.
- Bottom button „Weitere Freigabe erstellen" (empty state: „Freigabe erstellen") → `/shares/new`.
- A failed load shows the app's usual error view with retry; a failed end shows the app's usual error message and leaves the list unchanged.

- [ ] **Step 1: Write the failing tests:** provider `create` stores the secret and reloads, `end` reloads and removes the secret, a failing `end` leaves state as it was; the screen's ordering, the 90-day cut, each state word, the three opened lines, the confirm dialog and its cancel, the two variants of an active tile, the empty state; the Ich row's position, badge before and after the first tap, and both tap targets.
- [ ] **Step 2: Run** — expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the tests, `flutter test test/router`, and both app gates — expected: PASS.
- [ ] **Step 5: Commit** `feat(shares): Freigaben list and Ich entry`.

### Task A3: „Freigabe einrichten" and the created sheet

**Files:**
- Create: `lib/screens/shares/share_create_screen.dart`, `lib/screens/shares/widgets/share_created_sheet.dart`
- Modify: `pubspec.yaml` (add `share_plus`, the current major), `lib/router/app_router.dart`, `lib/config/constants.dart` (`privacyPolicyVersion = '2026-11-27'`, with the test that pins it)
- Test: `test/screens/shares/share_create_screen_test.dart`, `test/screens/shares/share_created_sheet_test.dart`

**Interfaces — Consumes:** `sharesProvider`, `NewShare`, `ShareSecretsStore`, `healthConsentProvider`.

Behaviour, as mockup screens 2 and 3 (upper half):
- Fields: „Dein Name in der Ansicht" (prefilled from `lastDisplayName()`, max 40, required after trimming); „Zeitraum" 14 Tage / **30 Tage** / Alles; „Was wird geteilt?" six switches, all on except „Fotos der Mahlzeiten"; „Link gültig für" 7 / **30** / 90 Tage.
- Switch rules: „Fotos" is disabled while „Mahlzeiten und Zutaten" is off. „Muster und Unverträglichkeiten" is switched off and disabled while „Bauchgefühl und Symptome" is off, with the line „Braucht Bauchgefühl". Under the patterns switch: „Muster zeigen immer die letzten 30 Tage." „Link erstellen" is disabled while the name is empty or all five non-photo switches are off.
- Footer line: „Das sind Gesundheitsdaten. Neue Einträge erscheinen automatisch. Du kannst die Freigabe jederzeit beenden."
- „Link erstellen" → `sharesProvider.create`. Success: replace the route with `/shares` and open the created sheet. A `ShareException` with a message shows that message; any other failure shows the app's usual error message; in both cases the form keeps its values and nothing is created.
- Created sheet: the link, „Link senden" (system share sheet; the text is „Hier ist mein Belly Buddy Tagebuch: <link>" and never contains the code), „Kopieren" (clipboard, then „Kopiert"), the code in large digits grouped „482 913", and „Sag ihn deiner Berater:in getrennt vom Link."

- [ ] **Step 1: Write the failing tests:** defaults; the two dependent-switch rules and their lines; the disabled button cases; the submitted `NewShare` for a changed form; a 409's message is shown and the form is kept; a generic failure likewise; on success the sheet shows link and grouped code; the shared text contains the link and not the code; copy puts the link on the clipboard.
- [ ] **Step 2: Run** — expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the tests and both app gates — expected: PASS.
- [ ] **Step 5: Commit** `feat(shares): create a share and send the link`.

### Task A4: App gates, local run against core, PR

- [ ] **Step 1:** Run `dart format --set-exit-if-changed .`, `flutter analyze` and the full `flutter test`. Expected: all green.
- [ ] **Step 2:** With the core dev stack from Part 1 running and Connect's build in `CONNECT_WEB_DIR`, create a share in the app on a simulator or emulator (after passing the new consent screen once), open the link in a browser, enter the code, and check: the diary shows; a new meal logged in the app appears after a reload; „Freigabe beenden" turns the open page into the invalid page within one reload. Note any deviation in the PR.
- [ ] **Step 3:** Push `feat/share-link` and open a PR to `develop` titled `feat: share your diary with a dietitian by link`, linking the spec and the core and Connect PRs. Stop there. The three are released together: core, then Connect, then the app.

---

---

## Needs from Severin before release

- DNS record `connect.bellybuddy.at` → the production host (`bellybuddy-infra`).
- First-time setup and first deploy of `bellybuddy-connect` on the host (`docs/runbooks/deploy.md` in that repo).
- `PUBLIC_CONNECT_URL`, `CONNECT_HOST`, `CONNECT_WEB_DIR` and the extended `CORS_ORIGINS` in the production vaultfile are plain config and are set in C6; no new secret is needed.
