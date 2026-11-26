# Tagebuch per Link teilen (Berater-Freigabe, Stufe 1) — Design

**Status:** decisions by Severin 2026-11-26 (brainstorm after the business-plan gap analysis). Mockups, screens 1–5:
https://claude.ai/artifact/P1iJWvSx1AsFkCyD5rJMYo (the canvas keeps each screen's HTML as `project/<name>.dc.html`:
`Main`, `Teilen`, `Link`, `Code`, `Bericht`; take colours and layout from there). Screens 6–14 on the same canvas show the
later stages and are **not** part of this design.
**Repos:** app `severinkl/bellybuddyapp` (branch `feat/share-link` from `develop` @ 22a9a2b), core `severinkl/bellybuddy-core`
(api, migration, edge config, privacy policy; branch from `develop`) and a **new** private repo `severinkl/bellybuddy-connect`
(the dietitian-facing web, served at `connect.bellybuddy.at`). The three ship together, core first.

## 1. Intent

The business plan's third core feature is the connection between clients and dietitians. The app has nothing for it. Severin
decided to build it in three stages that reuse one web view:

1. **Share link (this design):** a client shares a live, read-only view of their diary with a dietitian or doctor.
2. **Portal:** dietitians get a login, a client list, private notes and one-way recommendations to the client.
3. **Marketplace:** a directory of verified dietitians in the app, with booking and payment by us and video elsewhere.

Stage 1 exists so that a client can bring their Belly Buddy data into a consultation they already have, and so that dietitians
meet the product through their own clients. It must be useful on its own, with no dietitian account.

**Success:** a client creates a share in under a minute; the dietitian opens it on a desktop browser with link and code and can
read the last weeks at a glance and print them; the client sees whether it was opened and can end it at any time.
**Anti-goals:**
- A link that works without the code, or data that stays readable after the share ended or expired.
- The token or code in a server log, Sentry event, analytics call or Referer header.
- Anything in the view that identifies the client beyond the display name they typed (no email, birth year, weight, user id).
- Wording in the view that reads as a diagnosis. It shows what the client logged and frequencies, nothing more.

## 2. Decisions (Severin)

| # | Topic | Options shown | Decision |
|---|---|---|---|
| 1 | Shape of the dietitian feature | link-first / PDF-first / marketplace-first | **Link-first**, one web view that grows through three stages |
| 2 | Live or frozen | live / frozen at creation | **Live**: new entries appear while the share is valid |
| 3 | Stage 2: write-back | read-only / one-way recommendations / chat | One-way recommendations (stage 2, not here) |
| 4 | Stage 3: how much we run | booking + payment, video elsewhere / everything / directory only | Booking and payment with us, video elsewhere (stage 3, not here) |
| 5 | Where the dietitian web lives | page in the admin web app / second app in core / new repo | **New repo** `bellybuddy-connect`, address **`connect.bellybuddy.at`** |
| 6 | Privacy-policy version | bump (all users consent again once) / no bump | **Bump** |

Shown in the mockups and not objected to (Severin saw them before deciding 2–4): entry in „Ich" only; photos off by default; a
six-digit code next to the link; display name only; formal „Sie" in the web view; a portal sign-up box in the view.

## 3. Approaches

- **Link-first (picked).** The client creates a link; it opens a read-only web page. Stage 2 puts the same page behind a
  dietitian login, stage 3 adds a directory and booking. Each stage reuses the one before.
- **PDF-first.** An export inside the app. Faster for stage 1, but frozen (contradicts decision 2) and thrown away once the
  portal exists.
- **Marketplace-first.** Directory and booking before any data sharing. Gives dietitians a reason to sign up, but the app has no
  paying users to send them yet.

## 4. What exists today (found in core)

