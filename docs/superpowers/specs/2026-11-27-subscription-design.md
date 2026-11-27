# Belly Buddy Plus (Abo) — Design

**Status:** product decisions by Severin 2026-11-26 (price, trial, free/paid split, RevenueCat, ships switched off, shares
rule); everything marked „Claude's call" decided by the planner in his absence. Track E1 of the business-plan gap analysis.
**Repos:** app `severinkl/bellybuddyapp` and core `severinkl/bellybuddy-core`, branch `feat/subscription` in each, stacked on
`feat/share-link` (stage 1: the „Mit Berater:in teilen" feature this gates). Plan: `docs/superpowers/plans/2026-11-27-subscription.md`.

## 1. Intent

The business plan needs revenue; the app has none. This adds one monthly subscription, „Belly Buddy Plus", that unlocks
what costs us AI money or is the app's deeper value (Muster, Tipps, Alternativen, recipe adapting, sharing with a
dietitian), while logging and the Buddy stay free forever. It ships **switched off**: one remote switch keeps the whole app
free and unchanged until Severin turns the paywall on.

**Success:** with the switch off, nobody can tell the feature exists (no RevenueCat call, no Plus row, no lock). With the
switch on, a user who opens a paid feature sees what it does, starts the store's 14-day trial in two taps, and gets the
feature at once; a modified client cannot get the server's paid work without a subscription; restoring and managing the
subscription always work.
**Anti-goals:** dark patterns (fake countdowns, guilt copy, hidden price, pre-ticked anything, a close button that is hard to
find); locking what the user already has (their diary, tips and alternatives already received, active shares); a paywall in
the logging flow; any health data reaching RevenueCat.

## 2. Decisions

