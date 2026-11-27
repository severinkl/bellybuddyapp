# Barcode-Scan und Produktsuche — Design

**Status:** Severin decided the data source (Open Food Facts with its licence's attribution, no paid database, 2026-11-26);
everything else is Claude's call under the delegated autonomous run of 2026-11-26/27, labelled below.
Tracks A1 (Barcode-Scanner) and A2 (Produktsuche) of the business-plan gap analysis.
**Repos:** core `bellybuddy-core` and app `bellybuddyapp`, branch `feat/barcode` in each, from `develop`. Independent of
stage 1 (share link) and of the portal; shares one package (`mobile_scanner`) with the portal plan.

## 1. Intent

The business plan promises „Barcode-Scanner" and „Produktsuche" for packaged food. Today a meal is logged by photo
(core `analyze-meal`: Claude reads the photo, names are matched to the `ingredients` catalogue, new names get FODMAP flags
and become shared rows) or by typing names (each one `ensure_ingredient`). A packaged product has its ingredient list
printed on it; typing it is tedious and the photo AI cannot read it. This adds: scan the barcode, or search the product by
name, and the meal tracker is filled with the product's name and its ingredients, recognised the same way as a photo's.

**Success:** a user holds a yoghurt's barcode to the camera, sees „Joghurt Natur · Testmarke" with its ingredients as
chips, taps „Übernehmen", and saves a meal that looks like every other meal (title, ingredient chips, FODMAP flags and
„Alternativen" work as usual). A product that Open Food Facts does not know ends in one tap at typing it in.
**Anti-goals:** a nutrition-facts feature (calories, Nutri-Score); storing which user scanned which product beyond the
meal they save; the user's IP address or account reaching a third party; junk names („Säuerungsmittel: Citronensäure
2,5 %") entering the shared ingredient catalogue.

## 2. Decisions

| # | Topic | Decision | Whose |
|---|---|---|---|
| 1 | Data source | Open Food Facts (OFF), attribution per ODbL; no paid database | Severin |
| 2 | Where OFF is called | Only from core: one route `product-lookup` (`barcode` or `q`). The app never talks to OFF | Claude (brief); wrong: none, it is the privacy basis |
| 3 | Entry point | One full-width button „Barcode scannen oder suchen" in the meal tracker, between the photo area and the ingredients, in create and edit mode | Claude; wrong: one widget moved |
| 4 | Drink tracker | **No scan in v1.** A drink there is one catalogue `Drink` (FODMAP flags, no ingredients) plus an amount; a scanned product would become an unflagged user drink named after the product, which helps nobody. A drink with ingredients (Haferdrink) can be scanned in the meal tracker | Claude; wrong: one more entry point later, the route already serves it |
| 5 | Confirm step | The sheet shows the product (name, brand, recognised ingredients as chips, attribution) with „Übernehmen"; the **meal tracker itself** is the edit step (its existing chip list removes and adds ingredients) before „Speichern" | Claude; wrong: a second ingredient editor in the sheet |
| 6 | Applying to a filled tracker | The product's ingredients are **added** to those already there (no duplicates, case-insensitive); the title becomes the product name only while it is still the default „Neue Mahlzeit". So Müsli + Milch = two scans | Claude; wrong: replace instead of merge, one method |
| 7 | Title | Product name only (German name preferred); the brand is shown in the sheet, not stored | Claude; wrong: titles less specific |
| 8 | Image | **None.** No OFF image is stored or shown (shown would send the user's IP to OFF's image server; stored would add CC BY-SA and storage questions) | Claude (brief default) |
| 9 | Ingredient recognition | One AI pass **per product** (not per user), cached: OFF's ingredients text → the app's ingredient names, with the photo analysis's naming rules and the same catalogue preference; then the photo analysis's own catalogue match and new-name step, moved to a shared module | Claude; wrong: cost ≈ one cheap call per distinct product ever |
| 10 | AI unavailable | Deterministic fallback parse; those names are matched, **never inserted as shared rows**; unmatched ones become the user's own, as typed names do. The product is retried next time | Claude |
| 11 | Search | On submit only (no search-as-you-type: OFF allows ~10 searches/min for our one server IP); OFF results biased to AT/DE/CH, German names first | Claude; wrong: slower-feeling search |
| 12 | Cache | Table `products` without any user reference: found rows refresh after 30 days, not-found rows after 1 day | Claude (brief) |
| 13 | Paywall | Logging is free, so scanning and search are free; the paywall track must not gate `product-lookup` | Claude (brief) |
| 14 | Scanner package | `mobile_scanner` (current major), the same package the portal plan uses for QR codes; whichever track is built first adds it, the second reuses it | Claude (brief) |

## 3. Approaches

- **Core proxies OFF, caches, one AI pass per product (picked).** Users' IPs and accounts stay with us; we send OFF the
  User-Agent it asks for; one cache serves everyone; the recognised names go through the same catalogue code as photos,
  so FODMAP flags and „Alternativen" behave the same.
- **App calls OFF directly.** Rejected: every user's IP and scan habits go to a third party, no shared cache, no control
  over the User-Agent or the rate limit, and ingredient recognition would have to live in the app.
- **Deterministic parsing only (split on commas, strip percentages and E-numbers).** Rejected as the main path: OFF texts
  are in several languages, nest sub-ingredients in brackets, and hide the FODMAP-relevant parts in additive classes
  („Süßungsmittel: Sorbit"); a parser that keeps those and drops „Säuerungsmittel" is a word list that will never be done,
  and its output would land in the shared catalogue. Kept as the fallback when the AI is down.
- **Reuse `analyze-meal` with a text instead of a photo.** Rejected: its prompt guesses unseen ingredients („Öl zum
  Braten"); for a printed list that is wrong. Its catalogue match and new-name insert are reused as they are.

## 4. Design

### 4.1 Core: route `product-lookup` (`POST /functions/v1/product-lookup`, signed in)

Request: exactly one of
- `{"barcode": "4000000000013"}` — digits only, 8, 12 or 13 long, valid GTIN check digit. A 12-digit UPC-A is stored and
  sent as EAN-13 with a leading `0` (`036000291452` → `0036000291452`).
- `{"q": "haferdrink"}` — trimmed, 2–100 characters.

Responses (200):
```json
{"found": true, "product": {"barcode": "4000000000013", "name": "Haferdrink Natur", "brand": "Testmarke",
  "ingredients": [{"name": "Wasser", "ingredientId": "…uuid…"}, {"name": "Hafer", "ingredientId": "…"},
                  {"name": "Rapsöl", "ingredientId": "…"}, {"name": "Meersalz", "ingredientId": null}]}}
{"found": false, "barcode": "4000000000037"}
{"results": [{"barcode": "4000000000013", "name": "Haferdrink Natur", "brand": "Testmarke"}]}
```
`ingredientId` null = not in the catalogue the user reads (fallback path only, §4.3); `brand` may be null; `ingredients`
may be empty (OFF has no list). The first entry of OFF's comma-separated `brands` is the brand.

Errors (`{"error", "code"}`, German):

| Status | code | text |
|---|---|---|
| 400 | `bad_request` | „Schick entweder einen Barcode oder einen Suchbegriff." (both, neither, wrong types) |
| 400 | `invalid_barcode` | „Dieser Barcode ist ungültig." |
| 400 | `query_too_short` | „Gib mindestens 2 Zeichen ein." (also for > 100: „Der Suchbegriff ist zu lang.", code `query_too_long`) |
| 429 | `throttled` | „Du hast gerade sehr viele Produkte gesucht. Versuch es in ein paar Minuten nochmal." + `Retry-After` |
| 429 | `off_busy` | „Die Produktsuche ist gerade ausgelastet. Versuch es bitte gleich nochmal." + `Retry-After` |
| 502 | `off_unavailable` | „Open Food Facts ist gerade nicht erreichbar. Versuch es später nochmal oder trag die Mahlzeit selbst ein." |
| 500 | — | `@fallback_500` as every route |

**Throttles** (`app.throttle.Throttle`, in process like the others):
- per user: barcode lookups 40 per 10 min, searches 15 per 10 min (every request counts, cached or not: it also stops
  scraping our cache);
- global, outbound to OFF only: product reads 80 per minute, searches 8 per minute — below OFF's documented 100/min
  and 10/min per IP (**verify at build time** on https://openfoodfacts.github.io/openfoodfacts-server/api/ ; if
  search-a-licious documents a different limit, use 80 % of it). A global hit answers `off_busy` unless a stale cache
  row can answer (§4.2).

**Logs:** never the barcode, the search term, a product name or ingredient text (a barcode next to a user id says what
someone eats). Log kinds and counts only, as `analyze-meal` does.

### 4.2 Core: OFF client and cache

`app/off.py`, the only module that talks to OFF, through `app.http.http_client()`:
- `fetch_product(barcode) -> OffProduct | None | OffUnavailable`:
  `GET {off_api_url}/api/v2/product/{barcode}?fields=code,product_name,product_name_de,brands,lang,ingredients_text,ingredients_text_de,ingredients`
  (timeout 5 s, connect 3 s). `status == 0` or HTTP 404 → `None` (not found); other non-2xx, timeouts, unreadable JSON →
  `OffUnavailable`.
- `search_products(q) -> list[OffHit] | OffUnavailable`: search-a-licious
  `GET {off_search_url}/search?q=<q>&langs=de&page_size=50&fields=code,product_name,product_name_de,brands,countries_tags`
  (timeout 6 s), response `hits` (**verify at build time**; if search-a-licious is not usable, the legacy
  `{off_api_url}/cgi/search.pl?search_terms=<q>&search_simple=1&action=process&json=1&page_size=50&fields=…`, response
  `products`). Ranking in our code, not in the query syntax: hits with a valid code and a name; those whose
  `countries_tags` contain `en:austria`, `en:germany` or `en:switzerland` first, OFF's order otherwise; at most 20.
- Name = `product_name_de`, else `product_name`; both trimmed, empty = none. A product without any name counts as not
  found.
- Header `User-Agent: {settings.off_user_agent}`; default `BellyBuddy/1.0 (https://bellybuddy.at)` — app name and a
  contact URL, never a person's e-mail (Severin confirms the contact, Needs §9).
- Settings (`app/settings.py`, with defaults, so no deploy change is needed): `off_api_url =
  "https://world.openfoodfacts.org"`, `off_search_url = "https://search.openfoodfacts.org"`, `off_user_agent`.
- The request carries nothing of the user: no forwarded IP, no id, no cookie.

Search cache: in process, normalised term (lower-case, whitespace collapsed) → results, 1 hour, at most 1000 terms;
the term is kept only there, never with a user id.

Product cache: table `products` (§4.4). Lookup by barcode:
1. A row younger than its refresh age (found: 30 days, not found: 1 day) answers; a found row with `parsed_ingredients`
   null is parsed now (§4.3).
2. Otherwise OFF is asked (global throttle first). Found: upsert name, brand, ingredients text, `fetched_at`; if the
   ingredients text changed (or was never parsed), parse (§4.3); else keep the parsed names. Not found: upsert
   `found = false`.
3. OFF unavailable or global throttle full: a stale row answers as if fresh; no row → `off_unavailable` / `off_busy`.
4. Every answer matches the parsed names against the catalogue **for this user** (their own rows win), per request,
   with the moved `match_catalog` (§4.3).

### 4.3 Core: from OFF's text to the app's ingredients

Input text, first non-empty of: `ingredients_text_de`; `ingredients_text` (any language); the top-level `text` values
of the structured `ingredients` array joined with „, ". No text → `parsed_ingredients = []`, nothing else.

**AI pass** (new `AiRoute` `PRODUCT_INGREDIENTS = AiRoute("product ingredients", "low", 8_000)`, structured output
`{"ingredients": [str]}`): the system prompt takes the photo prompt's naming rules (German, singular, capitalised, the
bracket rules, „prefer these known names" with the same shared-name list from `_shared_names()`) and replaces the
„think beyond what is visible" part with rules for a printed list:
- translate to German;
- list sub-ingredients in brackets as ingredients of their own („Schokolade (Zucker, Kakaomasse)" → Zucker, Kakaomasse);
- drop quantities and percentages, „Zutaten:", footnote marks, „kann Spuren von … enthalten";
- drop additive classes and E-numbers that are not FODMAP-relevant (Säuerungsmittel, Emulgator, Farbstoff, Aroma …);
- **keep** and name in German the FODMAP-relevant ones: Sorbit (E420), Mannit (E421), Isomalt (E953), Maltit (E965),
  Lactit (E966), Xylit (E967), Erythrit (E968), Inulin, Oligofructose, Fructose, Fructose-Glucose-Sirup,
  Glucose-Fructose-Sirup, Honig, Laktose/Milchzucker, Milchpulver, Molkenpulver;
- each name once; no drinks rule (a product may be one).

Then exactly what `analyze-meal` does with its names: catalogue match, and unmatched names through the FODMAP call into
shared rows (`added_via = 'ai_detector'`, no owner — OFF text is public, never user text, so a shared row tells nothing
about a user). To share it, `_match_catalog` and `_insert_new_ingredients` (with `analyze_fodmaps`) move unchanged from
`app/routes/analyze_meal.py` into `app/domain/meal_ingredients.py`; `analyze-meal`'s tests stay green unchanged. The
parsed names are stored in `products.parsed_ingredients`, so the AI runs once per product (and again only when OFF's
text changes).

**Fallback** (AI error of any kind, `app/domain/off_ingredients.py::fallback_names(text)`): split on `,` and `;` outside
brackets, also take bracket contents as items, strip `\d+([.,]\d+)?\s*%`, `*`, „Zutaten:", trailing dots, and a leading
„Klasse: " (keep what follows the colon); map the polyol E-numbers above to their names; drop the other `E\d{3}[a-z]?`
items; capitalise; dedupe case-insensitively; at most 40. These names are matched but **not inserted** and **not
stored** (`parsed_ingredients` stays null, so the next lookup tries the AI again). Unmatched ones are returned with
`ingredientId: null`; the app adds them like typed names (`ensure_ingredient`, the user's own row).

### 4.4 Core: migration `products`

Next free migration number at build time (the plan says `0017_products`; renumber if another track took it).
```
products(
  barcode text primary key check (barcode ~ '^[0-9]{8}$|^[0-9]{13}$'),
  found boolean not null,
  name text, brand text, ingredients_text text,
  parsed_ingredients text[],            -- null: not parsed yet (or the last parse fell back)
  fetched_at timestamptz not null default now(),
  parsed_at timestamptz
)
```
API-only like `portal_interest` in 0016: RLS on, no policy, nothing granted to `anon`/`authenticated`. No user column;
`delete-account` needs no change.

### 4.5 App: the product sheet

`showProductFinderSheet(context) -> Future<ProductPrefill?>`, a modal sheet in the style of `showRecipeSelectorSheet`
(drag handle, `DraggableScrollableSheet`, keyboard padding). Title „Produkt finden".

- **Scanner area** (top, 4:3, rounded `radiusXl`): the camera preview with a frame and the hint „Halte den Barcode in den
  Rahmen". Formats EAN-13, EAN-8, UPC-A only. The first detection stops scanning, plays `HapticService.selection()` and
  looks the code up. The camera starts when the sheet opens and stops while the search field has focus or a result is
  shown; „Nochmal scannen" restarts it.
- **Camera denied:** the area shows „Kein Zugriff auf die Kamera" / „Erlaube Belly Buddy in den Einstellungen den Zugriff
  auf die Kamera, um Barcodes zu scannen. Du kannst das Produkt auch unten suchen." and „Einstellungen öffnen" (as
  `MealImageSection._showAccessDenied` does; the settings-URL constant moves to `utils/url_utils.dart` for both). Other
  camera errors: „Die Kamera konnte nicht gestartet werden. Du kannst das Produkt auch unten suchen."
- **Search** (below the scanner): field hint „Produkt oder Marke suchen", keyboard action „Suchen"; a search runs on
  submit only. Results: rows (`BbSheetRow`) with name (bold) and brand (muted). None: „Keine Produkte gefunden. Versuch
  einen anderen Namen oder trag die Mahlzeit selbst ein." Tapping a row looks its barcode up.
- **Loading:** a spinner with „Suche Produkt …".
- **Found:** a card: name, brand, the ingredients as `BbIngredientChip`s (or „Für dieses Produkt sind keine Zutaten
  hinterlegt. Du kannst sie gleich selbst eintragen."), the attribution line „Produktdaten: Open Food Facts (ODbL)"
  (tap opens `https://world.openfoodfacts.org/product/<barcode>` in the browser), buttons „Übernehmen" (pops the
  `ProductPrefill`) and „Anderes Produkt" (back to scanner and search).
- **Not found:** „Dieses Produkt kennen wir noch nicht." / „Du kannst die Mahlzeit einfach selbst eintragen.", buttons
  „Selbst eintragen" (closes the sheet, null) and the link „Produkt bei Open Food Facts ergänzen" (opens OFF's add page for
  the code, `https://world.openfoodfacts.org/cgi/product.pl?type=search_or_add&action=display&code=<barcode>` —
  **verify at build time**; opened in the browser by the user, so OFF's own policy applies there).
- **Errors:** core's German text when the body has one (throttles, OFF unavailable); else „Das hat gerade nicht
  geklappt. Versuch es bitte nochmal." Shown in the sheet with „Nochmal versuchen".

### 4.6 App: into the meal

`ProductPrefill {barcode, title, ingredients: List<ProductIngredient{name, ingredientId?}>}`.
`MealTrackerNotifier.applyProduct(ProductPrefill p)`: title := `p.title` iff the title is `kDefaultMealTitle`; each
ingredient name not already present (case-insensitive) is appended in order; for each appended name with `ingredientId
== null` the notifier calls `ingredientAutocompleteProvider.notifier.addIngredient(name)` (ensures the user's own row, as
typing does). Photo, date and notes untouched. The meal then saves through the normal `save()`; no product reference is
stored on the meal.

### 4.7 App: attribution in Settings

Settings gets a row under „Datenschutzerklärung": „Produktdaten", subtitle „Open Food Facts, Lizenz ODbL". It opens a
dialog „Produktdaten von Open Food Facts": „Name, Marke und Zutaten von Produkten, die du scannst oder suchst, stammen
aus Open Food Facts, einer freien Lebensmitteldatenbank. Die Daten stehen unter der Open Database License (ODbL)." with
„Open Food Facts öffnen" (`https://world.openfoodfacts.org`) and „Lizenz ansehen"
(`https://opendatacommons.org/licenses/odbl/1-0/`), and „Schließen".

### 4.8 Permissions

- iOS: `NSCameraUsageDescription` exists („BellyBuddy benötigt Zugriff auf die Kamera, um Mahlzeiten zu fotografieren.").
  It becomes „Belly Buddy braucht die Kamera, um deine Mahlzeiten zu fotografieren und Barcodes oder QR-Codes zu
  scannen." — one text that also covers the portal's QR scan (the portal plan sets a QR-only text; whichever track ships
  second keeps this combined text).
- Android: `android.permission.CAMERA` is already in the manifest. Nothing else.

### 4.9 ODbL: what the cache means for us (honest summary, not legal advice)

- OFF's database is under the ODbL 1.0, its individual contents under the Database Contents License, its images under
  CC BY-SA (we use no images).
- Showing a product's name and ingredients to a user is a „Produced Work": it needs the attribution notice (§4.3 of the
  licence) — the line on the result card and the Settings row.
- Our `products` table holds OFF extracts plus our own parsed names: that is a **Derivative Database**. As long as we
  only use it internally it carries no share-alike duty; but Produced Works made **from** a Derivative Database and used
  publicly oblige us (§4.6) to also offer that Derivative Database, or a file of our changes, under the ODbL to whoever
  receives the Produced Work. Practically: be ready to publish (or send on request) a dump of `products` (barcode,
  name, brand, ingredients text, parsed names) under the ODbL. That dump contains no user data. The ingredient names
  that land in our shared `ingredients` catalogue are single generic words (Hafer, Sorbit), not a substantial
  extract; that is our reading, to be confirmed.
- → „Legal check of the ODbL obligations for the cache" under Needs from Severin.

### 4.10 Testing without the network

- Core: OFF answers are recorded JSON in `backend/tests/fixtures/off/` (synthetic products with valid check digits, shaped
  like OFF's v2 and search answers; product data is not personal data), served with `respx` as the AI calls already are
  (`tests/routes/conftest.py`). The AI pass is mocked like `analyze-meal`'s.
- App: `ProductService` behind a provider (tests fake it); the scanner behind `barcodeScannerProvider`, a builder of the
  scanner widget, the only code importing `mobile_scanner` — widget tests inject a fake whose button „emits" a barcode
  or a permission error.

## 5. Privacy policy text (for the shared „policy text" task; no version bump here)

> **Barcode-Scan und Produktsuche (Open Food Facts).** Wenn du beim Eintragen einer Mahlzeit einen Barcode scannst oder
> nach einem Produkt suchst, schickt die App den Barcode oder deinen Suchbegriff an unseren Server. Das Kamerabild wird
> nur auf deinem Gerät ausgewertet und nicht übertragen. Unser Server fragt Name, Marke und Zutatenliste des Produkts bei
> Open Food Facts ab, einer freien Lebensmitteldatenbank des gemeinnützigen Vereins Open Food Facts (Frankreich). Dabei
> übermitteln wir nur den Barcode oder den Suchbegriff – nicht deine IP-Adresse, nicht dein Konto und nichts, was dich
> erkennbar macht. Die Produktdaten speichern wir ohne Bezug zu dir, damit wir nicht jedes Mal neu fragen müssen;
> Suchbegriffe halten wir höchstens eine Stunde im Arbeitsspeicher, ebenfalls ohne Bezug zu dir. Welches Produkt du
> gescannt hast, speichern wir nicht; was du danach als Mahlzeit speicherst, ist ein normaler Eintrag in deinem
> Tagebuch. Rechtsgrundlage ist die Erfüllung des Nutzungsvertrags (Art. 6 Abs. 1 lit. b DSGVO). Öffnest du über den
> Link „Produkt bei Open Food Facts ergänzen" oder die Produktdaten-Zeile die Website von Open Food Facts, gilt dort deren
> Datenschutzerklärung.

If the Android build uses Google's ML Kit for scanning (mobile_scanner does), add after the camera sentence — shared
with the portal's QR scan:

> Auf Android-Geräten erkennt eine Funktion von Google (ML Kit) den Code auf dem Gerät; Google kann dabei technische
> Nutzungsdaten der Funktion erhalten, aber keine Kamerabilder.

(Severin's check: Needs §9.)

## 6. Non-goals

- Nutrition facts, Nutri-Score, NOVA, allergens shown as such, portion sizes.
- Scanning in the drink tracker (decision 4); a product as a recipe.
- Contributing to OFF from the app (only the link to OFF's site).
- Product images; a „recently scanned" list; offline scanning.
- Any user reference in `products`; analytics on scans.

## 7. Left to the builder

- The exact OFF endpoints, field names and limits marked „verify at build time"; the client module is the only place to
  change.
- Whether the search cache is a small class or `functools`-style helper, as long as TTL and size are tested.
- How the scanner area pauses (`MobileScannerController.stop/start` or unmounting), as long as the camera is off while
  a result or the keyboard is shown.
- The `mobile_scanner` version (`flutter pub add mobile_scanner`, current major) and any native setup its README asks
  for (iOS deployment target, Android `minSdk`); report what was needed.

## 8. Manual checks for Severin (device only)

- iOS and Android: first scan asks for the camera with the new text; deny → the German explanation and „Einstellungen
  öffnen" work; allow → an EAN-13 (any German supermarket product), an EAN-8 and a US UPC-A product are recognised.
- A known product fills title and chips; a second scan adds its ingredients to the same meal; „Speichern" gives a normal
  diary entry with FODMAP flags on the chips.
- An unknown barcode shows „Dieses Produkt kennen wir noch nicht." and the OFF link opens OFF's page for that code.
- The search finds „Haferdrink" with German names first; the camera stops while typing.

## 9. Needs from Severin

1. **Legal check of the ODbL obligations for the cache** (§4.9): do we have to publish the `products` dump, and is the
   attribution wording on the card and in Settings enough?
2. **OFF User-Agent contact:** confirm `BellyBuddy/1.0 (https://bellybuddy.at)` or name a role mailbox (e.g. a
   `kontakt@` address) — never a personal e-mail. Set `OFF_USER_AGENT` only if it differs from the default.
3. **Privacy policy:** sign off the paragraph in §5, including the ML Kit sentence (shared with the portal's QR scan), in
   the one shared policy bump.
4. Nothing else touches a third-party account: OFF's read API needs no key or registration.