- The app has no sharing of any kind.
- Core's database still carries the Lovable-era dietitian model: role `nutritionist` in `app_role`, tables
  `nutritionist_clients`, `nutritionist_invites`, `nutritionist_client_notes`, the function `is_nutritionist_of`, and RLS policies
  that let a linked nutritionist read a client's meals, drinks, gut feelings, toilet entries, profile, recommendations and
  ingredient suggestions. The admin web has a „Nutritionists" tab. The five `nutritionist-*` functions were removed on
  2026-11-24 as unused. A separate Lovable project („Belly Buddy Connect", the nutritionist-facing app with chat) was never
  migrated.
- That model is all-or-nothing, started by an admin or by the dietitian, and the client cannot end it. It is the opposite of
  what stage 2 needs. **Stage 1 does not touch it.** Stage 2 will replace it with the share model below; what happens to the
  existing links is an open question for Severin (§9).
- Core already has a Python port of the app's Muster engine (`backend/app/domain/insights.py`, shared test vectors) and the
  FODMAP catalogue. The web view uses both, so app and view show the same patterns.
- Profiles hold no name. The view therefore needs a display name typed by the client.

## 5. Design

### 5.1 The share
A share is one grant by one client. It holds:
- **Display name** (required, 1–40 characters, prefilled with the last one used on this device).
- **Period:** the last 14 days, the last 30 days (default), or everything. The period is rolling: it is counted back from the
  moment of viewing, in the client's time zone, with the wall-clock rule the app and core already use for `tracked_at`.
- **What is shared** (each a switch, all on except photos): meals with ingredients; drinks; gut feeling and symptoms (the four
  gut symptoms and the mood fields); toilet entries; patterns and stated intolerances (Muster, diet, intolerances, symptoms from
  the profile); meal photos (off by default). At least one switch must be on. The entries' free-text notes travel with their
  category.
- **Switches that depend on each other** (Claude's call): the course, the good/medium/hard numbers and the pattern lists are
  all derived from gut-feeling entries. With gut feeling off, the view shows none of them and the create screen turns the
  patterns switch off and disables it with a one-line reason. The pattern lists also need meals on. The profile chips need only
  the patterns switch.
- **Validity:** 7, 30 (default) or 90 days from creation. No open-ended links in stage 1.
- **A share cannot be edited** (Claude's call). Period, switches, name and validity are fixed at creation; the client ends it
  and creates a new one. 90 days is the hard cap.
- **State:** active, ended by the client, expired, or locked after wrong codes. Only an active share shows data.
- **Access record:** when it was last opened and how often, shown to the client. No IP or device is kept for the client to see.

A client may have at most 5 active shares. Creating one requires the current health consent the app already asks for, and the
create screen says plainly that health data is being shared and can be withdrawn. The moment of confirmation is stored on the
share. The view also requires the owner's current health consent on every request: if the client withdraws it or has not yet
accepted a newer policy version, the view shows the neutral „nicht mehr gültig" page until they have.

### 5.2 Link and code
- Creating a share returns a link and a six-digit code, once. The server stores only hashes of both.
- The link is `https://connect.bellybuddy.at/teilen#<token>`. The token sits in the URL fragment so it never reaches the server's
  request log or a Referer; the page sends it in a request body. The token has at least 128 bits of randomness.
- The code is entered on the web page. Five wrong codes lock the share for good; the client sees „Gesperrt" and creates a new
  one. Requests are also rate-limited per address with the api's existing throttle.
- After a correct code the page gets a short-lived view session (about 15 minutes, renewed while the page is used, kept only in
  the tab). Every data request checks the share's state again, so ending a share cuts a view that is already open.
- The app keeps link and code of shares created on this device so the client can send them again later. On another device the
  list shows the share without them, with „Neu erstellen".

### 5.3 App (mockup screens 1–3)
- **Ich:** a new row „Mit Berater:in teilen", subtitle „Tagebuch für Diätolog:in oder Ärzt:in freigeben", between „Streak & Ziel"
  and „Einstellungen", with a „Neu" badge until first opened.
- **Deine Freigaben:** the list of shares, active first, each with its description („Letzte 30 Tage, ohne Fotos"), state,
  created date, last opened, and „Freigabe beenden" with a confirmation. Ended, expired and locked shares stay listed for 90
  days, then disappear. Empty state: one sentence on what sharing is for and the create button. With no share yet, the Ich row
  opens the create screen directly.
- **Freigabe einrichten:** display name, period, switches, validity, the health-data sentence, „Link erstellen".
- **After creating:** the link, „Link senden" (the system share sheet), „Kopieren", and the code in large digits with the line
  „Sag ihn deiner Berater:in getrennt vom Link." The share-sheet text contains the link and never the code.
- All text German, „du". Offline or on a server error, creating and ending fail with the app's usual error message and change
  nothing.
- Deleting the account deletes all shares.

### 5.4 Web view (mockup screens 4–5)
- A public page at `/teilen` of the new web project „Belly Buddy Connect" (`connect.bellybuddy.at`), German, formal „Sie", not
  indexed by search engines, usable from 360 px width, built for a desktop browser. It is a separate project and address
  from the admin web app on purpose: the view renders text typed by clients and must not share an origin with admin logins,
  and stages 2 and 3 grow it into its own product. The root path stays free for the stage 2 portal.
- **Code page:** what this is, the code field, „Tagebuch öffnen", and the sentence that the data belongs to the person sharing
  it. Wrong code: how many tries are left. Ended, expired, locked or unknown link: one neutral page („Diese Freigabe ist nicht
  mehr gültig. Bitten Sie Ihre Klientin oder Ihren Klienten um einen neuen Link.") that does not say which of the four it is.
- **Diary page, top to bottom:**
  1. Header: „Geteiltes Tagebuch, nur lesen", valid-until date, „Drucken / als PDF sichern" (the browser's print dialog; a print
     stylesheet gives clean pages with every day expanded).
  2. „Tagebuch von <Name>", the period, and chips for diet, stated intolerances and symptoms (only with the patterns switch).
  3. Summary numbers: days with entries, good, medium and hard days, meals logged.
  4. Course: one cell per day with a letter and a colour (G, M, S, empty), legend below. Day classes come from the Muster engine.
     The numbers in 3 and the course cover the share's period and use the engine's per-day class rule, which does not depend
     on a window. For „everything", the course shows the last 90 days and the day list pages further back.
  5. „Vor schweren Tagen häufig gegessen" and „An guten Tagen häufig gegessen", with counts („5 von 6 schweren Tagen") and the
     ingredient's FODMAP groups, plus the line that these are frequencies and no diagnosis. Shown only with the patterns switch
     and only when the engine has enough data; otherwise a sentence saying there is not enough yet.
     These two lists are the client's Muster exactly as the app shows them: the engine's fixed last 30 days, unchanged, with
     the heading saying „aus den letzten 30 Tagen" whatever the share's period is (Claude's call: no second pattern
     calculation, and the dietitian sees what the client sees). The create screen's patterns switch says the same.
  6. Entries by day, newest first, 7 days open and the rest behind „weitere Tage anzeigen". Each row: time, kind, content.
     Meals show title, ingredients with FODMAP-flagged ones marked and named, notes, and the photo if shared. Drinks show name
     and amount. Gut feeling shows the level in words, the four symptoms that are above „none" with their strength, and mood.
     Toilet entries show the Bristol type as number and word.
  7. Portal box: „Sie betreuen mehrere Klient:innen?" with an email field and „Vormerken". It stores the email and the time,
     with no link to the client or the share, and confirms on the page. The privacy policy names this. Claude's call: no
     confirmation mail in stage 1; the box states that the address is used for one message when the portal opens; entries
     are read from the database and deleted after that message or after 12 months.
- Categories the client switched off do not appear at all, not even as empty headings.
- Photos are served through short-lived signed URLs that the api issues per view session.

### 5.5 Privacy and legal
- The privacy policy (`frontend/src/pages/legal/privacyPolicy.ts` and `docs/legal` in core) gets a section on sharing: what is
  shared, that the client starts and ends it, the access record, and the portal sign-up.
- Decision 6: the policy version **is** raised, following core's rule („bump on every change of substance"). Every user
  confirms the consent screen once after the update; until then their existing shares show the „nicht mehr gültig" page
  (§5.1).
- Sentry and logs must not contain token, code, view session or diary content from these routes.

## 6. Non-goals
- Dietitian accounts, client lists, notes, recommendations, practice codes (stage 2).
- Directory, booking, payment (stage 3).
- A server-generated PDF, an export file, or sharing from the Muster screen.
- Any change to the Lovable-era nutritionist tables, policies or the admin tab.
- English.

## 7. Constraints
- Core's architecture rule: per-user CRUD through PostgREST and RLS; secrets and cross-user logic through the api. Creating a
  share and everything the anonymous view does go through the api. Listing and ending may use either, as long as the hashes are
  never readable by the client.
- The view computes patterns with core's `insights.py`, not a third implementation.
- App: design-system rules in `CLAUDE.md` (colours, font sizes, spacing from `AppTheme`/`AppConstants`), Riverpod, GoRouter,
  `AppLogger`.
- Core: `mypy --strict`, synthetic test data only, German user-facing text.

## 8. Left to the builder
- Table and column names, route names, the shape of the JSON the view loads, hashing and session-token mechanics.
- How the app stores link and code on the device.
- The exact widget structure, and whether the three app screens are routes or sheets.
- Whether the system share sheet needs a new package.
- The new repo's tooling beyond „the same stack as core's `frontend/`" (React, Vite, TypeScript, bun), and how its build
  reaches the host, as long as core's Caddy serves it and production changes are run by Severin.
- Print layout details and the colour values of the web view (take them from the mockup and the app's palette; the view has
  one light theme).
- A flag in `app_config` to hide the Ich row, if that makes the release safer.

## 9. Open for Severin (do not block stage 1)
- What the existing `nutritionist_clients` links and „Belly Buddy Connect" were used for, and whether anything there must
  survive into stage 2.
- Legal check of Claude's call above: the portal sign-up without a confirmation mail.
- Infra, by Severin (no infra access on the dev box): the DNS record for `connect.bellybuddy.at` and the first deploy of the
  new project on the production host.
- Legal check that listing only Diätolog:innen is required in Austria (stage 3), and that consultation payments may bypass the
  stores' in-app purchase (stage 3).