| # | Topic | Decision | By |
|---|---|---|---|
| 1 | Product | „Belly Buddy Plus", one auto-renewing monthly subscription, 6,90 €, 14 days free | Severin |
| 2 | Free forever | Meals, drinks, Bauchgefühl, Klo; Tagebuch; Buddy, streaks, the 7-day journey | Severin |
| 3 | Paid | Muster, Tipps, Alternativen, recipe adapting, creating share links | Severin |
| 4 | Purchases | RevenueCat (`purchases_flutter`); Severin creates products and the RevenueCat project | Severin |
| 5 | Ships off | App config key `paywall_enabled` (`'false'`); app and core both read it | Severin (key name: Claude) |
| 6 | Shares on lapse | Existing shares work until they expire or are ended; creating a link needs Plus (connections: decision 16) | Severin |
| 7 | Entitlement | One RevenueCat entitlement `plus`; in the app RevenueCat's customer info is the truth, on the server a `plus_entitlements` row kept by a webhook and by on-demand lookups | Claude's call — wrong: one more table to migrate if RevenueCat's v2 API is wanted later |
| 8 | Trial | Store-managed introductory offer (14 days free), no app-side trial | Claude's call — wrong: an app trial would need its own server clock and abuse checks |
| 9 | What a lapse takes | „What you got stays": tips and alternatives already received stay readable; only *new* ones (weekly tips, new alternatives, adapting, new shares) need Plus. Muster (computed live) locks, Home's one-line Muster pick stays free | Claude's call — wrong: lapsed users keep more value; easy to tighten later in the app alone |
| 10 | Journey | The journey stays free with its rewards: the day-3 first tip is free (server allows a user's first tip set without Plus); day 7 still celebrates, its line says the Muster are ready, the Muster page then offers the trial | Claude's call — wrong: day 7 becomes the main trial moment; if Severin wants no paywall in the journey's last step, Muster must be free until day 14 |
| 11 | Unknown state | App: entitlement unknown (loading, error) counts as unlocked; config unreadable counts as switch off. Server enforces its own features | Claude's call — wrong: an offline non-subscriber sees Muster for a session |
| 12 | Existing users at switch-on | Nobody grandfathered; everyone can take the store trial on their first paid feature | Severin's default — **confirm** |
| 13 | RevenueCat before switch-on | The SDK is not configured at all while the switch is off (no network, no identifiers) | Claude's call — wrong: the first switch-on day has no RevenueCat history (none needed) |
| 14 | Alternativen backlog | With the switch on, `refresh-ingredient-suggestions` analyses only meals of the last 14 days (wall clock) | Claude's call — wrong: a resubscriber misses alternatives for older meals |
| 15 | Account deletion | Also deletes the RevenueCat customer (best effort); the dialog warns that the store subscription continues until cancelled | Claude's call |
| 16 | Dietitian connection | Free, also with the switch on: entering or scanning a practice code, connecting, editing and ending a connection, and the dietitian's tips on Entdecken. Only creating a share link needs Plus. Overrides the planner's ruling R10 (connect gated as „sharing with a dietitian") | Severin, 2026-11-27 |

## 3. Approaches

- **RevenueCat webhook + server lookup on demand (picked).** The webhook (`Authorization` header with a shared secret)
  tells core *that* something changed; core then reads the subscriber's current state from RevenueCat's REST API and stores
  it. Re-deliveries and out-of-order events are harmless (each one refetches the truth), so no event log is needed. A user
  with no row, or a row that says expired, gets one lookup on demand (cached), which also covers „bought a second ago, the
  webhook is still on its way".
- **Trust the webhook payload alone.** Rejected: events can arrive out of order and repeat; we would need an event log and
  ordering by `event_timestamp_ms`, and a purchase is not visible to core until the webhook lands.
- **App sends its customer info to core.** Rejected: a modified client could forge it.
- **App-side trial.** Rejected: the stores already run 14-day free trials, refund rules and reminders, and the price/trial
  wording must match what the store charges.

## 4. Design

### 4.1 Remote switch
- Core migration adds `app_config` row `('paywall_enabled', 'false')`. Only the exact value `'true'` means on.
- App: `AppConfig` gains `paywallEnabled` (missing key → false); `appConfigProvider` already loads once per process. A
  failed config fetch → off (decision 11).
- Core: `app.domain.plus.paywall_enabled(session)` reads the row on each paid request (one indexed read); off → every
  paid route behaves exactly as today.
- Turning it on: Severin sets the row on prod (runbook section added by the plan). Turning it off again restores free use
  at the next app start; nobody's data changes.

### 4.2 Entitlement in core
- Table `public.plus_entitlements`: `user_id uuid pk references auth.users on delete cascade`, `expires_at timestamptz`
  (null: never had Plus), `period_type text` (`trial|intro|normal`, null), `product_id text`, `store text`, `checked_at
  timestamptz not null`. RLS on, no grant to `anon`/`authenticated`: only the api reads it.
- `has_plus(user_id, now)`: switch off → true. Row with `expires_at > now` → true. Otherwise, unless `checked_at` is
  younger than 60 s (negative cache), look the user up at RevenueCat (`GET /v1/subscribers/{uid}`, secret key, 5 s timeout),
  upsert the row, answer from it. RevenueCat unreachable → the row's answer (none → false), logged with an outcome word.
- Expiry = the `plus` entitlement's `expires_date`, or its `grace_period_expires_date` if later (store billing grace keeps
  Plus during a payment retry).
- Paid server work answers **402** `{"error": "Dafür brauchst du Belly Buddy Plus.", "code": "plus_required"}`:
  - `adapt-recipe` (before the throttle and the AI call);
  - `shares` create (`/end` stays free); `share-view` untouched, so existing shares keep working (decision 6);
    `shares/dietitian` (portal connect) and `shares/{id}/update` stay free (decision 16);
  - `diet-recommendations`, except when the user has no own non-broadcast recommendation yet (the journey's first tip);
  - `refresh-ingredient-suggestions` without Plus answers `200 {"created": 0}` and leaves the meals unanalysed (it is
    fire-and-forget after a meal; no error for the app to show); with the switch on it analyses meals of the last 14 days only;
  - the weekly-tips job: eligibility adds „switch off, or `plus_entitlements.expires_at > now`" (table only, no lookups in
    the job). A user who keeps `weekly_tips_enabled` but lapsed is skipped silently and resumes on resubscribing.
- Routes:
  - `POST /functions/v1/revenuecat-webhook`: `Authorization: Bearer <REVENUECAT_WEBHOOK_SECRET>`, constant-time compare;
    secret unset → 503; wrong/missing → 401. Body `{"event": {"type", "app_user_id", "transferred_from"?, "transferred_to"?}}`.
    `TEST` → 200. Every id that is a UUID of an existing user (from `app_user_id`, and for `TRANSFER` both lists) is
    refreshed from RevenueCat; anonymous `$RCAnonymousID:` and unknown ids are ignored. Lookup failure → 502, so
    RevenueCat retries. Success → `200 {"ok": true}`. Logs: event type and outcome, never ids beyond the user id.
  - `POST /functions/v1/plus-sync` (signed-in user): forces a lookup for the caller (ignores the negative cache), answers
    `{"plus": bool, "expires_at": iso|null}`; throttled to 10 per hour per user. The app calls it after a purchase or restore.
- Account deletion: deletes the `plus_entitlements` row with the user's rows and calls RevenueCat's
  `DELETE /v1/subscribers/{uid}` best effort (failure logged and reported, deletion goes on).
- Settings: `revenuecat_api_key: str = ""` (secret v1 key), `revenuecat_webhook_secret: str = ""`; empty = not
  configured (lookups answer „no Plus", webhook 503). Compose passes both as `${…:-}`; CI gets dummies; Severin sets prod values.

### 4.3 Entitlement in the app
- `PurchasesGateway` (interface): `configure(String appUserId)`, `logIn(String)`, `logOut()`, `status()`,
  `statusChanges` (stream), `offer()`, `purchase(PlusOffer)`, `restore()`. `RevenueCatGateway` wraps `purchases_flutter`;
  tests use `FakePurchasesGateway`. Nothing else imports `purchases_flutter`.
- `PlusStatus { PlusState state (none|trial|active|lapsed), DateTime? expiresAt, bool willRenew, bool billingIssue,
  String? managementUrl }`, from customer info's `plus` entitlement: active + period trial → trial; active → active;
  present but inactive → lapsed; absent → none.
- `plusProvider` (AsyncNotifier): only while the switch is on and a user is signed in. Configures RevenueCat once with
  `appUserID` = Supabase user id; a different user → `logIn(newId)` (the old user's status is never shown, a load for the
  old user lands nowhere: `ref.isCurrentUser`); sign-out → `logOut()`. No user → no SDK call (no anonymous RevenueCat users).
- `plusAccessProvider` → `PlusAccess.open | locked`: switch off → open; status unknown → open; trial/active → open;
  none/lapsed → locked. Every lock in the UI reads only this.
- SDK keys: `REVENUECAT_IOS_KEY`, `REVENUECAT_ANDROID_KEY` through `--dart-define-from-file=env.json` (`RevenueCatConfig`,
  like `SupabaseConfig`). Empty key → the gateway reports „not available" and the paywall says „Gerade nicht verfügbar";
  not part of `_validateEnv` (the app must run without them while the switch is off).

### 4.4 What „locked" looks like
One widget, `PlusLockedCard` (title, one line, button „Belly Buddy Plus ansehen" → `/plus`), in the style of
`PatternsLocked`'s card (`BbCard`, `AppTheme.primarySoft`). Entry points stay where they are; the screens show the lock.

| Place | Locked (switch on, no Plus) |
|---|---|
| Home insight card | Unchanged: the journey, the progress, and once unlocked the one-line pick stay free |
| „Muster frei!" (day 7) | Line becomes „7 Tage und 3× Bauchgefühl: Ich hab mir deine Einträge angeschaut. Deine ersten Muster sind da." Button unchanged |
| Muster page | Before day 7: unchanged `PatternsLocked`. After: `PatternsPlusLocked` — card „Deine Muster sind da" / „Mit Belly Buddy Plus siehst du, was an guten und schwierigen Tagen auffällig oft dabei war.", the blurred `PatternsPreview`, button |
| Tipps screen | Received sets stay readable, feedback works; below them the card „Jeden Montag neue Tipps" / „Mit Belly Buddy Plus schaut sich Belly Buddy jede Woche deine Einträge an." Empty state: the same card |
| Home Tipps row, Entdecken Tipps | Unchanged (they show received sets) |
| „Wöchentliche Tipps" switch (Entdecken opt-in, Einstellungen) | Subline „Mit Belly Buddy Plus"; tapping opens `/plus`; the stored value is not changed |
| Day-3 first tip offer | Unchanged and free |
| Alternativen (Entdecken section, list screen) | Received ones stay; with none, the note „Alternativen zu auffälligen Zutaten gibt es mit Belly Buddy Plus." and a link to `/plus` instead of „sie entstehen nach deinen Mahlzeiten" |
| „Für mich anpassen" | Button stays with a small „Plus" badge; tap → `/plus`. A 402 from core (stale app state) → `AdaptFailure.plusRequired` → `/plus` |
| „Mit Berater:in teilen" | Row stays and opens the list (existing shares must stay reachable; with no share the list alone, not the create screen). „Link erstellen" and „Neu erstellen" → `/plus`; a 402 on link create → `/plus`. „Berater:in verbinden", the connect flow, „Ändern" and ending stay free (decision 16) |

### 4.5 Paywall `/plus`
Route `/plus` (redirects to Home while the switch is off). Opened from every lock and the Ich row. Close button top left,
always visible. No timers, no „nur heute".

- Title „Belly Buddy Plus", the Buddy (happy).
- „Damit holst du mehr aus deinen Einträgen:" then five lines: „Muster: was an guten und schwierigen Tagen auffällig oft
  dabei war" · „Jeden Montag neue Tipps zu deinen Einträgen" · „Alternativen zu Zutaten, die bei dir auffällig sind" ·
  „Rezepte für dich anpassen" · „Dein Tagebuch per Link mit Diätolog:in oder Ärzt:in teilen" (decision 16: connecting is free).
- „Immer gratis: Mahlzeiten, Getränke, Bauchgefühl und Klo eintragen, dein Tagebuch, Belly Buddy, Streaks und die Reise."
- Price block from the store offer only: eligible for the trial → „{n} Tage gratis, danach {price} pro Monat"; else
  „{price} pro Monat". `{price}` = the store's `priceString`, `{n}` = the intro offer's length from the store. Button:
  „{n} Tage gratis testen" or „Plus abonnieren". Offer not loadable → „Belly Buddy Plus ist gerade nicht verfügbar.
  Versuch es später nochmal." and no buy button.
- Terms text (platform-specific, below the button, always visible):
  - iOS: „Das Abo verlängert sich jeden Monat automatisch, wenn du es nicht spätestens 24 Stunden vor Ablauf kündigst. Die
    Zahlung läuft über deine Apple-ID. Kündigen kannst du jederzeit in den Einstellungen deiner Apple-ID. Kündigst du in den
    Gratis-Tagen, zahlst du nichts."
  - Android: „Das Abo verlängert sich jeden Monat automatisch, bis du es kündigst. Die Zahlung läuft über dein
    Google-Play-Konto. Kündigen kannst du jederzeit in Google Play unter „Abos". Kündigst du in den Gratis-Tagen, zahlst du
    nichts."
- Links: „Käufe wiederherstellen", „Nutzungsbedingungen" (`AppConstants.termsUrl`), „Datenschutz"
  (`AppConstants.privacyPolicyUrl`).
- Outcomes: purchase ok → `plus-sync`, then the paywall closes with the SnackBar „Willkommen bei Belly Buddy Plus!";
  cancelled by the user → nothing; pending (Ask to Buy, slow card) → „Dein Kauf wartet noch auf Bestätigung."; error →
  „Der Kauf hat nicht geklappt. Du wurdest nicht belastet." Restore: found → as success; none → „Wir haben kein Abo
  gefunden."; error → „Wiederherstellen hat nicht geklappt. Versuch es später nochmal."
- With Plus (opened from Ich): the status line (4.6), „Abo verwalten" (customer info's `managementURL`, else the store's
  subscriptions page), restore and the links; no buy button.

### 4.6 Ich row and account deletion
- „Belly Buddy Plus" row (icon `workspace_premium_outlined`), directly below „Mit Berater:in teilen", only while the switch
  is on. Subtitles: none „Alle Funktionen freischalten"; trial „Gratis-Test bis {d.M.}" / with renewal off „Gratis-Test
  endet am {d.M.}"; active „Aktiv · verlängert sich am {d.M.}" / renewal off „Aktiv bis {d.M.}"; billing issue „Zahlung
  offen – bitte im Store prüfen"; lapsed „Abgelaufen · Wieder abonnieren". Tap → `/plus`.
- Delete-account dialog, while Plus is trial/active: one more line „Dein Abo läuft über den Store weiter. Kündige es dort,
  sonst wird es weiter verrechnet."

### 4.7 Store requirements (built in)
Restore button on the paywall; price and length from the store; auto-renew and cancel text; links to terms and privacy;
manage-subscription link; account deletion exists and warns about the running subscription; no purchase UI outside
`/plus`; sandbox-testable.

## 5. Privacy policy text

New section for the shared „policy text" task (no version bump in this track):

> **Abo „Belly Buddy Plus" (RevenueCat)**
> Wenn du Belly Buddy Plus abschließt oder dir die Abo-Seite ansiehst, nutzen wir den Dienst RevenueCat (RevenueCat, Inc.,
> USA) als Auftragsverarbeiter, um dein Abo zu verwalten. Dabei werden verarbeitet: deine Belly-Buddy-Nutzerkennung (eine
> zufällige ID, nicht deine E-Mail-Adresse), deine Käufe und ihr Status (Produkt, Kaufdatum, Gratis-Zeitraum, Ablauf,
> Verlängerung), Kennungen des App Store bzw. von Google Play zu deinen Käufen, sowie technische Angaben zu deinem Gerät
> (Gerätetyp, Betriebssystem, App-Version, Land des Stores, IP-Adresse). Gesundheitsdaten und Tagebuch-Einträge gehen nicht
> an RevenueCat. Die Zahlung selbst wickeln Apple bzw. Google ab; Zahlungsdaten erhalten wir nicht. Rechtsgrundlage ist die
> Erfüllung des Vertrags (Art. 6 Abs. 1 lit. b DSGVO). Die Übermittlung in die USA stützt sich auf den
> EU-US Data Privacy Framework bzw. EU-Standardvertragsklauseln. Wir speichern bei uns, ob und bis wann dein Abo gilt. Löschst
> du dein Konto, löschen wir diese Angaben auch bei RevenueCat; gesetzliche Aufbewahrungspflichten der Stores bleiben
> unberührt. Solange Belly Buddy Plus nicht angeboten wird, findet keine Übermittlung an RevenueCat statt.

## 6. Non-goals
- Yearly plan, family sharing, promo codes, win-back offers, a reminder before the trial ends (the stores show trial terms).
- RevenueCat Paywalls / `purchases_ui_flutter`; experiments; analytics events.
- Locking anything in logging, Tagebuch, Buddy, streaks, journey, Wissen, recipes collection browsing, own recipes.
- An entitlement view in the admin panel.
- Server-side protection of already-generated tips/alternatives (they are the user's own rows, read through RLS).

## 7. Left to the builder
- `purchases_flutter` version (`flutter pub add purchases_flutter`, current major) and its README's native steps.
- How `PlusLockedCard` and the „Plus" badge look within `AppTheme`/`AppConstants` (new tokens added there first).
- Whether `plusProvider` listens to RevenueCat's customer-info stream directly or through the gateway's `statusChanges`, as
  long as the fake can drive it.

## 8. Needs from Severin
- **Confirm:** decision 12 (no grandfathering; everyone gets the store trial), decision 10 (day 7 is where most users meet
  the paywall), decision 9 (received tips/alternatives stay readable after a lapse).
- **Create:** App Store Connect subscription group „Belly Buddy Plus", product `bellybuddy_plus_monthly`, 6,90 € (AT/DE/CH
  price points), introductory offer „free, 2 weeks", review screenshot; Play Console subscription `bellybuddy_plus` with base
  plan `monthly` (auto-renewing) and offer `trial-14d` (free trial, 14 days, new customers only); Paid Apps agreement and
  tax/bank details in both consoles.
- **RevenueCat:** project with both apps; entitlement `plus` attached to both products; offering `default` with package
  `$rc_monthly`; App Store Server Notifications V2 and Google RTDN set up as RevenueCat documents; restore behaviour
  „Transfer to new App User ID"; webhook URL `https://api.bellybuddy.at/functions/v1/revenuecat-webhook` with the
  Authorization header `Bearer <secret>`.
- **Secrets:** `REVENUECAT_IOS_KEY`, `REVENUECAT_ANDROID_KEY` into the `ENV_JSON_BASE64` GitHub secret (and local
  `env.json`); `REVENUECAT_API_KEY` (v1 secret key) and `REVENUECAT_WEBHOOK_SECRET` into core's production vaultfile
  (`dotenvx set`).
- **Legal:** a „Nutzungsbedingungen" page at `https://app.bellybuddy.at/nutzungsbedingungen` (or Apple's standard EULA for iOS
  plus a page for Android) — the switch must not go on before it exists; sign-off of the privacy paragraph above; Impressum
  /AGB check for a paid offer in AT/DE/CH.
- **Verify:** RevenueCat's DPF certification and DPA; that Apple accepts the trial wording; whether Play requires the
  „Abos"-deep-link wording; whether the iOS target needs the In-App Purchase capability ticked; tax treatment of the price
  (stores are merchant of record).
- **Switch-on:** set `paywall_enabled` to `'true'` on prod only after both stores approved the subscription with an app
  version that contains this feature.

## 9. Manual checks for Severin
1. Switch off (default): app looks and behaves exactly as today; no Plus row; no RevenueCat traffic (proxy or RevenueCat
   dashboard shows no new customer).
2. Switch on, iOS sandbox account: Muster → lock → paywall shows store price and „14 Tage gratis"; buy; Muster opens; Ich
   row „Gratis-Test bis …"; adapt a recipe works; create a share link works. Without Plus: connecting to a dietitian by practice code works.
3. Same on Android with a license tester (Play internal track).
4. Cancel in the store's subscription settings → Ich row „… endet am …"; let the sandbox subscription expire → locks return,
   existing share link still opens on Connect, received tips still readable.
5. Delete the app, reinstall, sign in → Plus is back without buying; „Käufe wiederherstellen" on a second account moves Plus.
6. RevenueCat dashboard „Send test event" → core logs 200; check one real event updates `plus_entitlements`.
7. Delete account with an active trial → the warning line shows; RevenueCat customer gone afterwards.
8. Sign out and in as another user on the same device → the other user's state, never the first user's.
