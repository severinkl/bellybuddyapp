# Akuthilfe („Ruhe für den Bauch") — Design

**Status:** two decisions by Severin 2026-11-26 (text exercises with a timer, no audio or video; Claude drafts, Susi reviews
every text before release); the rest is Claude's call, labelled. Tracks D1/D2 of the business-plan gap analysis.
**Repo:** app `severinkl/bellybuddyapp`, branch `feat/akuthilfe` from `develop` @ 22a9a2b. **No core change** (see 2.3).

## 1. Intent

The business plan promises „Akuthilfe": quick, calming help in the moment the belly hurts, in the Buddy's warm voice.
Nothing of it exists. This adds six short guided exercises (breathing, relaxing, a gentle belly massage, warmth, calming
thoughts) as text with a step timer, reachable in one tap after a hard Bauchgefühl entry and always from „Entdecken".

**Success:** someone in discomfort reaches an exercise in at most two taps, can follow it with eyes half closed (pacer,
vibration, one short sentence per step), and always sees where real help is when it is more than ordinary discomfort.
**Anti-goals:** anything that reads as treatment, diagnosis or triage; nagging after every bad entry; a paywall in front of
it; anything reaching users before Susi has reviewed the texts.

## 2. Decisions

| # | Topic | Decision | By |
|---|---|---|---|
| 1 | Format | Text steps with a timer; no audio, no video | Severin |
| 2 | Texts | Claude drafts (section 5); Susi reviews every text before release; each exercise carries `reviewed: false` | Severin |
| 3 | Remote switch | `app_config` key `akuthilfe_enabled`; only `'true'` is on; missing → off. **And** the feature stays off until every exercise is `reviewed: true` in the code | Claude's call — wrong: flipping the switch alone would ship unreviewed text; the extra guard costs one commit after Susi's review |
| 4 | Core | No migration: a missing key already means off; switching on is one `insert … on conflict` by Severin | Claude's call — wrong: the key is not visible in the table until Severin adds it; avoids a migration-number race with the other tracks |
| 5 | User-facing name | „Ruhe für den Bauch" (screen and card title); „Akuthilfe" stays the code/plan name | Claude's call — wrong: „Hilfe" next to „keine medizinische Hilfe" would contradict itself; one string to change |
| 6 | Entry after a Bauchgefühl entry | One quiet pill on the success page, only when a symptom is 4 or 5 and the entry's time is within the last 2 hours | Claude's call (direction from the brief) — wrong: a back-dated entry would offer help for yesterday's pain |
| 7 | Entdecken | One compact card at the **top** of Entdecken, above Tipps | Claude's call — wrong: Tipps moves down by one card height; when it hurts, scrolling is the wrong cost |
| 8 | Home | No new Home element | Claude's call (brief's default) — Home is full |
| 9 | Box breathing vs 4-7-8 | Box breathing (4-4-4-4) | Claude's call — 4-7-8's 7-second hold and 8-second exhale are harder when tense and more likely to cause dizziness |
| 10 | Storage | Nothing on the server. Per user and device in shared preferences: the last „Hat's geholfen?" answer per exercise | Claude's call — wrong: no cross-device history; but no health-behaviour data leaves the phone and no policy change is needed |
| 11 | What the answer does | Exercises answered „Ja" move to the top with a quiet „Hat dir geholfen" label; „Nein" moves to the bottom | Claude's call |
| 12 | Screen awake | Yes while an exercise runs, via new package `wakelock_plus`; not during the quiet warmth timer | Claude's call — `wakelock_plus` is the maintained Flutter wake-lock plugin; nothing in `pubspec.yaml` does it today |
| 13 | Haptics | A light tick at each breath phase change and each step change, also under „Bewegung reduzieren" | Claude's call — vibration is not motion and is the one signal that works with closed eyes |
| 14 | Background | Leaving the app pauses the exercise, except the quiet warmth timer, which keeps counting by wall clock | Claude's call |
| 15 | Paywall | Free, always: no `/relief` route or entry is ever gated by `paywall_enabled` | Claude's call (brief) |
| 16 | Review marker | Debug builds and builds with `--dart-define=RELIEF_PREVIEW=true` show the feature regardless of the switch and mark unreviewed exercises „Entwurf: noch nicht fachlich geprüft" | Claude's call — the app has no staging flavour; release CI never passes the define |
| 17 | Safety sheet on first open | Not forced; the safety line is on every screen, the cautions sit before the start of massage and warmth | Claude's call — wrong: one more flag to force it once |

