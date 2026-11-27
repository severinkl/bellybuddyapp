# Belly Buddy Plus (Abo) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A monthly „Belly Buddy Plus" subscription (store trial, RevenueCat) unlocks Muster, new Tipps, new Alternativen, recipe adapting and creating shares — shipped behind the remote switch `paywall_enabled = 'false'`, so nothing changes until Severin turns it on.

**Architecture:** Core stores a per-user `plus_entitlements` row, kept current by a RevenueCat webhook that refetches the subscriber from RevenueCat's REST API and by on-demand lookups; paid routes answer 402 `plus_required` unless `has_plus` (always true while the switch is off). The app wraps `purchases_flutter` behind a `PurchasesGateway` (fake in tests), derives one `plusAccessProvider` (open/locked) from the switch and RevenueCat's customer info, and shows locks in place plus one paywall route `/plus`.

**Tech Stack:** core: FastAPI, SQLAlchemy async, alembic, httpx2, respx, pytest. App: Flutter, Riverpod, GoRouter, `purchases_flutter` (new), mocktail.

**Spec:** `docs/superpowers/specs/2026-11-27-subscription-design.md` (docs branch `docs/plan-subscription`).

## Repos and commands

| | Core (tasks SC1–SC6) | App (tasks SA1–SA7) |
|---|---|---|
| Repo | `~/projects/bellybuddy-core` | `~/projects/bellybuddy` (new worktree `.worktrees/subscription`) |
| Branch | `feat/subscription` from core `feat/share-link` (PR targets `feat/share-link` until it merges, then `develop`) | `feat/subscription` from app `feat/share-link` (same rule) |
| Stack | `scripts/dev-env.sh`, `sg docker -c "docker compose up -d --wait"`, `sg docker -c "docker compose stop worker"`; api 18000, DB 54322 | — |
| Tests | `cd backend && TEST_DATABASE_URL=… uv run pytest <path>` | `flutter test <path>` |
| Gates | `uv run ruff check . && uv run black --check . && uv run mypy --strict app` | `dart format --set-exit-if-changed . && flutter analyze` |

