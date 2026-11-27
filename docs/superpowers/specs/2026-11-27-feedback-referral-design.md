# Feedback in der App und Freund:innen einladen — Design

**Status:** direction by the controller (on Severin's behalf) 2026-11-26: an in-app form instead of an outside link, and the
smallest useful invite with no rewards. Everything else is Claude's call, labelled below. Tracks E3 and E4 of the
business-plan gap analysis.
**Repos:** app `severinkl/bellybuddyapp`, branch `feat/feedback-referral` from `feat/share-link` (it reuses stage 1's
`shareLauncherProvider`); core `severinkl/bellybuddy-core`, branch `feat/feedback-referral` from `feat/share-link` (it joins
stage 1's retention job and follows migration `0016`).

## 1. Intent

The business plan promises a feedback channel in the app and lists „Freunde einladen" as a growth channel.

**What the code does today:** the Ich row „Feedback geben" (`MeScreen.feedbackKey`, `lib/screens/me/me_screen.dart`) opens
`AppConstants.feedbackFormUrl`, a **Mailchimp survey** (`us20.list-manage.com/survey?...`) in the browser. So feedback leaves
the app, lands at a US processor the privacy policy does not name, has no category, no context, no way to reply, and Severin
reads it in Mailchimp. There is no invite feature, no analytics or product-event logging (`buddy_events_provider.dart` is the
Buddy's in-memory reaction to a log, not analytics), and no smart store link. The public site `https://bellybuddy.at` exists
but today only offers a waitlist („Auf die Warteliste"), with no store links.

**Success:** a user writes feedback in two taps without leaving the app, sees exactly what is sent along, can ask for an
answer; Severin sees it in the admin SPA, filters it by category and ticks it off. A user who likes the app can send a friend
a link from „Ich" in one tap.
**Anti-goals:** collecting health or diary data through feedback; a referral scheme with rewards, codes or tracking of who
invited whom; a new ask that competes with the rating prompt or the Buddy's other asks.

## 2. Decisions

| # | Topic | Decision | Whose | Cost if wrong |
|---|---|---|---|---|
| 1 | Feedback channel | In-app form, stored in core; the Mailchimp link and its constant go | Controller | — |
| 2 | Categories | „Idee", „Problem", „Lob", „Sonstiges" (stored `idea`, `problem`, `praise`, `other`); none preselected, one required | Claude's call | One more tap; a default would bias the counts |
| 3 | Text | 1–2,000 characters as a person sees them (trimmed); the server accepts up to 4,000 code points so a text full of emoji the app allowed is never refused | Claude's call | Same pattern as the Buddy name; low |
| 4 | „Antwort erwünscht" | Switch, off by default; the form shows the account address („Wir antworten an <E-Mail>.") and the api stores that address (from the token) with the row only when the switch is on. Without an address in the account the switch is hidden | Claude's call | A changed address later still gets the reply at the old one; fine for a one-off answer |
| 5 | Context | App version, platform, OS version, listed on the form under „Das wird mitgeschickt:"; no device model, no diary or health data | Controller + Claude (no model) | Slightly harder bug triage without the model; asking for it in the reply covers it |
| 6 | OS version source | New package `device_info_plus` (same family as `package_info_plus`): „iOS 18.1", „Android 14". `Platform.operatingSystemVersion` gives a kernel string on Android | Claude's call | One dependency |
| 7 | Write path | api route `POST /functions/v1/feedback` (not a PostgREST insert): it validates, counts the limit in the database, snapshots the e-mail from the token and returns German errors. The table has no client grants except admin read and the admin's `done_at` update | Claude's call | A route instead of a policy; the architecture rule allows it for logic beyond plain CRUD |
| 8 | Rate limit | 5 per user per rolling 24 hours, counted in the table under a per-user advisory lock (survives api restarts, unlike `Throttle`) | Claude's call | A burst user waits a day |
| 9 | Operator notice | **No e-mail.** Severin looks at the admin tab „Feedback"; the tab's nav item shows the number of open items | Claude's call | Feedback sits unread if Severin does not look; listed under Needs from Severin |
| 10 | Admin view | New tab „Feedback": list newest first, category filter, „Erledigt" checkbox per row (`done_at`), reply address only on rows that asked for an answer; admin role only (RLS) | Controller + Claude | — |
| 11 | Retention | Rows older than 24 months are deleted by the existing daily job (`share_retention.py`, schedule `share-retention`; name kept so the Sentry monitor stays) | Controller (24 months) + Claude (same job) | — |
| 12 | Account deletion | Feedback rows go with the account (FK cascade), reply address included | Claude's call | Old feedback of deleted accounts is lost; it may hold health data and an address, so deleting is the safe side |
| 13 | Invite row | „Freund:innen einladen" in „Ich", opens the system share sheet with a fixed German text and `https://bellybuddy.at` | Controller + Claude (URL) | The site still says „Warteliste": must change before release (Needs from Severin) |
| 14 | Second invite entry point | **None.** Only the Ich row. The one happy moment (back on Home after „Muster frei!") belongs to the rating prompt, and Home's hero queue already arbitrates four asks | Claude's call | Fewer invites; adding a later cue is a contained change |
| 15 | Counting shares | **Nothing counted.** The app has no product-event logging to join, and building one for a single counter is not worth a new purpose in the privacy policy | Claude's call | No number for the business plan; store console referrer stats are the substitute |
| 16 | Reward-based referral | **Not built** — see 4.4 | Claude's call | — |
| 17 | iPad anchoring | Reuse stage 1's `shareLauncherProvider`; its inline origin computation moves into a helper `shareOriginOf` used by both callers | Claude's call | — |
| 18 | Row order in „Ich" | … Tutorial wiederholen · Belly Buddy bewerten (rating track) · Feedback geben · Freund:innen einladen | Claude's call | Cosmetic |

## 3. Approaches

**Feedback.**
- **In-app form → api route → `feedback` table → admin tab (picked).** Data stays on our servers, the user sees what is sent,
  Severin has one place to look.
- *Keep the Mailchimp survey, add context to its URL.* Rejected: a US processor not in the policy, no reply path, context in
  a URL query is visible to Mailchimp and the browser history.
- *`mailto:` with prefilled context.* Rejected: needs a mail app set up (often not on Android), puts the user's address and
  text through their own provider anyway, and gives Severin no category or done flag.
- *PostgREST insert with RLS and a trigger for the limit.* Workable, but the e-mail snapshot, the limit and German errors are
  three things a trigger does worse than the 30 lines the api already has a pattern for (`shares`, `portal-interest`).

**Invite.**
- **Share sheet with text and site link, no tracking (picked).** One row, no server, no new personal data.
- *Personal invite links with attribution (`?ref=<id>`).* Rejected for now: needs a redirect service, store attribution
  (Play Install Referrer, Apple has none for this) and a privacy section — for a number nobody acts on before rewards exist.
- *A Buddy cue „Erzähl's weiter!" at a happy moment.* Rejected (decision 14).

## 4. Design

### 4.1 Feedback form (app)
Route `/me/feedback` (`RouteNames.feedback`, `RoutePaths.feedback`), pushed from the Ich row „Feedback geben" (title and
subtitle unchanged: „Teile uns deine Ideen und Wünsche mit"). Screen `FeedbackScreen`, app bar „Feedback geben".

Top to bottom:
1. „Worum geht es?" — four choices „Idee", „Problem", „Lob", „Sonstiges", the same segmented-choice style as „Zeitraum" in
   `share_create_screen.dart`; none selected at first.
2. Text field, label „Deine Nachricht", hint „Was ist dir aufgefallen, was wünschst du dir?", multi-line, counter
   `n / 2000` (`AppConstants.feedbackMaxLength = 2000`, counted as characters a person sees).
3. Warning line (muted, info icon): „Bitte schreib hier keine Gesundheitsdaten hinein, die du nicht teilen möchtest."
4. Switch „Antwort erwünscht", subtitle „Wir antworten an <address>." Hidden when the signed-in user has no e-mail.
5. „Das wird mitgeschickt:" with two lines „App-Version <version>" and „System: <iOS 18.1 | Android 14>", then
   „Keine Tagebuch- oder Gesundheitsdaten." While the context is still loading the lines show „…"; if it cannot be read the
   value is „unbekannt" (and the server gets `unbekannt`).
6. Primary button „Senden", disabled until a category is chosen and the trimmed text is not empty; while sending it shows the
   usual progress state and the form is locked.

Outcomes:
- **Sent:** the screen pops back to „Ich" and shows the SnackBar „Danke! Dein Feedback ist angekommen."
- **429:** the server's message stays on the form („Du hast heute schon 5-mal Feedback geschickt. Morgen geht's wieder."),
  the text is kept.
- **Other 4xx with a message:** that message, text kept. **Anything else:** „Das hat nicht geklappt. Versuch es später
  nochmal." (stage 1's wording), text kept.
- **Back with unsaved text:** the app's usual leave dialog is not needed; the text is simply dropped (Claude's call: it is
  feedback, not a diary entry). Nothing is stored on the device.

Logging: `AppLogger` lines carry the status code and an outcome word only; never the text, category or address.

### 4.2 Core
**Migration `0017_feedback`** (renumber if another track lands first):

```
public.feedback
  id            uuid pk default gen_random_uuid()
  user_id       uuid not null references auth.users(id) on delete cascade
  category      text not null check (category in ('idea','problem','praise','other'))
  message       text not null check (char_length(message) between 1 and 4000 and message ~ '\S')
  reply_email   text null check (reply_email is null or char_length(reply_email) between 3 and 254)
  app_version   text not null check (char_length(app_version) between 1 and 32)
  platform      text not null check (platform in ('ios','android'))
  os_version    text not null check (char_length(os_version) between 1 and 64)
  created_at    timestamptz not null default now()
  done_at       timestamptz null
  index (user_id, created_at desc); index (created_at desc)
```
RLS on; `revoke all … from anon, authenticated`; `grant select, update (done_at) on public.feedback to authenticated`;
policies „Admins can view feedback" (select, `has_role(auth.uid(),'admin')`) and „Admins can mark feedback done" (update,
same check in `using` and `with check`). No client insert, no user read (not even their own).

**Route `feedback`** (`backend/app/routes/feedback.py`, auto-registered as `/functions/v1/feedback`), `POST ""`, authenticated:
- Body `{"category": "idea"|"problem"|"praise"|"other", "message": str, "reply_wanted": bool, "app_version": str,
  "platform": "ios"|"android", "os_version": str}` → `200 {"ok": true}`.
- 400 `INVALID_CATEGORY` „Bitte wähle aus, worum es geht.", `INVALID_MESSAGE` „Deine Nachricht muss 1 bis 2000 Zeichen
  lang sein.", `INVALID_CONTEXT` „Die Anfrage ist ungültig." (version, platform, OS or `reply_wanted` wrong; text not clean
  per `is_clean_text`), `NO_EMAIL` „Für eine Antwort braucht dein Konto eine E-Mail-Adresse." (`reply_wanted` without
  `user.email`).
- 429 `TOO_MANY` (text in 4.1) when the user already has 5 rows with `created_at > now() - interval '24 hours'`, with
  `Retry-After` = seconds until the oldest of those is 24 hours old. Count and insert run in one transaction under
  `pg_advisory_xact_lock(7_160_003, hashtext(user_id))`.
- The message is trimmed, stored as typed otherwise. `reply_email` = `user.email` when `reply_wanted`, else null.
- Logs: „feedback stored" / „feedback refused: <reason word>" — never message, address or category.

**Retention:** `share_retention.py` gains `DELETE_FEEDBACK_SQL = "delete from public.feedback where created_at < now() -
interval '24 months'"`, `ShareRetentionRun.feedback_deleted: int`, and the log line names all three counts.

**Admin tab** (`frontend/src/pages/admin/FeedbackTab.tsx`, route `/admin/feedback`, nav item „Feedback", lucide
`MessageCircle`):
- `useAdminListQuery<FeedbackRow>({table: 'feedback', perPage: 50, filterColumn: 'category', filter, orderBy:
  'created_at', orderAscending: false, errorMessage: 'Fehler beim Laden des Feedbacks'})`.
- Filter select: „Alle", „Idee", „Problem", „Lob", „Sonstiges".
- Each row: date (`fmtDate`), category badge (German label), message (`whitespace-pre-wrap`, rendered as text), „Antwort
  an: <mailto link>" only when `reply_email` is set, „<platform> <os_version> · App <app_version>", checkbox „Erledigt"
  (sets `done_at` to now / null through PostgREST; on error a toast „Konnte nicht gespeichert werden." and the box flips
  back). Done rows are muted.
- Nav item label „Feedback (<n>)" while `n` = open rows (`done_at is null`, head count) > 0, refreshed when the tab marks
  a row.
- The user id is not shown.

### 4.3 Invite row (app)
- Ich row „Freund:innen einladen", subtitle „Erzähl anderen von Belly Buddy", icon `Icons.share_outlined`,
  `MeScreen.inviteKey`, last row (after „Feedback geben").
- Tap → `shareLauncherProvider` with `AppConstants.inviteShareText` and the row's screen rect (`shareOriginOf`).
- Text (`AppConstants.inviteShareText`, built from `AppConstants.inviteUrl = 'https://bellybuddy.at'`):
  „Schau dir mal Belly Buddy an: Damit schreibst du auf, was du isst und wie es deinem Bauch geht, und ein kleiner Buddy
  begleitet dich dabei. https://bellybuddy.at"
  (Claude's call: it describes the app, not the sender's condition, so forwarding it reveals nothing about their health.)
- Launcher throws → SnackBar „Das Teilen hat nicht geklappt." and an `AppLogger` error line without the text.
- No counter, no prefs flag, no badge.

`lib/utils/share_origin.dart`: `Rect shareOriginOf(BuildContext? context)` — the render box's global rect, `Rect.zero`
without one; `share_created_sheet.dart` switches to it (behaviour unchanged).

### 4.4 Reward-based referral: not built, and why (Claude's call)
A reward („Lade eine Freundin ein, ihr bekommt beide einen Monat Premium") needs things that do not exist yet: a
subscription to credit, a server-side ledger of invites and redemptions, attribution that survives the store install
(Play Install Referrer works, iOS has no install referrer — it needs offer codes or a sign-up code field), fraud handling
(self-invites with second accounts, which a health app with free sign-up cannot stop cheaply), and a check against both
stores' rules on incentivised installs and reviews. It also makes the invited person's address or device a thing we
process. **Later, after the subscription exists:** per-user referral codes redeemed at sign-up, store offer codes / Play
promo codes as the reward, a ledger table with limits per user, a privacy section, and an attribution count. This design's
row and text stay; only the link gains a code.

## 5. Privacy policy text (German, for the shared final „policy text" task; no version bump here)

**Abschnitt 2, neuer Listenpunkt:**
„**Wenn du uns Feedback schickst:** die gewählte Kategorie, deinen Text, App-Version, Betriebssystem und dessen Version,
den Zeitpunkt sowie – nur wenn du „Antwort erwünscht" einschaltest – die E-Mail-Adresse deines Kontos. Bitte schreib keine
Gesundheitsdaten in dein Feedback, die du nicht teilen möchtest; tust du es doch, verarbeiten wir sie nur, um dein Feedback
zu lesen und zu beantworten."

**Abschnitt 3, neue Tabellenzeile:**
„Feedback aus der App lesen, beantworten und die App verbessern" | „Art. 6 Abs. 1 lit. f DSGVO (berechtigtes Interesse an
einer besseren App); Gesundheitsangaben, die du selbst hineinschreibst, auf Grundlage deiner Einwilligung nach Art. 9 Abs. 2
lit. a DSGVO"

**Abschnitt 7, neuer Listenpunkt:**
„**Feedback:** speichern wir **24 Monate** und löschen es danach automatisch. Löschst du dein Konto, wird dein Feedback
sofort mitgelöscht. Nur Administrator:innen von Belly Buddy können es lesen."

**Abschnitt 7, Punkt „Konto- und Tagebuchdaten":** in der Aufzählung der gelöschten Daten „… Empfehlungen, Feedback und
E-Mail-Protokolle …" ergänzen.

The invite row adds no text: we process nothing about the friend, and the share sheet is the operating system's.

## 6. Non-goals
- No e-mail or push to the operator; no reply from inside the admin SPA (Severin answers from his mail client).
- No list of a user's own past feedback in the app.
- No screenshots or attachments.
- No referral rewards, codes, attribution, counters or analytics.
- No invite cue on Home or after celebrations.
- No change to the rating track's row or logic.

## 7. Left to the builder
- Widget split inside `FeedbackScreen` (one file is fine) and whether the form state is local `State` or a small notifier,
  as long as the submit goes through `FeedbackService` and is tested without widgets.
- Exact device-info calls (`IosDeviceInfo.systemVersion`, `AndroidDeviceInfo.version.release`), behind a provider tests
  can replace.
- Admin row layout (card or table), as long as 4.2's fields and controls are there.

## 8. Needs from Severin
- **bellybuddy.at** must point visitors to the stores (badges for App Store and Google Play, AT/DE/CH) instead of the
  waitlist before the app release that carries the invite row — or name a better URL; it is one constant.
- A **smart store link** (one URL that opens the right store) is optional later; the site with both badges covers it.
- **Legal check** of the Art. 9 wording for health data users type into feedback (section 5).
- **Look at the admin tab „Feedback"** regularly; nothing notifies you.
- The **Mailchimp survey** can be closed once this ships; its existing answers are outside this design (export or delete
  them in Mailchimp; the current policy does not name Mailchimp).
- Apple „Hide My Email" addresses only forward mail from domains registered for Sign in with Apple: reply from an address
  on such a domain (as the auth mails do), or the reply bounces.

## 9. Manual checks for Severin (device-only)
- iPad: „Freund:innen einladen" opens the share popover anchored at the row (not at the corner, not a crash).
- iPhone and Android: the share sheet shows the text with a tappable link in Messages/WhatsApp.
- The form's context shows real values („iOS 18.x", „Android 1x") on a device.
- Send one feedback with „Antwort erwünscht" from a TestFlight build and find it, with the address, in the admin tab.