### 2.1 What the code says
- `AppConfig` (`lib/models/app_config.dart`) holds only the two version strings; `AppConfigRepository.fetch()` reads
  `minimum_supported_version` and `latest_version` and throws if either is missing. The subscription track adds
  `paywallEnabled` to the same two files: **the two branches conflict there**; both add one bool and one key, merge by hand.
- The Bauchgefühl success page is `BbSuccessOverlay` with `LogSuccessHero` and `calm: hardDay`. It already supports
  `actions` (rendered as pills that absorb the tap-to-dismiss), so the offer needs no new overlay.
- Entdecken (`DiscoverScreen`) is a column of sections: Tipps (optional), Alternativen, Rezepte, Wissen.
- `BuddySays(mood: BuddyMood.zen, line:, height:)` already shows a calm Buddy with a line (used by recipe adapting).
- The Android manifest's `<queries>` has only `PROCESS_TEXT`; `tel:` links need a `DIAL` query entry.
- Nothing in `lib/` uses „Therapie", „Behandlung", „heilt" or „Diagnose", so these can join the vocabulary test's ban list.

### 2.2 Massage direction (for Susi)
„Im Uhrzeigersinn" is meant as seen by someone facing you; seen from yourself looking down it is the other way round. The
text therefore never relies on the word: it describes the path (start low on the right, up, across, down on the left),
which follows the colon. Susi please confirm the wording.

### 2.3 Switching on
`insert into public.app_config (key, value) values ('akuthilfe_enabled', 'true') on conflict (key) do update set value =
excluded.value;` — after a release whose content has every exercise `reviewed: true`. Off again: set it to `'false'`;
takes effect at the next app start.

### 2.4 Teaser until reviewed (decision 2026-11-27)
Until Susi has reviewed the texts, the app already shows the feature as coming soon. While the gate (4.1, unchanged) is
off, Entdecken shows `DiscoverReliefCard.teaser()` in the card's place: zen Buddy, „Ruhe für den Bauch", „Kleine Übungen
für Momente, in denen der Bauch drückt." and the pill „Kommt bald" instead of the chevron. Not tappable, opens nothing,
one screen-reader item (title, line, „Kommt bald"), no button role. The routes stay guarded, so no exercise text is
reachable. The offer after a Bauchgefühl entry stays absent while off: a „Kommt bald" right after a hard moment would
promise help that isn't there.

## 3. Approaches

- **Bundled text exercises with a step player (picked).** Works offline, one content file for Susi, no processor, no audio
  production.
- **Content from core (a `relief_exercises` table).** Rejected: Susi's edits would be data migrations, the feature would
  need the network exactly when someone feels bad, and the review flag would live in a database.
- **Store sessions on the server (`relief_sessions`).** Rejected: health-related behaviour data with RLS, a policy section
  and an export/delete path, for a benefit (order by what helped) that a local preference gives as well.

## 4. Design

### 4.1 Gate
`reliefEnabledProvider` (bool) = preview **or** (`appConfig.akuthilfeEnabled` **and** every exercise `reviewed`). A failed
or pending config fetch → off. Preview = `kDebugMode || bool.fromEnvironment('RELIEF_PREVIEW')`, behind its own provider so
tests set it. When the remote switch is on but content is unreviewed, log one warning (`AppLogger`), stay off. The routes
`/relief` and `/relief/:id` redirect to `/discover` while off, so a stale link never shows it.

### 4.2 Entry points
- **After a Bauchgefühl entry:** `offersRelief(entry, now)` is true iff any of `bloating`, `gas`, `cramps`, `fullness` is
  ≥ 4 **and** `trackedAt` is not earlier than `now − 2 h` and not later than `now + 5 min` (plain local wall-clock
  `DateTime`s, never `toLocal()`), **and** the gate is on. Then the success page gets one action pill:
  „Brauchst du gerade etwas Ruhe für deinen Bauch?". Tap → `pushReplacement('/relief')` (back returns to where the user
  logged from). Tapping anywhere else dismisses as today. No other change to the success page.