Order: SC1–SC6, then SA1–SA7 (SA5 relies on SC4's 402 contract). The app's pre-commit hook fails inside a worktree: run the app gates by hand and commit with `--no-verify`. No simulator on the dev box: device behaviour is in the spec's „Manual checks".

## Global Constraints

- App strings German, „du"; mascot „Belly Buddy"/„Buddy"; vocabulary test (`test/utils/vocabulary_test.dart`) passes — „Tipp", „Klo", „eintragen", never „Empfehlung".
- Colours only `AppTheme` constants; font sizes `AppTheme.fontSize*`; spacing/radii `AppConstants` (add tokens there first); Riverpod `AsyncNotifier`; GoRouter paths in `lib/router/`; `AppLogger`, never `print()`.
- Remote switch: `app_config` key `paywall_enabled`; only `'true'` is on. Off ⇒ app and core behave exactly as before this branch; RevenueCat is never configured or called.
- Entitlement id `plus`; RevenueCat app user id = Supabase user id; no anonymous RevenueCat users.
- Price and trial length only from the store offer; never a literal „6,90" or „14" in a widget or copy file.
- 402 body: `{"error": "Dafür brauchst du Belly Buddy Plus.", "code": "plus_required"}`.
- No secret in the repo: SDK keys via `env.json`; `REVENUECAT_API_KEY`, `REVENUECAT_WEBHOOK_SECRET` via settings with empty defaults.
- Logs and Sentry: never a token, secret, receipt or purchase payload; user id and an outcome word at most.
- Core: `mypy --strict`; synthetic test data only; fixtures delete `profiles` and `auth.users` rows.
- No privacy-policy version bump here: the spec's „Privacy policy text" goes to the controller's shared policy task.
- Migration number: `0017` at the time of writing; renumber to the next free revision if another track took it.
- Conventional commits; never merge or arm auto-merge; stop at `gh pr create`.

## Review Focus

1. **Switch off after this branch merges.** Every paid route answers as before, the weekly job selects the same users, the app shows no Plus row, no lock, makes no RevenueCat call, and `/plus` redirects Home. Tests in SC4 (`test_switch_off_*`), SC5, SA2 (`switch off: gateway never configured`), SA4, SA6.
2. **Bought a second ago, webhook not there yet.** The next adapt/share call succeeds (lookup on demand; `plus-sync` bypasses the 60 s negative cache). Tests in SC2 and SC3.
3. **Webhook replayed, out of order, a TRANSFER, an unknown or anonymous id, a wrong secret.** State equals RevenueCat's current answer; nothing else is touched; 401 for the secret. Tests in SC3.
4. **Account switch on one device.** User B never sees user A's Plus, and a status load for A that finishes after B signed in is dropped. Test in SA2.
5. **Purchase cancelled, pending or failing; offer unavailable.** Cancel shows nothing; pending and error show their lines; no buy button without an offer; restore with nothing found says so. Tests in SA3.

---

## Part 1: Core

### Task SC1: Migration `0017_plus_entitlements`

**Files:**
- Create: `backend/migrations/versions/0017_plus_entitlements.py`
- Test: `backend/tests/db/test_plus_entitlements.py`
- Modify: `backend/tests/conftest.py` (`USER_TABLES` += `plus_entitlements`), generic RLS/parity tests only as they require.

**Interfaces — Produces:** `public.plus_entitlements(user_id uuid primary key references auth.users on delete cascade, expires_at timestamptz, period_type text check (period_type in ('trial','intro','normal')), product_id text, store text, checked_at timestamptz not null)`; RLS on, `revoke all from anon, authenticated`, no policy. `insert into app_config values ('paywall_enabled','false') on conflict do nothing`. Downgrade drops the table and deletes the key.

- [ ] **Step 1: Write the failing tests:** `test_clients_have_no_access` (select as `authenticated` and `anon` raises permission denied), `test_period_type_check_rejects("monthly")`, `test_row_goes_with_the_user` (delete `auth.users` cascades), `test_paywall_switch_seeded_off` (`select value from app_config where key='paywall_enabled'` == `'false'`, readable as `anon`).
- [ ] **Step 2: Run** `uv run pytest tests/db/test_plus_entitlements.py` — expected FAIL (relation does not exist).
- [ ] **Step 3: Write the migration** (`revision="0017"`, `down_revision="0016"`), docstring style of `0016_data_shares.py`.
- [ ] **Step 4: Run** `uv run pytest tests/db` — expected PASS.
- [ ] **Step 5: Commit** `feat(db): plus_entitlements and the paywall switch (0017)`.

### Task SC2: `app/domain/plus.py` — switch, RevenueCat lookup, `has_plus`

**Files:**
- Create: `backend/app/domain/plus.py`, `backend/app/revenuecat.py`
- Modify: `backend/app/settings.py` (`revenuecat_api_key: str = ""`, `revenuecat_webhook_secret: str = ""`), `docker-compose.yml` and `docker-compose.prod.yml` (`REVENUECAT_API_KEY: ${REVENUECAT_API_KEY:-}`, same for the secret), `environment/ci/.env.ci` (dummies), `environment/production/.env.production.example`, `environment/README.md` (both keys under „Severin supplies").
- Test: `backend/tests/domain/test_plus.py`, `backend/tests/test_revenuecat.py`

**Interfaces — Produces:**

```python
# revenuecat.py
API = "https://api.revenuecat.com/v1"
TIMEOUT_S: Final = 5.0
@dataclass(frozen=True)
class Entitlement: expires_at: datetime | None; period_type: str | None; product_id: str | None; store: str | None
class RevenueCatError(Exception): ...          # message is an outcome word only
async def fetch_entitlement(user_id: uuid.UUID) -> Entitlement   # GET /subscribers/{uid}, Bearer revenuecat_api_key;
    # `plus` entitlement: expires = max(expires_date, grace_period_expires_date); period_type/store from
    # subscriptions[product_identifier]; no `plus` -> Entitlement(None, None, None, None); non-2xx/timeout/no key -> RevenueCatError
async def delete_subscriber(user_id: uuid.UUID) -> None          # DELETE /subscribers/{uid}; 404 counts as done

# domain/plus.py
ENTITLEMENT: Final = "plus"
NEGATIVE_CACHE_S: Final = 60
PLUS_REQUIRED: Final = "Dafür brauchst du Belly Buddy Plus."
async def paywall_enabled(session: AsyncSession) -> bool          # app_config 'paywall_enabled' == 'true'
async def refresh(session: AsyncSession, user_id: uuid.UUID, now: datetime) -> bool   # fetch + upsert row (checked_at=now); returns expires_at > now
async def has_plus(user_id: uuid.UUID, now: datetime, *, force: bool = False) -> bool
async def plus_user(user: Annotated[User, Depends(current_user)]) -> User    # FastAPI dependency: has_plus or ApiError(402, PLUS_REQUIRED, code="plus_required")
```

`has_plus` rules (spec 4.2): switch off → True without touching the table; row with `expires_at > now` → True; row `checked_at` younger than `NEGATIVE_CACHE_S` and not `force` → False; else `refresh`; `RevenueCatError` → the row's answer (none → False), logged `plus lookup failed`.

- [ ] **Step 1: Write the failing tests** (RevenueCat mocked with respx):

```python
async def test_switch_off_is_plus_without_lookup(...)          # no respx route called, no row written
async def test_active_row_needs_no_lookup(...)
async def test_no_row_looks_up_and_stores(...)                 # respx 200 with plus expires in 10 days -> True; row.period_type == "trial"
async def test_expired_row_is_refetched_once_then_cached(...)  # two calls within 60 s -> one respx call; at 61 s -> second call
async def test_force_ignores_the_negative_cache(...)
async def test_grace_period_counts(...)                         # expires_date past, grace_period_expires_date future -> True
async def test_revenuecat_down_falls_back_to_row(...)           # 503 -> row answer; no row -> False; caplog has no api key
async def test_unconfigured_key_means_no_plus(...)              # revenuecat_api_key "" -> False, no HTTP call
async def test_plus_user_raises_402_with_code(...)
```

- [ ] **Step 2: Run** `uv run pytest tests/domain/test_plus.py tests/test_revenuecat.py` — expected FAIL (module not found).
- [ ] **Step 3: Implement** both modules and the settings/compose/env entries (compose style of `FIREBASE_SA_JSON_B64`).
- [ ] **Step 4: Run** the tests — expected PASS; `uv run pytest tests/test_settings.py` (if present) still PASS.
- [ ] **Step 5: Commit** `feat(plus): entitlement lookup and the paywall switch`.

### Task SC3: Routes `revenuecat-webhook` and `plus-sync`

**Files:**
- Create: `backend/app/routes/revenuecat_webhook.py`, `backend/app/routes/plus_sync.py`
- Test: `backend/tests/routes/test_revenuecat_webhook.py`, `backend/tests/routes/test_plus_sync.py`

**Interfaces — Consumes:** SC2. **Produces:**
- `NAME = "revenuecat-webhook"`: `POST` with `Authorization: Bearer <revenuecat_webhook_secret>` (`hmac.compare_digest`). Secret unset → 503 `{"error": "Nicht eingerichtet."}`; wrong/missing → 401 `{"error": "Nicht berechtigt."}`; body not `{"event": {...}}` → 400. `type == "TEST"` → 200 `{"ok": true}`. Ids: `app_user_id`, plus `transferred_from` and `transferred_to` for `TRANSFER`; each UUID of an existing `auth.users` row → `plus.refresh`; others skipped. Any `RevenueCatError` → 502. Else 200 `{"ok": true}`. Log: `revenuecat event <type>: <outcome>`.
- `NAME = "plus-sync"`: `POST`, `current_user`; `Throttle(limit=10, window_s=3600)` → 429 `{"error": "Bitte versuch es später nochmal."}`; answers `{"plus": bool, "expires_at": iso | null}` from `has_plus(..., force=True)` and the row. Switch off → `{"plus": true, "expires_at": null}` without lookup.

- [ ] **Step 1: Write the failing tests:**

```python
async def test_wrong_or_missing_secret_is_401(...)              # and no respx call
async def test_unset_secret_is_503(...)
async def test_test_event_is_ok(...)
async def test_purchase_event_stores_revenuecat_state(...)      # row expires_at == respx answer
async def test_replayed_and_out_of_order_events_end_in_current_state(...)   # EXPIRATION delivered after RENEWAL, respx says active -> row active
async def test_transfer_refreshes_both_users(...)
@pytest.mark.parametrize("uid", ["$RCAnonymousID:abc", "not-a-uuid", str(uuid.uuid4())])   # last: no such user
async def test_unknown_ids_are_ignored(...)                     # 200, no row
async def test_lookup_failure_is_502_for_retry(...)
async def test_plus_sync_bypasses_negative_cache(...)           # row checked 5 s ago, expired; respx active -> {"plus": true}
async def test_plus_sync_throttled_after_10(...)
async def test_plus_sync_switch_off(...)
```

- [ ] **Step 2: Run** — expected FAIL (404).
- [ ] **Step 3: Implement** both routes (`@fallback_500(NAME)`, `service_session()`), auth comparison in the style of `handle_email_suppression.py`.
- [ ] **Step 4: Run** `uv run pytest tests/routes/test_revenuecat_webhook.py tests/routes/test_plus_sync.py tests/routes/test_mounting.py` — expected PASS.
- [ ] **Step 5: Commit** `feat(api): RevenueCat webhook and plus-sync`.

### Task SC4: Gate the paid routes

**Files:**
- Modify: `backend/app/routes/adapt_recipe.py`, `backend/app/routes/shares.py`, `backend/app/routes/diet_recommendations.py`, `backend/app/routes/refresh_ingredient_suggestions.py` (and `app/domain/ingredient_suggestions.refresh_meals` if the window belongs there)
- Test: the matching files under `backend/tests/routes/`

**Interfaces — Consumes:** `plus_user`, `has_plus`, `paywall_enabled`, `PLUS_REQUIRED` (SC2).
Rules (spec 4.2):
- `adapt-recipe`: `Depends(plus_user)` replaces `current_user`; 402 comes before the 400 parse, the 409s, the throttle and any AI call. Add `"plus_required": PLUS_REQUIRED` to `ERRORS`.
- `shares` create: `Depends(plus_user)`; `/end` unchanged.
- `diet-recommendations`: if the user has an own non-broadcast `recommendations` row and not `has_plus` → 402; first set free.
- `refresh-ingredient-suggestions`: not `has_plus` → `{"created": 0}`, nothing marked analysed; with the switch on, only meals with `tracked_at >= wall-clock now − 14 days` (`app.domain.wall_clock`, user's zone) are read.

- [ ] **Step 1: Write the failing tests:**

```python
async def test_adapt_needs_plus(...)                      # switch on, no row, respx no plus -> 402 code plus_required; AI mock not called; throttle not hit
async def test_adapt_with_plus_works(...)                 # existing happy-path test with an active row
async def test_create_share_needs_plus_end_does_not(...)
async def test_existing_share_view_works_after_lapse(...)  # test_share_view.py: row expired -> open + data still 200
async def test_first_tip_is_free_later_ones_need_plus(...)
async def test_suggestions_without_plus_create_nothing_and_mark_nothing(...)
async def test_suggestions_only_last_14_days_when_switch_on(...)   # meal at wall-clock now-15d stays unanalysed
@pytest.mark.parametrize("route", ["adapt-recipe", "shares", "diet-recommendations", "refresh-ingredient-suggestions"])
async def test_switch_off_route_behaves_as_before(route, ...)       # no row, no respx call, today's answer
```

- [ ] **Step 2: Run** — expected FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `uv run pytest tests/routes` — expected PASS.
- [ ] **Step 5: Commit** `feat(plus): paid routes need Belly Buddy Plus when the paywall is on`.

### Task SC5: Weekly tips job and account deletion

**Files:**
- Modify: `backend/app/jobs/weekly_tips.py` (`_ELIGIBLE` += `and (not :paywall or exists (select 1 from public.plus_entitlements e where e.user_id = p.user_id and e.expires_at > :now))`; `_params` reads `paywall_enabled` once per run), `backend/app/routes/delete_account.py` (`plus_entitlements` in step 2; `revenuecat.delete_subscriber` best effort before step 3, `RevenueCatError` logged `revenuecat delete failed` and sent to Sentry, deletion continues; skipped while `revenuecat_api_key` is empty)
- Test: `backend/tests/jobs/test_weekly_tips.py`, `backend/tests/routes/test_delete_account.py`

- [ ] **Step 1: Write the failing tests:** `test_switch_on_selects_only_plus_users` (two opted-in users, one with an active row → only that one), `test_switch_off_selects_as_before`, `test_lapsed_user_keeps_opt_in_and_is_skipped` (`weekly_tips_enabled` still true afterwards), `test_delete_account_deletes_entitlement_and_revenuecat_customer` (respx DELETE called), `test_delete_account_survives_revenuecat_failure` (respx 500 → 200 success, user gone).
- [ ] **Step 2: Run** — expected FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `uv run pytest tests/jobs/test_weekly_tips.py tests/routes/test_delete_account.py` — expected PASS.
- [ ] **Step 5: Commit** `feat(plus): weekly tips only for Plus, deletion removes the RevenueCat customer`.

### Task SC6: Runbook and core gates

**Files:**
- Modify: `docs/runbooks/deploy.md` (section „Switch the paywall on (or off)": the `update public.app_config set value='true' where key='paywall_enabled'` statement, the preconditions from the spec's „Switch-on", and the RevenueCat webhook settings), `docs/needs-from-severin.md` (the spec's RevenueCat and secret items).

- [ ] **Step 1: Write** the two doc changes.
- [ ] **Step 2: Run** the core gates and `uv run pytest` (worker stopped) — expected: all PASS, zero ruff/black/mypy findings.
- [ ] **Step 3: Commit** `docs(plus): runbook for the paywall switch`.
- [ ] **Step 4: Open the PR after the owner's routine** (simplify → code review → fix): `gh pr create --base feat/share-link` (or `develop` once stage 1 merged), body lists the spec's „Needs from Severin". Stop there.

---

## Part 2: App

### Task SA1: Switch, config and the purchases gateway

**Files:**
- Modify: `lib/models/app_config.dart` (`final bool paywallEnabled;`), `lib/repositories/app_config_repository.dart` (also select `paywall_enabled`; missing → false; only `'true'` → true), `env.example.json` (`"REVENUECAT_IOS_KEY": ""`, `"REVENUECAT_ANDROID_KEY": ""`), `pubspec.yaml` (`purchases_flutter`, for the store purchase SDK)
- Create: `lib/config/revenuecat_config.dart`, `lib/models/plus_status.dart`, `lib/services/purchases/purchases_gateway.dart`, `lib/services/purchases/revenuecat_gateway.dart`, `test/helpers/purchases_fakes.dart`
- Test: `test/repositories/app_config_repository_test.dart`, `test/services/purchases/plus_status_test.dart`

**Interfaces — Produces:**

```dart
class RevenueCatConfig { static const iosKey = String.fromEnvironment('REVENUECAT_IOS_KEY'); static const androidKey = String.fromEnvironment('REVENUECAT_ANDROID_KEY'); }

enum PlusState { none, trial, active, lapsed }
class PlusStatus { const PlusStatus({required this.state, this.expiresAt, this.willRenew = false, this.billingIssue = false, this.managementUrl});
  static const none = PlusStatus(state: PlusState.none); bool get granted => state == PlusState.trial || state == PlusState.active; }

class PlusOffer { const PlusOffer({required this.priceString, required this.trialDays, required this.handle});
  final String priceString; final int? trialDays; /* null: not eligible */ final Object handle; }

sealed class PurchaseOutcome {}  // PurchaseDone(PlusStatus) | PurchaseCancelled() | PurchasePending() | PurchaseFailed()
class PurchasesUnavailable implements Exception {}

abstract interface class PurchasesGateway {
  bool get available;                        // false when the platform key is empty
  Future<void> configure(String appUserId);
  Future<void> logIn(String appUserId);
  Future<void> logOut();
  Future<PlusStatus> status();
  Stream<PlusStatus> get statusChanges;
  Future<PlusOffer?> offer();                // current offering's monthly package; null if none
  Future<PurchaseOutcome> purchase(PlusOffer offer);
  Future<PurchaseOutcome> restore();         // PurchaseDone with status none when nothing found
}
PlusStatus plusStatusOf(EntitlementInfo? info)   // in revenuecat_gateway.dart; pure, tested
final purchasesGatewayProvider = Provider<PurchasesGateway>((ref) => RevenueCatGateway());
```

`RevenueCatGateway`: `Purchases.configure(PurchasesConfiguration(key)..appUserID = id)`; trial eligibility iOS via `checkTrialOrIntroductoryPriceEligibility`, Android via `defaultOption?.freePhase`; trial days from the store's period; `PurchasesErrorCode.purchaseCancelledError` → cancelled, `paymentPendingError` → pending. `FakePurchasesGateway` records calls and returns scripted values.

- [ ] **Step 1: Write the failing tests:** repository: `paywall_enabled 'true'` → true, `'false'`/`'TRUE '`/missing → false, missing min/latest still throws; `plusStatusOf`: active+trial → trial, active+normal → active (`willRenew`, `expiresAt` copied), inactive → lapsed, null → none, `billingIssueDetectedAt` set → `billingIssue`.
- [ ] **Step 2: Run** `flutter test test/repositories/app_config_repository_test.dart test/services/purchases/plus_status_test.dart` — expected FAIL.
- [ ] **Step 3: Implement**; `flutter pub add purchases_flutter`; follow its README's Android/iOS steps.
- [ ] **Step 4: Run** the tests — expected PASS.
- [ ] **Step 5: Commit** `feat(plus): paywall switch in app config and the purchases gateway`.

### Task SA2: `plusProvider` and `plusAccessProvider`

**Files:**
- Create: `lib/providers/plus_provider.dart`
- Modify: `lib/providers/auth_provider.dart` (nothing unless sign-out needs `logOut` here; prefer the provider reacting to `currentUserIdProvider`)
- Test: `test/providers/plus_provider_test.dart`

**Interfaces — Consumes:** SA1. **Produces:**

```dart
final paywallEnabledProvider = Provider<bool>   // appConfigProvider.value?.paywallEnabled ?? false
class PlusNotifier extends AsyncNotifier<PlusStatus> {
  Future<PurchaseOutcome> purchase(PlusOffer offer);   // on PurchaseDone: state + best-effort `plus-sync` (EdgeFunctionService)
  Future<PurchaseOutcome> restore();                   // same
}
final plusProvider = AsyncNotifierProvider<PlusNotifier, PlusStatus>(PlusNotifier.new);
final plusOfferProvider = FutureProvider.autoDispose<PlusOffer?>;
enum PlusAccess { open, locked }
final plusAccessProvider = Provider<PlusAccess>;
```

`build`: switch off or no user or `!available` → `PlusStatus.none` with no gateway call. First user → `configure(uid)`; a later different user → `logIn(uid)`; user gone → `logOut()` (once, only if configured). Subscribes to `statusChanges` for the current user. Results for a user who is no longer current are dropped (`ref.isCurrentUser`). `plusAccessProvider`: switch off → open; `plusProvider` loading/error → open; granted → open; else locked.

- [ ] **Step 1: Write the failing tests** (`ProviderContainer`, fake gateway, overridden `appConfigProvider` and `currentUserIdProvider`):

```dart
test('switch off: gateway never configured, access open')
test('switch on, signed out: no gateway call, access open')   // nothing to lock without a user
test('first user configures with the Supabase id')
test('second user logs in, never sees the first user\'s status') // fake answers A's status late -> dropped
test('sign-out logs out once')
test('status changes stream updates the state')
test('lapsed and none lock, trial and active open, error opens')
test('purchase done calls plus-sync; a failing plus-sync still returns done')
```

- [ ] **Step 2: Run** `flutter test test/providers/plus_provider_test.dart` — expected FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** — expected PASS.
- [ ] **Step 5: Commit** `feat(plus): entitlement state from RevenueCat per signed-in user`.

### Task SA3: The paywall `/plus`

**Files:**
- Create: `lib/screens/plus/plus_screen.dart`, `lib/services/plus/plus_copy.dart`
- Modify: `lib/router/route_names.dart` (`plus = 'plus'`, `RoutePaths.plus = '/plus'`), `lib/router/app_router.dart` (route; redirect `/plus` → `RoutePaths.dashboard` while `paywallEnabledProvider` is false), `lib/config/constants.dart` (`termsUrl = 'https://app.bellybuddy.at/nutzungsbedingungen'`, `appleSubscriptionsUrl = 'https://apps.apple.com/account/subscriptions'`, `playSubscriptionsUrl(String productId, String packageName)`)
- Test: `test/screens/plus/plus_screen_test.dart`

**Interfaces — Consumes:** SA2. **Produces:** `PlusCopy` with every German string of spec 4.5 verbatim (benefits, free line, `priceLine(String price, int? trialDays)`, `buyLabel(int? trialDays)`, `termsIos`, `termsAndroid`, `unavailable`, `welcome`, `pending`, `failed`, `restoreNone`, `restoreFailed`, `restore = 'Käufe wiederherstellen'`, `terms = 'Nutzungsbedingungen'`, `privacy = 'Datenschutz'`, `manage = 'Abo verwalten'`) and `PlusCopy.statusLine(PlusStatus)` from spec 4.6 (dates `d.M.`). Keys: `PlusScreen.buyKey`, `restoreKey`, `manageKey`, `closeKey`.

- [ ] **Step 1: Write the failing widget tests** (fake gateway; `TargetPlatform` overridden for the terms text):

```dart
testWidgets('eligible offer: "14 Tage gratis, danach 6,90 € pro Monat" from the fake offer') // fake priceString '6,90 €', trialDays 14
testWidgets('not eligible: "6,90 € pro Monat" and "Plus abonnieren"')
testWidgets('no offer: unavailable line, no buy button, restore still there')
testWidgets('iOS shows termsIos, Android termsAndroid; terms and privacy links open their URLs')
testWidgets('purchase done: closes and shows "Willkommen bei Belly Buddy Plus!"')
testWidgets('cancelled: stays, no SnackBar'); testWidgets('pending: "Dein Kauf wartet noch auf Bestätigung."')
testWidgets('failed: "Der Kauf hat nicht geklappt. Du wurdest nicht belastet."')
testWidgets('restore with nothing found: "Wir haben kein Abo gefunden."')
testWidgets('with Plus: status line and "Abo verwalten", no buy button')
testWidgets('switch off: /plus redirects to Home')
test('PlusCopy.statusLine covers trial, trial ending, active, active ending, billing issue, lapsed, none')
```

- [ ] **Step 2: Run** — expected FAIL.
- [ ] **Step 3: Implement** (double tap on buy runs one purchase; the close button is always visible).
- [ ] **Step 4: Run** `flutter test test/screens/plus test/utils/vocabulary_test.dart` — expected PASS.
- [ ] **Step 5: Commit** `feat(plus): paywall screen`.

### Task SA4: Locks for Muster, Tipps and Alternativen

**Files:**
- Create: `lib/widgets/common/plus_locked_card.dart`, `lib/screens/patterns/widgets/patterns_plus_locked.dart`
- Modify: `lib/screens/patterns/patterns_screen.dart`, `lib/screens/patterns/patterns_unlocked_screen.dart` (line by access), `lib/screens/recommendations/recommendations_screen.dart` (card below the sets / as empty state), `lib/widgets/common/weekly_tips_switch.dart`, `lib/screens/discover/widgets/discover_alternatives_section.dart`, `lib/screens/ingredient_suggestions/ingredient_suggestions_screen.dart` (empty state), `lib/services/plus/plus_copy.dart` (lock copy of spec 4.4)
- Test: `test/screens/patterns/patterns_screen_test.dart`, `test/screens/patterns/patterns_unlocked_screen_test.dart`, `test/screens/recommendations/recommendations_screen_test.dart`, `test/widgets/common/weekly_tips_switch_test.dart`, `test/screens/discover/discover_alternatives_section_test.dart`

**Interfaces — Produces:** `PlusLockedCard({required String title, required String line, Key? key})` whose button `PlusLockedCard.openKey` pushes `RoutePaths.plus`. Copy (spec 4.4, verbatim): `PlusCopy.patternsTitle = 'Deine Muster sind da'`, `patternsLine`, `patternsUnlockedLine`, `tipsTitle = 'Jeden Montag neue Tipps'`, `tipsLine`, `weeklyTipsSubline = 'Mit Belly Buddy Plus'`, `alternativesNote`, `openPlus = 'Belly Buddy Plus ansehen'`.

- [ ] **Step 1: Write the failing tests:** Muster locked by Plus after unlock shows `PatternsPlusLocked` (no `PatternsUnlocked`, `PatternsPreview` present); before day 7 still `PatternsLocked`; access open → `PatternsUnlocked`; „Muster frei!" line switches with access; Tipps with sets + locked → sets and the card; weekly switch locked → subline „Mit Belly Buddy Plus", tap pushes `/plus`, `setWeeklyTips` never called; Alternativen locked and empty → `alternativesNote`, with groups → groups unchanged; every test repeated with the switch off shows today's widgets.
- [ ] **Step 2: Run** — expected FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the five test files and `test/utils/vocabulary_test.dart` — expected PASS.
- [ ] **Step 5: Commit** `feat(plus): locks for Muster, Tipps and Alternativen`.

### Task SA5: Adapting and sharing

**Files:**
- Modify: `lib/models/adapted_recipe.dart` (`AdaptFailure.plusRequired`), `lib/services/recipe_service.dart` (`(402, 'plus_required') => AdaptFailure.plusRequired`), `lib/screens/recipes/collection_recipe_screen.dart` (badge „Plus" on `adaptKey`; locked → push `/plus`), `lib/screens/recipes/adapt_recipe_screen.dart` (`plusRequired` → replace with `/plus`), `lib/services/share_service.dart` (`ShareException.plusRequired` getter for 402 + code), `lib/screens/shares/shares_screen.dart` and `share_create_screen.dart` („Neue Freigabe" and a 402 → `/plus`), `lib/screens/me/me_screen.dart` (`_openShare`: locked and no share → `/plus` instead of the create screen)
- Test: `test/services/recipe_service_test.dart`, `test/screens/recipes/collection_recipe_screen_test.dart`, `test/screens/shares/shares_screen_test.dart`, `test/screens/me/me_screen_test.dart`

- [ ] **Step 1: Write the failing tests:** 402 `plus_required` → `AdaptFailure.plusRequired` (a 402 without the code → `failed`); locked „Für mich anpassen" pushes `/plus`, adapt never called; locked shares list keeps existing shares and „Beenden" works, „Neue Freigabe" pushes `/plus`; create answering 402 pushes `/plus`; Ich share row locked with no share pushes `/plus`, with shares pushes the list; switch off: all as today.
- [ ] **Step 2: Run** — expected FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the four files — expected PASS.
- [ ] **Step 5: Commit** `feat(plus): adapting and new shares need Plus`.

### Task SA6: Ich row and the delete-account warning

**Files:**
- Modify: `lib/screens/me/me_screen.dart` (`MeScreen.plusKey`, row below the share row only while `paywallEnabledProvider`; subtitle `PlusCopy.statusLine`; tap → `/plus`), `lib/screens/settings/widgets/delete_account_dialog.dart` (`PlusCopy.deleteWarning` = „Dein Abo läuft über den Store weiter. Kündige es dort, sonst wird es weiter verrechnet." while `plusProvider` is trial/active)
- Test: `test/screens/me/me_screen_test.dart`, `test/screens/settings/delete_account_dialog_test.dart`

- [ ] **Step 1: Write the failing tests:** switch off → no `plusKey`; on + none → „Alle Funktionen freischalten"; on + trial ending 10.12. with renewal off → „Gratis-Test endet am 10.12."; lapsed → „Abgelaufen · Wieder abonnieren"; tap pushes `/plus`; delete dialog shows the warning for trial/active only.
- [ ] **Step 2: Run** — expected FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** — expected PASS.
- [ ] **Step 5: Commit** `feat(plus): Belly Buddy Plus row in Ich and deletion warning`.

### Task SA7: App gates and PR

- [ ] **Step 1: Run** `dart format --set-exit-if-changed . && flutter analyze` — expected: no changes, „No issues found!".
- [ ] **Step 2: Run** `flutter test` — expected: all PASS.
- [ ] **Step 3: Commit** any formatting fix `chore(plus): format` (`--no-verify`).
- [ ] **Step 4: Open the PR after the owner's routine** (simplify → code review → fix): `gh pr create --base feat/share-link` (or `develop` once stage 1 merged); body links the spec, lists „Needs from Severin" and „Manual checks for Severin". Stop there.