- **Entdecken:** while the gate is on (off: its teaser, 2.4), the first child is `DiscoverReliefCard`: zen Buddy icon, title „Ruhe für den Bauch",
  subtitle „Atmen, entspannen, Wärme – für den Moment", chevron; whole card one tap target → `/relief`.
- **Home:** nothing.

### 4.3 List screen `/relief`
App bar „Ruhe für den Bauch". Top: `BuddySays` zen, „Ich bin da. Such dir aus, was dir gerade guttut." Then one card per
exercise in the order of 4.6: title, subtitle, duration („3 Min."), label „Hat dir geholfen" when the last answer was
„Ja"; in preview the „Entwurf" marker. Below the scroll area, **fixed** (outside the scroll view, always visible): the
safety line (4.5).

### 4.4 Player `/relief/:id`
- **Ready:** title, duration, the exercise's caution (if any) in a soft box, button „Starten". Unknown id → redirect to
  `/relief`.
- **Running:** „Schritt 2 von 4", a total progress bar (seconds done / total), the step text (large, `fontSizeTitleLG`),
  the step's remaining time („0:45"). Breathing steps add the pacer: a circle that grows over the inhale, stays during
  holds, shrinks over the exhale, with the phase word („Einatmen", „Halten", „Ausatmen") and its countdown („3") in the
  middle. Under „Bewegung reduzieren" (`MediaQuery.disableAnimationsOf`) the circle stays still; the word and countdown
  carry it alone. Steps advance by themselves when their time is up.
- **Controls** (bottom, each ≥ `AppConstants.minTapTarget`): „Zurück" (previous step from its start; on step 1 restarts
  it), „Pause" / „Fortsetzen", „Weiter" (next step; on the last step finishes). Close (X) in the app bar leaves at once,
  no confirmation, nothing stored.
- **Quiet step** (warmth's 10 minutes): no pacer, the remaining time large; the screen may lock; leaving the app does not
  pause it (it is computed from wall-clock time when the user returns).
- **Leaving the app** during any other step pauses it; coming back shows „Fortsetzen".
- **Done:** `BuddySays` zen „Schön, dass du dir die Zeit genommen hast.", then „Hat's geholfen?" with three buttons „Ja",
  „Ein bisschen", „Nein" and a text button „Fertig". An answer is stored (4.6) and replaced by a thank-you line:
  Ja/Ein bisschen → „Danke! Ich merk mir das."; Nein → „Danke, dass du es mir sagst. Probier gern eine andere Übung – und
  hol dir Hilfe, wenn es nicht besser wird." plus a link „Wann du Hilfe holen solltest" (opens 4.5's sheet). „Fertig" (or
  back) returns to the list. Answering is optional; leaving without an answer stores nothing.
- **Screen awake:** on while running a non-quiet step; off on pause, quiet step, done, close and dispose.
- **Accessibility:** at each step change one screen-reader announcement with the step text; in breathing steps one
  announcement per phase word only (never the countdown); the countdown digits are excluded from semantics, the phase
  container has the label „Einatmen, noch 3 Sekunden" on focus. All text scales; at 200 % the step text scrolls, the
  controls stay pinned.
- **Haptics:** `HapticService.selection()` per phase change, `HapticService.light()` per step change, only while running.
- The safety line is fixed at the bottom of ready and done (not over the running step, where it would distract; the
  running view has an info icon in the app bar that opens the sheet).

### 4.5 Safety frame
**Line** (list, ready, done): „Das ersetzt keine ärztliche Hilfe. Bei starken Beschwerden: Notruf 144 (AT, CH) oder 112."
with an info icon; tapping the line opens the sheet.

**Sheet „Wann du Hilfe holen solltest":**

> Die Übungen hier können dir helfen, ruhiger zu werden. Sie ersetzen keine ärztliche Hilfe und sagen nichts darüber,
> woher deine Beschwerden kommen.
>
> **Ruf sofort den Notruf, wenn du**
> - sehr starke oder plötzliche Bauchschmerzen hast,
> - Schmerzen in der Brust oder Atemnot hast,
> - Blut erbrichst oder viel Blut im Stuhl ist.
>
> **Geh bald zur Ärztin oder zum Arzt, wenn**
> - die Schmerzen neu, ungewohnt oder nicht besser werden,
> - du Blut im Stuhl bemerkst,
> - du Fieber hast,
> - du dich immer wieder übergeben musst,
> - du ungewollt abnimmst.
>
> **Notruf:** 144 Rettung (Österreich, Schweiz) · 112 (Deutschland und ganz Europa)
> **Ärztlicher Rat, wenn es kein Notfall ist:** 1450 (Österreich) · 116 117 (Deutschland) · in der Schweiz deine
> Hausarztpraxis oder der ärztliche Notfalldienst deines Kantons

Each number is a button that opens the dialer (`tel:144`, `tel:112`, `tel:1450`, `tel:116117`); if the dialer cannot open,
the snackbar „Wähl bitte direkt {Nummer}." No symptom input, no branching, no triage logic: the sheet is static text.

### 4.6 Feedback, stored on the device
Shared preferences key `relief_feedback_<userId>`: a JSON object `{"<exerciseId>": "yes" | "little" | "no"}`, last answer
only. Order of the list: „yes" first, then „little" and unanswered (content order), then „no"; stable within each group.
Signed out or no user → content order, nothing stored. Corrupt JSON → treated as empty, logged once.

### 4.7 Free
Always free, also when `paywall_enabled` is on: not in the subscription track's list of paid surfaces, no Plus check.

### 4.8 Content file
All exercise texts **and** every user-facing string of the feature (safety line, sheet, list, player, done) live in one
file, `lib/services/relief/relief_content.dart`, so Susi's edits are one-file changes. Each exercise has
`reviewed: false` until her sign-off.

## 5. The exercises (drafts for Susi; every text `reviewed: false`)

Voice: the Buddy, „du", calm, short sentences, nothing promised („kann helfen", „vielen tut … gut"). Seconds per step in
brackets; „Atem 4/0/6/0" = inhale/hold/exhale/hold.

### 5.1 `bauchatmung` — „Bauchatmung" · „Ruhig in den Bauch atmen" · 3 Min.
Caution: „Wenn dir schwindlig wird, atme einfach wieder ganz normal."
1. (20) „Mach es dir bequem. Du kannst sitzen oder liegen. Leg eine Hand auf deinen Bauch."
2. (20) „Atme ganz normal weiter. Spür, wie sich deine Hand mit dem Atem hebt und senkt. Du musst nichts ändern."
3. (120, Atem 4/0/6/0) „Atme langsam durch die Nase ein, bis sich dein Bauch hebt. Atme durch den Mund etwas länger
   wieder aus. Vielen tut dieser lange Ausatem gut."
4. (20) „Lass den Atem wieder von allein fließen. Bleib noch einen Moment so, wie du bist."

### 5.2 `box_atmung` — „Box-Atmung" · „Vier Seiten, je vier Sekunden" · 3 Min.
Caution: „Hör auf, wenn dir schwindlig wird. Halte die Luft nie mit Druck an."
1. (20) „Setz dich bequem und aufrecht hin. Deine Schultern dürfen locker sein."
2. (15) „Stell dir ein Quadrat vor. Jede Seite dauert vier Sekunden: einatmen, halten, ausatmen, halten."
3. (128, Atem 4/4/4/4) „Folg einfach dem Kreis. Ein durch die Nase, aus durch den Mund. Ist das Halten unangenehm, lass es
   weg und atme nur ruhig."
4. (17) „Lass das Quadrat los und atme in deinem eigenen Tempo. Gut gemacht."

### 5.3 `muskelentspannung` — „Muskeln entspannen" · „Kurze Progressive Muskelentspannung" · 4 Min.
Caution: „Spann nur so fest an, dass es angenehm bleibt – nie so, dass es weh tut. Deinen Bauch lässt du heute locker."
1. (20) „Setz oder leg dich bequem hin. Wir spannen nacheinander ein paar Muskeln kurz an und lassen sie wieder los. Dein
   Bauch darf dabei ganz in Ruhe bleiben."
2. (7) „Mach mit beiden Händen eine feste Faust. Halte die Spannung."
3. (25) „Und loslassen. Spür, wie deine Hände weich und warm werden."
4. (7) „Winkle die Arme an und spann die Oberarme an. Halten."
5. (25) „Lass los. Deine Arme dürfen schwer werden."
6. (7) „Zieh die Schultern hoch zu den Ohren. Halten."
7. (25) „Lass sie sinken. Spür, wie viel Platz dein Nacken jetzt hat."
8. (7) „Kneif die Augen zusammen und runzle die Stirn. Halten."
9. (25) „Lass dein Gesicht ganz weich werden. Auch der Kiefer darf locker sein."
10. (7) „Zieh die Zehen zu dir hin und spann die Beine an. Halten."
11. (25) „Lass los. Deine Beine liegen schwer und ruhig."
12. (40) „Atme ein paar Mal ruhig durch. Spür deinen ganzen Körper: Hände, Arme, Schultern, Gesicht, Beine. Alles darf
    schwer und warm sein."

### 5.4 `bauchmassage` — „Sanfte Bauchmassage" · „Im Uhrzeigersinn, ganz ohne Druck" · 4 Min.
Caution: „Bitte nicht bei starken oder neuen Schmerzen, nach einer Operation am Bauch und in der Schwangerschaft nur nach
ärztlichem Rat. Wenn es weh tut, hör auf."
1. (20) „Leg dich auf den Rücken und stell die Beine an. Ein Kissen unter den Knien kann angenehm sein."
2. (20) „Reib deine Hände aneinander, bis sie warm sind. Leg sie dann flach auf deinen Bauch."
3. (30) „Atme ein paar Mal ruhig in deine Hände. Du musst noch nichts tun."
4. (90) „Beginn unten rechts an deinem Bauch, nah am Hüftknochen. Streich mit der flachen Hand langsam hinauf bis unter
   die Rippen, quer hinüber zur linken Seite und links wieder hinunter. Ganz sanft, wieder und wieder."
5. (60) „Mach die Kreise so groß oder klein, wie es sich gut anfühlt. Ist eine Stelle empfindlich, lass sie aus."
6. (20) „Lass deine Hände zum Schluss ruhig auf dem Bauch liegen und spür nach."

### 5.5 `waerme` — „Wärme" · „Wärmflasche oder Kirschkernkissen" · 12 Min.
Caution: „Nur warm, nie heiß: kein kochendes Wasser, immer ein Tuch zwischen Haut und Wärme. Schlaf nicht mit der
Wärmflasche ein. Nicht bei Fieber und nicht an Stellen, an denen du wenig spürst."
1. (30) „Füll deine Wärmflasche mit warmem, nicht kochendem Wasser, etwa zu zwei Dritteln. Drück die Luft heraus und
   schraub sie gut zu."
2. (20) „Wickle sie in ein Handtuch oder steck sie in ihren Bezug. Ein warmes Kirschkernkissen geht genauso."
3. (20) „Leg dich bequem hin und leg die Wärme auf deinen Bauch. Prüf kurz: Fühlt es sich angenehm warm an?"
4. (600, quiet) „Jetzt darfst du einfach liegen. Du kannst das Handy weglegen – ich passe auf die Zeit auf."
5. (20) „Nimm die Wärme wieder weg und schau kurz auf deine Haut. Ist sie stark gerötet, nimm beim nächsten Mal ein
   dickeres Tuch."

### 5.6 `gedanken` — „Gedanken beruhigen" · „5-4-3-2-1: im Moment ankommen" · 3 Min.
1. (20) „Wenn der Bauch weh tut, kreisen oft auch die Gedanken. Wir holen dich jetzt ein Stück ins Hier und Jetzt."
2. (35) „Schau dich um. Nenn in Gedanken fünf Dinge, die du sehen kannst."
3. (35) „Spür vier Dinge, die du gerade berührst: den Boden, den Stoff deiner Kleidung, deine Hände …"
4. (30) „Hör hin. Welche drei Geräusche kannst du hören?"
5. (25) „Welche zwei Dinge kannst du riechen? Fällt dir nichts ein, denk an zwei Gerüche, die du magst."
6. (20) „Und eine Sache, die du schmecken kannst – oder nimm einen Schluck Wasser."
7. (15) „Atme einmal lange aus. Du bist hier. Und du hast gerade gut für dich gesorgt."

Durations: 180, 180, 220, 240, 690, 180 seconds. Warmth is longer than the others by design (its 10-minute timer).

## 6. Privacy policy text
None. Nothing leaves the device; the feedback is a local preference per user and device. (If Severin prefers to mention it:
„Wenn du nach einer Übung unter ‚Ruhe für den Bauch' angibst, ob sie dir geholfen hat, speichern wir das nur auf deinem
Gerät, um die Übungen für dich zu sortieren. Es wird nicht an uns übertragen.")

## 7. Non-goals
- No audio, video, music or voice; no notifications or reminders for exercises.
- No symptom checker, no triage, no logic that depends on what hurts.
- No server data, no analytics event.
- No Home element; no entry from Klo entries (could follow later with the same `offersRelief` idea).
- No paywall.

## 8. Left to the builder
- Pacer drawing (a `CustomPaint` or an `AnimatedContainer` in a circle), colours from `AppTheme` (`primarySoft` fill,
  `primary` ring), as long as 4.4's rules hold.
- The exact screen-reader announcement API of the pinned Flutter (no deprecated call; analyzer must stay clean).
- `wakelock_plus` version: `flutter pub add wakelock_plus` (current major).

## 9. Needs from Severin
- **Susi reviews all texts before release:** section 5 and 4.5 (also in `lib/services/relief/relief_content.dart`); her
  sign-off sets `reviewed: true` per exercise in one commit. Especially: the massage direction wording (2.2), the warmth
  safety note, and the two-group list in the safety sheet (is the split „sofort Notruf / bald zur Ärztin" right?).
- The emergency and advice numbers for AT/DE/CH (144, 112, 1450, 116 117, the Swiss wording) — confirm.
- Switch-on on prod after a release with reviewed content: the SQL in 2.3 (a prod write; not part of the plan).
- Whether you want the optional privacy sentence of section 6.

## 10. Manual checks for Severin (device-only)
- The screen stays on during Bauchatmung for 3 minutes; it may lock during warmth's quiet step, and on return the timer
  shows the right remaining time.
- Leaving the app mid-Bauchatmung pauses it; „Fortsetzen" continues.
- Reduce motion on (iOS „Bewegung reduzieren", Android „Animationen entfernen"): the circle stays still, word and countdown
  run.
- VoiceOver and TalkBack: one announcement per step and per phase word, no countdown chatter.
- The vibration ticks feel gentle, not alarming.
- 144 / 112 / 1450 / 116 117 open the dialer on iPhone and Android.
- Text size at maximum: list, player and done screens remain usable; the gut-feeling success page with the pill still fits.
- `RELIEF_PREVIEW` build (debug): „Entwurf" markers visible; a release build without the define and with the switch off
  shows no trace of the feature.
