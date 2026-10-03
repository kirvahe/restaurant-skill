---
name: restaurant
description: Find restaurants, bars, wine bars, and cocktail bars matching taste profile. This skill should be used when the user asks for restaurant, bar, wine bar, or cocktail bar recommendations, wants to rate a visited place, or asks to analyze dining patterns. Triggers on food/drink venue recommendations, "where to eat", "want a drink", "bar", "wine", "cocktails", city names with food/drink context.
argument-hint: [city mood/type]
version: "1.4"
---

## LANGUAGE RULE — RESPONSE LANGUAGE = REQUEST LANGUAGE (НЕНАРУШАЕМО)

**ALL user-facing output is in the language of the user's request. Russian request → Russian answer. English request → English answer.**

This applies to EVERYTHING shown to the user, with NO exceptions:
- Chat prose (Overview, card descriptions, notes)
- Inline blocks (★ Insight, summaries, explanations)
- Saved `recommendations/*.md` files

Internal data files stay in English regardless of request language: `taste-profile.md`, `feedback-log.md`, `cities/*.md`, `config.yml`, `MEMORY.md`. File and folder NAMES are always ASCII-English. But everything the user reads = request language. No English fragments inside a Russian conversation, no mixing.

If you catch yourself drafting user-facing text in a language different from the request — STOP and rewrite. See `~/.claude/CLAUDE.md` (LANGUAGE RULES) and memory `feedback_output_language_match.md`.

## Setup

On first use, Claude must check if the skill is configured:

1. Look for `~/.claude/skills/restaurant/config.yml`
2. If `config.yml` does NOT exist → run Onboarding from Block 1
3. If `config.yml` exists → read it, load taste-profile.md from `data_dir`
4. Check if onboarding is complete — taste-profile.md must have all three required sections filled (not empty, not template placeholders):
   - **Who** section (Block 1) — home city, companions, budget
   - **Cuisine** section (Block 2) — hierarchy, comfort dishes
   - **Reference restaurants** section (Block 6) — at least 3 calibration entries
   If any required section is missing → resume Onboarding from the first incomplete required block
5. If complete → proceed to Routing

### Config file: `~/.claude/skills/restaurant/config.yml`

Created during onboarding. Contains:

```yaml
version: "1.4"
home_city: Berlin                                          # set during onboarding
home_address: "Musterstrasse 42"
data_dir: "/Users/yourname/Documents/restaurant-data"
saved_places_source: google_maps                           # or apple_maps / none
gmaps_data_dir: "/Users/yourname/gmaps-sync/data"          # optional, only if google_maps
gmaps_sync_script: "/Users/yourname/gmaps-sync/sync.sh"    # optional, only if google_maps
gmaps_timestamp: "/Users/yourname/gmaps-sync/.last-sync"   # optional, only if google_maps
```

All data files live at the path specified in `data_dir`. Google Maps integration is optional; without it the skill operates without saved-list cross-checks.

## Data Files

All paths relative to `data_dir` from config.yml:

| File | Purpose |
|---|---|
| `taste-profile.md` | Full taste profile — read BEFORE every action |
| `feedback-log.md` | Visit log, /10 scale — rating scale and entry format defined here |
| `cities/{city}.md` | City recommendation caches |
| `recommendations/` | Saved recommendation outputs |
| `restaurant-capsule.md` | 25-slot "go-to" picks by occasion (optional). When present and filled, consult during Find-a-spot to surface a proven anchor alongside fresh search |
| `google-maps-data.md` | Index of all Google Maps saved lists (symlink to gmaps_data_dir). Read to discover available lists |

**Google Maps data** (lives at `gmaps_data_dir` from config.yml):
- `google-maps-data.md` — index of all synced lists (48 lists, auto-updated by Playwright scraper)
- `{list-name}.tsv` — one TSV file per list. Format: `Name\tRating\tReviews\tType\tStatus`
- Key lists: `favorites.tsv`, `want-to-go.tsv`, `noodles.tsv`, `italian.tsv`, `japanese.tsv`, `cocktail-bar.tsv`, etc.

**Reference files** (live next to SKILL.md in `~/.claude/skills/restaurant/references/`):
- `visit-protocol.md` — peak/end/disconfirm question protocol + decimal scoring rule (loaded when recording a visit)
- `source-confidence.md` — A/B/C tier model + tourist-bias annotation rule (loaded when ranking candidates / formatting output)
- `hidden-gems.md` — under-the-radar slot mandate (loaded when composing output of 3+ picks)
- `occasion-taxonomy.md` — 7 occasions + inference rules (loaded when starting Find-a-spot)
- `onboarding-blocks.md` — full 7-block onboarding protocol (loaded only during onboarding)
- `local-critics.md` (lives in `~/.claude/skills/restaurant/`, not in references/) — editorial food sources by country (31 countries). Read when searching new countries.

### cities/{city}.md — structure

**Standard sections (always present):**
- `## Searched` — one line per search or round. Format: `YYYY-MM-DD R{N}: {query} → {outcome}`
- `## Recommended` — current active recommendations (table: Name, Type, Area, Rating, Notes)
- `## Mentioned (researched, not yet selected)` — candidates surfaced during research that did NOT make the final cut. Table: Name, Type, Source/Context, Date. Goal: prevent loss between sessions. Example: a Michelin-listed taberna researched in a coastal-views search and excluded for "no view" — log it here so the next general search can promote it instead of re-researching from scratch
- `## Blacklist` — permanently excluded restaurants with one-line reason

**Multi-round sections (added only when Round 2+ occurs):**
- `## Round N — {outcome}` — archive of completed round. Heading includes outcome: "rejected by wife (visual)", "dinner hours problematic", etc.
- `## Excluded (with reason)` — cumulative exclusion list across all rounds. One entry per restaurant: name + one-line causal reason. Grows across rounds, never shrinks
- `## Criteria changes` — documents what shifted between rounds: `R1→R2: {what changed and why}`
- `## Transport notes` — when distances vary across candidates
- `## Key facts` — city-specific logistics (holidays, meal times, weather)

Single-shot searches create ONLY standard sections. Multi-round sections appear automatically when Round 2+ begins.

## Resilience

### Before any action, check data files:
- **taste-profile.md missing or empty** → STOP. Tell user: "Taste profile not found. Run `/restaurant` to start onboarding." Do not guess preferences.
- **feedback-log.md missing or empty** → continue without visit cross-checks. Note in output: "No visit history loaded."
- **Google Maps data missing** → if `gmaps_data_dir` is set but `google-maps-data.md` doesn't exist there → note "Google Maps data unavailable — run sync or check ~/gmaps-sync setup." Continue without cross-check. If `gmaps_data_dir` is not set → treat as `saved_places_source: none`.
- **cities/{city}.md missing** → normal for first search in a city. No warning needed. Will be created on save.
- **recommendations/ or cities/ directory missing** → create with `mkdir -p` before saving. Never fail on missing directory.

### Web search failure:
- If primary search tool returns error or empty results → try fallback tool (see Search tool detection below).
- **Site-specific rejection** (e.g. Firecrawl returns "We do not support this site" — happens on Reddit): do NOT drop the source. Immediately retry via Exa (`mcp__exa__web_search_exa` or `mcp__exa__web_fetch_exa`). Reddit is a top-priority source — never abandon it because Firecrawl can't scrape it. A scrape/tool error counts as a primary-tool failure and triggers fallback, same as an empty result.
- If ALL search tools fail → use training knowledge only. Add to Overview: "Web search unavailable — recommendations based on training data only. Verify independently."
- Never silently degrade. If any data source was unavailable, state which one and what was skipped.

### Data integrity:
- If a file exists but cannot be parsed (garbled content, broken markdown) → treat as missing. Tell user: "File appears corrupted — proceeding without it."
- One missing enhanced data source is normal. Two or more missing → add a disclaimer to the output.
- Never invent data to fill gaps (fake ratings, imagined visit history, fabricated sources).

## Google Maps Auto-Sync

On every /restaurant invocation, before Routing:

1. Read `gmaps_timestamp` file (path from config.yml `gmaps_timestamp` key)
2. Parse Unix timestamp, compare with current time (`date +%s`)
3. If elapsed > 86400 seconds (24h) → run `gmaps_sync_script` (from config) in background via Bash (`nohup ... &`). Do NOT wait for completion
4. If elapsed <= 86400 → skip, data is fresh
5. Proceed immediately with current data. Never block on sync

If `gmaps_timestamp` file doesn't exist → run sync script in background, proceed with whatever data is available.

---

## Routing

Default mode is **Find a spot.** Switch only when confident the user intends Record or Analyze.

For Find a spot, infer the **occasion** from query language before scoring candidates. The occasion materially changes which candidates rank well — a date-night search and a quick-solo-lunch search produce different recommendations even from the same taste profile. See `references/occasion-taxonomy.md` for the 7-occasion model and inference rules.

After inferring the occasion, check `restaurant-capsule.md` (if it exists and the matching slot is filled): a capsule pick is a user-confirmed go-to for exactly this kind of outing, so surface it as an anchor candidate alongside fresh search results — clearly, and never to the exclusion of new discovery. The capsule is an accelerator, not a replacement for searching. If the file is missing or the relevant slot is empty, skip silently.

**Record a visit** — user is reporting on a place they already went to.
Signals: past tense, gives a rating, evaluates a specific place, mentions what they ordered.
Examples: "went to Septime, 9/10" · "I was at that sushi place, solid 8" · "tried the new Georgian, disappointed"

**Analyze preferences** — user wants to understand their own patterns.
Signals: asks about patterns, statistics, what they like/dislike, profile updates.
Examples: "analyze my preferences" · "what do I actually like?" · "my stats"

**Everything else → Find a spot.** If ambiguous, ask.

### Round detection (within "Find a spot")

Before searching, check if this is a continuation of a previous search:

1. Read `cities/{city}.md` — look for `## Searched` entries from the last 7 days
2. Detect refinement signals in user message:
   - References to prior results: "none of those work", "she didn't like any", "try something else"
   - Criteria shifts: "actually lunch not dinner", "forget the view", "tasting menu is OK now"
   - Companion feedback: "wife rejected", "he wants something more casual"
   - Explicit round language: "round 2", "next batch", "refine"

**If continuation detected:**
- Load the existing recommendation file from `cities/{city}.md` most recent `## Searched` entry
- Load the exclusion list from `## Excluded (with reason)`
- Load the `## Mentioned (researched, not yet selected)` list — these are surfaced candidates from prior rounds. Cross-check before re-researching the same names. Promote to `## Recommended` if the current criteria fit, otherwise keep in Mentioned with updated context
- Track as Round N+1 (increment from last round number in `## Searched`)
- Document what changed and why in `## Criteria changes`

**If new search** (different city, different cuisine category, or no recent history):
- Standard single-shot flow. No round tracking overhead.

Never ask "is this a continuation?" — infer from context. If genuinely ambiguous (same city, same week, different cuisine), treat as new search.

---

## Taste Profile

Read `taste-profile.md` BEFORE every action. If the file is empty, missing required sections, or contains only template placeholders — do NOT recommend. Run onboarding first. Never guess preferences without a profile.

Reference restaurants from the profile are internal calibration — NEVER mention them in output.

---

## Sources

These are defaults. User's taste-profile.md overrides them.

### Trusted (use these)
Reddit (city subs, diaspora) · Conde Nast Traveller · Eater (9 maintained cities only — see rule below) · The Infatuation · Monocle · Gambero Rosso · OAD · Noble Rot · Punch (drinks) · La Liste · Gault & Millau · Raw Wine · Wine Spectator (wine lists) · Serious Eats · Vittles · Fare Magazine · Raisin (natural wine) · Guía Repsol (Soles + Soletes — Spain/Portugal/Andorra) · Michelin Guide (Bib Gourmand, recs) · World's 50 Best · Google Maps · Madrid Secreto (madridsecreto.co — CCAA Madrid only) · ComerJapones (comerjapones.com — Japanese cuisine in Spain)

**Local critics:** For every recommendation, look up the target country in `local-critics.md` (31 countries, named critics, publications, dominant platforms).

### Banned — NEVER use
TripAdvisor · Yelp · TheFork · Instagram · Tourist guides · AI-generated listicles · GetYourGuide/Viator

---

## Search Rules

### Search tool detection — route by query type (hybrid)
There is no single "primary" tool. The project routing rule `.claude/rules/web_search.md` is a per-task-type table, not a blanket preference — honor it by picking the tool by what the query actually needs:

- **Exa** (`mcp__exa__web_search_exa` / `mcp__exa__web_fetch_exa`) → Reddit (ALWAYS — Firecrawl cannot scrape Reddit), editorial/diaspora consensus, and semantic discovery ("places similar to X", "natural-wine bars like Y"). This is the bulk of restaurant discovery.
- **Firecrawl** (`mcp__firecrawl__firecrawl_search` / `firecrawl_scrape`) → structured local-business lookups (exact address, opening hours, "near me"), scraping a specific known URL (a venue's own site, a Michelin page), and Madrid Secreto category pages.
- **Direct HTTP via Bash + curl** → the Guía Repsol API only (`guia-app-api.cloudapp.repsol.com`, no auth). Its venue-listing endpoint is a POST, so no scrape/fetch tool can reach it. Use for Spain/Portugal/Andorra discovery, then Firecrawl the returned `canonical` URL for the details the API omits. See `references/guia-repsol.md`.
- **Built-in WebSearch/WebFetch** → last resort only (no site: filtering).
- None available → Degraded Mode (see Resilience section).

Reddit is a top-priority source queried 3×/cuisine, and Firecrawl returns "We do not support this site" on it — so route Reddit straight to Exa instead of wasting a Firecrawl call first. Cache the tool chosen per purpose for the session; re-detect only on error.

### Language rule — search in up to 3 languages:
1. Country language FIRST — local critics are strongest (in Spain/Portugal/Andorra this includes Guía Repsol)
2. English (Reddit, Conde Nast, The Infatuation — Eater only in its 9 maintained cities)
3. Cuisine language if different from country language
- {Cuisine} in its home country: cuisine language > EN
- {Cuisine} in another country: country language > EN > cuisine language

### Reddit: always 3 queries per cuisine — country language + cuisine language + English. Include diaspora communities for ethnic cuisines (diaspora knows authenticity better than locals).

### Home-country business press: MANDATORY whenever a search for an ethnic cuisine outside its home country returns "this format does not exist here".

A specialist chain that expands out of its home country can be the only venue in a city doing a given format — and it will be invisible to local food media for years, because it arrived through **corporate expansion, not the restaurant scene**. No critic covered it because no critic was told about it. Search the home country's business wires, not its food press.

| Source | Query in | Finds |
|---|---|---|
| Nikkei (nikkei.com) | Japanese | Listed-company overseas openings, with the format stated plainly |
| PR TIMES (prtimes.jp) | Japanese | The company's own release: address, seat count, opening hours, opening date |
| Local job boards for the diaspora (e.g. `kaigai-bbs.com`) | Japanese | Staff-recruitment ads that precede an opening by months — the earliest possible signal |

Equivalents exist per cuisine: Korean, Chinese, Italian and Thai operators all announce outbound expansion in their own business media first.

**Worked example.** A search for a dedicated udon house in a Spanish city ran three rounds — Spanish editorial, Guía Repsol, ComerJapones, Japanese expat Q&A boards, two Reddit threads, and a menu-phrase sweep — and all of them converged on "this city has no udon-ya". It was stated as verified. It was wrong. A listed Japanese noodle chain with a few hundred restaurants at home had opened a noodle house there. Nikkei reported it on opening day, quoting the format directly: soba and udon at the core, sushi only under consideration. Not one Spanish source, and not ComerJapones, ever mentioned it. The expat Q&A thread predated the opening.

**Three failure modes this guards against:**
1. **A generic brand name drowns the search.** "Udon" in Spain returns the 81-location UDON Asian Food chain on every query, in every language, forever. When a common dish word is also a local brand, keyword search is structurally dead — go to the business wires and to menu-phrase searches (`kitsune udon`, `kake udon`) instead.
2. **Community sources have a timestamp.** A diaspora thread is a snapshot of when it was written. A venue that opened afterwards cannot appear in it, however authoritative the thread is.
3. **Absence of evidence read as evidence of absence.** Four source families agreeing still only proves those four families do not cover it. Say "I did not find one, in these sources" — never "there is none".

**MANDATORY second query — the closure check.** A business-press hit proves the venue *opened*. It says nothing about whether it still exists. Before recommending, run a second query in the same language and same source family for `閉店` / `撤退` / `cierre` / `closure` plus the venue name, and — when the operator is a listed company — open its IR store-movement disclosure. Listed operators publish openings and closures in the same table; that table is the single most reliable status source available anywhere.

**Never take a live delivery-platform or menu-aggregator page as proof of life.** Uber Eats store pages, carta.menu / speisekarte.menu menus, Instagram reels and TheFork entries all persist long after a venue dies — they are not deprecated on closure, so they actively manufacture false confidence. A TripAdvisor page reading "Cerrado ahora" means *outside opening hours*, not permanently closed; it is not a status signal in either direction. **The one cheap, decisive test: if a venue has no Google Maps listing, it is almost certainly gone.** Check that the Maps pin resolves before the recommendation ships.

*Worked failure, same case:* the noodle house was found via Nikkei's opening-day report. It had closed in less than a year — reported by the Japanese regional business press and listed in the operator's own IR closures. It was recommended as a live venue anyway, because the search queried the opening and never the closure, while an Uber Eats page and a menu-aggregator page were both still up. The closure only came to light when the map link resolved to an empty search.

**Judging the result.** An inbound specialist chain trips the "chain" anti-pattern, and that tension is real, so state it rather than resolving it silently. A noodle-specialist chain from the cuisine's home country is a different object from a pan-Asian chain in the destination country — but the home-country standard (in-store milling, twice-daily noodle production) is a claim about the parent, not about the franchise in front of you. Verify it locally or mark it unverified.

### Diaspora-language Q&A boards: MANDATORY for any ethnic-cuisine search outside the cuisine's home country, at the same level as Reddit.

Residents of a city who come FROM the cuisine's country are the highest-signal source that exists for authenticity, and they almost never write in the local language, so no amount of Spanish/French/English searching reaches them. Query in the cuisine's language.

| Board | Community | Access |
|---|---|---|
| `locotabi.jp/{city}/q/` | Japanese expats, city-by-city Q&A | Exa (Japanese-language query). Firecrawl scrapes the thread pages fine |
| Japanese personal blogs (hatenablog, ameblo, fc2) | Japanese residents + travellers | Exa, query in Japanese |

**Why the Q&A format matters more than the platform.** These are people answering a specific question from a specific person — not writing for an audience, not being paid, not performing taste. Answers name streets and dishes, and they contradict each other openly. This layer routinely surfaces venues that are invisible to every local-language source, and those can end up being the ones recommended.

**The decisive signal is the dish, not the verdict.** A Japanese blogger wrote of one venue's kitsune udon 「出汁が惜しい」 — "the dashi falls short" — and that single clause outweighed a candidate's high Google Maps rating, hundreds of reviews and a ComerJapones listing. Nobody writing in Spanish tastes dashi and reports on it. Search for the dish name in the cuisine's script (うどん, 天ぷら, 出汁) rather than the venue name.

**Read them as a spread, not a consensus.** In one thread a resident called a venue "正に日本の味" while a Reddit local dismissed the same place on ownership alone. Report both; the ownership objection is not a food objection.

**Guardrail:** these threads are often years old and the boards do not mark closures. Every venue that reaches the output still needs its own open-status check — a single search has turned up three Reddit/locotabi-recommended venues that were permanently closed.

### Madrid Secreto (madridsecreto.co): MANDATORY for every search where target city is Madrid OR anywhere in Comunidad de Madrid (Alcalá de Henares, Aranjuez, Chinchón, San Lorenzo de El Escorial, etc.). Same enforcement level as Reddit — never skip, regardless of cuisine or occasion. Search `site:madridsecreto.co {cuisine OR neighborhood OR query}` via Exa/Firecrawl, or fetch a relevant category page directly. Strong local editorial signal for hidden gems, neighborhood scenes, and trend spots. A positive mention on Madrid Secreto counts as one of the 2+ independent validations required by the Validation rule below.

### ComerJapones (comerjapones.com): MANDATORY for every Japanese-cuisine search in Spain, at the same enforcement level as Guía Repsol. Run by Roger Ortuño, a Japanese-food specialist writing in Spanish; the only source in the Spanish-language landscape that judges a Japanese venue on *washoku* terms rather than on sushi-market terms.

Two assets, used differently:
- **Venue finder** — `comerjapones.com/restaurante/?_localidad={city}` (paginated; the `restaurantes/` spelling redirects to `restaurante/`). Entries carry format tags (izakaya, omakase, kaiseki, "buena carta de sake") and a one-line editorial note. Firecrawl scrapes it fine.
- **Long-form reviews** — `comerjapones.com/{slug}-{city}/`. These name the *dish* worth ordering in Japanese with the kanji, which is what makes the source uniquely valuable: it is usually the only place that says which specific bowl at a given venue is the one to get.

**Why this matters for non-sushi searches.** Spain's Japanese coverage is overwhelmingly sushi-first — Michelin, Repsol and Google all rank the omakase layer and are close to blind to udon, soba, tempura, teishoku and katei ryori. ComerJapones is the corrective: it is where a specific udon or tempura recommendation actually exists. On an udon-and-tempura search, every other source returned either the UDON chain or an omakase counter.

**Guardrail — check the date on every review.** A large share of the long-form posts are from 2007-2012 and some venues in them are permanently closed (Janatomo is flagged in-page as `cerrado permanentemente`, but not all are). The finder entries are refreshed more recently. Treat the dish recommendation as durable and the venue's existence as unverified: always confirm open status separately.

A ComerJapones review or finder entry counts as one of the 2+ independent validations required by the Validation rule below.

### Raisin (raisin.digital): ALWAYS check for wine bar / natural wine searches. Search `raisin.digital {city}` or fetch `raisin.digital/en/explore/{country}/{region}/{city}/`. Cross-reference every candidate against Raisin — presence on Raisin is a strong quality signal for natural/organic/biodynamic wine venues.

### Guía Repsol (guiarepsol.com): MANDATORY for every search in Spain, Portugal, or Andorra — same enforcement level as Reddit, never skip. Full spec in `references/guia-repsol.md`; read it before the first call.

Two award systems, and the distinction decides which one you want:
- **Soletes** (`calificacion;S`, 5,500+) — casual: bars, tabernas, chiringuitos, cafés, vinotecas, heladerías. This is the default for most searches, and the layer Michelin does not cover at all.
- **Soles** (`calificacion;1`/`2`/`3`, 808 restaurants) — the serious rating. Use for celebration/destination occasions.

**Primary path — API (Bash + curl, no auth):** resolve the city with `GET /search/{city}` → take `locations.data[0].id` (verify its `subtitle` names the right place), then `POST /poi/map` with `{"tagIds":[...],"locationId":"..."}`. Filter by cuisine (`tipoCocinaRte;`), venue type (`tipoEstablecimiento;`), chef (`cocineros;{name}`), or services (`servicios;acepta_mascotas`, `terraza_verano`, `conVistas`, `conNinnos`). Then Firecrawl the returned `canonical` URL for opening hours, review text, chef names, and award history — the API does not carry those.

**Fallback when Bash is unavailable or the API changes:** `site:guiarepsol.com/es/fichas/solete {type} {city}` via Firecrawl (path-scoping restricts results to Soletes; swap `/restaurante` for Soles).

**Three guardrails, all mandatory:**
1. An award means "was once judged good", not "is currently good" — Soles are rarely revoked and the 2025 edition made only 400 visits against a 618-venue list. Always confirm `schedule.businessStatus` from `GET /poi/{id}`.
2. Prefer inspector- and chef-sourced Soletes (`cocineros;`) over celebrity-sourced (`famosos;`) — a celebrity Solete is a personal pick, not an inspected award.
3. The badge is a filter, not a ranking. Shortlist with it, then rank by taste profile.

Also worth querying directly for chef-cited candidates: `/es/comer/donde-comen-los-cocineros/` (plus `/{city}` variants) — chefs naming their own favourite places.

A Solete or Sol counts as one of the 2+ independent validations required below, subject to guardrail 1.

### Eater (eater.com): use ONLY for the 9 cities Eater actually maintains — Paris, London, Barcelona, Lisbon, Rome, Tokyo, Mexico City, Vancouver, Montreal. For every other city, skip Eater entirely and rely on local-language critics; 31 of its 47 international lists have never been touched since commission.

**Freshness gate — check before using ANY Eater page:** read the `article:modified_time` and `article:published_time` meta tags (plain `curl -sL` reaches them; no Firecrawl needed). Reject the page if **either** test fails:
- `modified == published` → the list was never revisited since commission
- `modified` is more than ~12 months old → the edition has gone dormant

The second test matters because the 9-city list below is a snapshot of July 2026 and will decay — an edition can be dropped at any time, and the city whitelist alone will not notice. A maintained list also states its own changes ("New to the map in April 2026: …"); the absence of such a note on a supposedly current list is a warning sign.

**Access:** `firecrawl_scrape` on `https://{sub}.eater.com/maps` with `formats:["json"]` returns that US city's current 38 and heatmap in one call. For international cities, resolve through `https://www.eater.com/international-maps` or search — international slugs are not guessable. Check the final status after redirects; the `/eater-38` hub still links dead URLs that 301 into 404s.

**Never** scope a query to a city subdomain (`site:london.eater.com`) — dormant subdomains return only archives and miss the live list on `www`. **Never** use the San Sebastián list: it is titled "12 Best *New* Restaurants", was published in 2012 and last touched in 2018. For Spain, Eater has exactly one current asset (the Barcelona 38); Madrid, Seville, Mallorca and Getaria are 16 months to 4.5 years stale.

### Anti-recommendation search: search for overrated/avoid mentions in the target city. Build blacklist BEFORE recommending. In Round 2+, user/companion exclusions replace the anti-recommendation search — run anti-rec search only in Round 1.

### Multi-round exclusion:
When continuing a previous search (Round 2+):
- ALL restaurants from prior rounds are excluded — never re-recommend a rejected candidate
- Load exclusion list from `cities/{city}.md` `## Excluded (with reason)` section
- Add every new exclusion with a one-line causal reason. Use companion's words when available, preserve original language (e.g., "Wife: 'пош, не уютно'" not "Decor mismatch")
- Exclusion reasons are causal: "Too far without car", "Lunch only, need dinner", "No panoramic views"
- If user explicitly reinstates a previously excluded restaurant, remove it from the exclusion list

### Quality: minimum 4 queries, target 6-8. If < 5 candidates → second round with different patterns. Better 2 strong picks than 3 mediocre ones — never pad with weak options.

### Priority: Reddit + diaspora Q&A boards → Madrid Secreto (CCAA Madrid only) → Guía Repsol (Spain/Portugal/Andorra) → ComerJapones (Japanese cuisine in Spain) → Raisin (for wine) → local critics (from `local-critics.md`) → Conde Nast → Michelin → fresh articles (last 2 years)

Eater is not in the main chain — it is conditional. Consult it only for its 9 maintained cities, and only after its freshness gate passes; there it ranks alongside Conde Nast.

### Validation: reliable if mentioned in 2+ independent sources, OR detailed Reddit review with specifics, OR Michelin rec.

### Source confidence — assign tier per candidate
Every candidate gets a confidence tier ([A], [B], [C]) based on source quality. This drives ranking when other factors are comparable, and appears as a visible prefix in output. See `references/source-confidence.md` for the tier model + tourist-bias rule.

### Google Maps saved lists (if connected):
When `saved_places_source` is not `none` and `gmaps_data_dir` is set in config:

**Step 1 — Identify relevant TSV files:**
- Read `google-maps-data.md` from `gmaps_data_dir` to see all available lists
- **Always check:** `favorites.tsv` (strongest signal), `want-to-go.tsv`
- **By cuisine:** match search cuisine to list name. Examples:
  - ramen/noodles → `noodles.tsv` + `japanese.tsv`
  - Italian → `italian.tsv`
  - cocktails → `cocktail-bar.tsv`
  - sushi → `sushi.tsv` + `japanese.tsv`
  - steak/grill → `meat.tsv`
- **By country (travel searches):** check country-named lists (`armenia.tsv`, `spanish.tsv`, etc.)

**Step 2 — Grep TSV files for candidates:**
- Use Grep tool on each relevant TSV file. TSV format: `Name\tRating\tReviews\tType\tStatus`
- **Match on a normalized name, never on the literal display name.** Google Maps stores venues under their own branding, which routinely differs from the guide/press spelling: `Kai Ten` → `Restaurante Kaiten`, `La Bodega de Example` → `Example`, `Casa Ejemplo` → `casa ejemplo madrid`. Before comparing, lowercase, strip accents, and remove every non-alphanumeric character from BOTH sides, then test substring containment in both directions. A literal grep on the display name silently reports "not saved" and the whole recommendation is wasted on a place the user already knows.
- **Short names need a direct grep too.** Normalized containment on names under ~6 characters (`Oda`, `Kai`, `Mesa`, `Fuego`) produces both false positives and false negatives, so verify each short-named finalist with its own targeted grep before it reaches the output.
- **Verify every finalist individually before writing the card**, not just at pool-filtering time. The claim "нет ни в одном твоём списке" is load-bearing when the user asked for unknown places — get it wrong and the pick is worthless even if the venue is excellent.
- **Respect the Status column.** Never recommend a place whose Status is `permanently_closed` — drop it from candidates entirely. For `temporarily_closed`, include only if it's a strong match and tag it explicitly "(temporarily closed — verify before going)". `open` or empty → normal candidate. Do NOT delete closed rows from the TSV files: the scraper regenerates them from Google Maps on each sync, so filtering must happen here at read time, not in the data.
- EVERY open place from the user's thematic list is a candidate — do not skip by rating or brand association
- Cross-check: in Favorites → priority candidate (user confirmed it's good). In feedback-log → already visited
- If a group/brand is known for one format (pizza) but has another format (trattoria, bistro) → evaluate each format separately ("brand ≠ format" rule)
- Family business with 2-4 locations is NOT a "chain". Chain = corporate (soulless, "for everyone")

**Step 3 — Annotate output cards:**
- For each recommended place, check if it appears in ANY Google Maps list
- If found: add to card after price line: `Your lists: {list names} · GM {rating}`
- If NOT found in any list: omit this line (absence is also information — note in Overview if a top pick isn't in user's maps)

### Google Maps rating — information, NOT a filter:
- Always show rating + review count in the card
- Do NOT filter by rating. Threshold: 3.0+ = consider
- High rating ≠ good place. Low rating ≠ bad place
- Factors that deflate ratings: authentic cuisine without adaptation, no English menu, small/no-frills service, family business not chasing reviews
- Factors that inflate ratings: tourist wow-effect, beautiful interior masking average food, managed reviews
- Decision is made by sources, format, and taste profile match — not by the number

---

## Round Transitions

A round transition happens when the user provides feedback on the current round's recommendations. The transition is implicit — no ceremony needed.

**Between rounds, Claude must:**
1. Archive the current round in `cities/{city}.md` under `## Round N — {outcome}` (what was recommended, what happened)
2. Move all rejected restaurants to `## Excluded (with reason)` with causal reasons
3. Document criteria changes in `## Criteria changes` section
4. Begin the new search with the updated exclusion list loaded

**Claude must NOT:**
- Ask "shall I start a new round?" — if the user is refining, just do it
- Number rounds in chat output — the user doesn't care. Track round numbers only in files
- Repeat prior round results — the user already saw them
- Re-search excluded restaurants — the exclusion list is definitive unless the user explicitly reinstates a candidate

**Companion feedback as round trigger:** receiving "wife rejected all 4" or similar = Round N is complete, Round N+1 begins. Record feedback verbatim in the round archive, preserve original language including non-English.

---

## Output Format

### Structure:
1. **Overview** (always this word, even in non-English output) — can be text, bullets, or a mix (e.g. one intro line + bullets). Key facts, practical summary, **inferred occasion** (one phrase). For Round 2+ searches, Overview must open with: what changed from the previous round and why (one line), count of excluded restaurants (not the full list), then standard content.
2. **Cards** — 2-5 places, sorted by relevance (best match first, weakest last). NO labels. Never pad with weak options to reach a count.
3. **Hidden Gem** — for outputs of 3+ picks, one slot is reserved for an under-the-radar candidate. See `references/hidden-gems.md` for selection criteria + when the slot can be skipped.
4. **Proximity note** — ONLY when planning an evening (restaurant + bar) or exploring a new city. NEVER suggest walking from restaurant to restaurant.

### Card format:
```
### N. {Name}
**{Type} · {Neighbourhood}**

{Why this place fits — 2-3 sentences about the place itself. NO comparisons to other restaurants. NO vibe references. Just what this place is and why it works.}

**{local currency} XX-YY for two** · caveat if any (reservation, unusual hours, etc.)

> {Street address} · {distance from home if in home city}
> [Google Maps](https://www.google.com/maps/search/{Name+Street+City, ASCII, spaces as +}) · {Rating} ({N reviews}{tourist-bias annotation if triggered}) · **Sources:** [{tier}] {source list}
```

The `[A]` / `[B]` / `[C]` tier prefix on the Sources line is mandatory — see `references/source-confidence.md`. The tourist-bias inline annotation (e.g., "(842 — likely tourist-inflated, treat as ~4.0)") fires only in tourist-heavy zones; same reference file defines the trigger conditions.

### Rules:
- **LANGUAGE = REQUEST LANGUAGE** — all chat prose, card text, inline ★ Insight blocks, and the saved recommendation `.md` are written in the user's request language (see LANGUAGE RULE at top). Internal cache files stay English. No mixing.
- NO labels (strong pick / solid / speculative) — sorting does the job
- NO comparisons to reference restaurants
- NO italic (unreadable in terminal)
- NEVER start a line with `~` (renders as strikethrough in Claude Code)
- Google Maps link: always `https://www.google.com/maps/search/{Name+Street+City}` (path form, no query params). Use ASCII only (strip accents: Dongiò → Dongio), spaces as `+`, include the street so the pin resolves to the exact venue, not a fuzzy name match. (Note: a link opening two browser tabs is a Warp terminal Cmd+Click behavior, not a URL-format issue — not fixable from link formatting.)
- **Every venue name in EVERY table is a Google Maps hyperlink** — no exceptions, no separate link column. Wrap the name itself: `| [Kai Ten](https://www.google.com/maps/search/Kai+Ten+Example+St+12+Berlin) | якитори | ... |`. Applies to comparison tables, "Mentioned", "Excluded", city-cache tables, and any ad-hoc table in chat or in a saved `.md`. A table of place names without links forces the user to re-search each one by hand, which defeats the point of the table.
- For home city: include neighbourhood + distance from home address
- `---` between cards

### Multi-round extensions (Round 2+ only)

These elements are FORBIDDEN in single-shot output but PERMITTED in Round 2+:

- **Logistics tags** after the price line in cards: `All-weather (panoramic windows)` or `Terrace only — weather dependent`. Plain text, no emoji
- **Comparison table** after all cards — only when 3+ candidates AND the search involves trade-offs the user needs to weigh (view vs food quality, price vs distance). Columns: only attributes that actually differ between candidates. No decorative columns. Every name in the first column is a Google Maps hyperlink (see Rules above) — mandatory
- **Action items** as the final section — concrete next steps with phone numbers and a suggested booking script. Only when booking is time-sensitive (holidays, limited seating)
- **Exclusion summary** at the end — excluded restaurants with reasons. For Round 3+, group by round

Labels (strong pick / speculative / ✅ / ⚠️ / ❌) remain FORBIDDEN in all modes. Sorting by relevance still does the job.

### After delivering response:

**Single-shot:**
1. Save as `recommendations/{city}-{type}-YYYY-MM-DD.md` — write using Bash tool, do not show file content in chat
2. Update `cities/{city}.md` cache — write using Bash tool, do not show file content in chat
3. Write all researched-but-not-selected candidates from this search to `## Mentioned (researched, not yet selected)` in `cities/{city}.md`. Include one-line context (why excluded from this cut: e.g. "no view", "tasting menu only", "too far"). This applies to candidates surfaced anywhere in the chat — research alternatives, near-miss options, candidates rejected for axis-mismatch, anything you actually looked up. Goal: prevent "Los Fueros effect" — losing a researched candidate between sessions because it didn't make a single search's final cut
4. Last line of chat: link to saved .md file

**Multi-round (Round 2+):**
1. UPDATE the existing `recommendations/{city}-{type}-YYYY-MM-DD.md` — replace with current round's content. The recommendation file always reflects the CURRENT active round only. File header tracks round and criteria evolution:
   ```
   Created: YYYY-MM-DD (round N — {what changed})
   Search: {current criteria}
   Prior: R1 {criteria} → {outcome}; R2 {criteria} → {outcome}
   ```
2. Update `cities/{city}.md` — add round archive, update exclusion list, update `## Recommended` table
3. Last line of chat: link to the updated .md file

Round history lives in `cities/{city}.md`, not in the recommendation file. This keeps the recommendation file clean and actionable.

**Recommendations recap before the link** — the very END of every Find-a-spot response must be a compact recap list of the recommended places (name + one-line hook each, in recommendation order), placed immediately ABOVE the file link. The cards above can be scrolled past; this recap is the scannable takeaway. Meta/notes go above the recap; nothing goes between the recap and the file link except the link itself. See memory `feedback_results_before_link`.

**Always end with the .md file link** — every response (find, record, analyze) must finish with a link to the saved/updated file. Order at the bottom of the message is strictly: recap list → file link (last line).

### Before outputting, cross-check each candidate against:
- feedback-log (already visited? what rating?)
- Google Maps TSV files (in Favorites? Want to go? Thematic list?) — grep `gmaps_data_dir` TSVs
- cities/{city}.md cache (previously recommended?)
- round exclusion list (cities/{city}.md `## Excluded` — never re-recommend)

### Debrief
On every /restaurant invocation (before routing, skip if message contains Record signals): check recommendations/ for files from last 30 days with no matching feedback-log entries. If found AND not previously asked: "Last time I recommended {N} places in {city}. Tried any? A quick rating helps me learn." Then proceed with user's actual request. Mark asked batches with `<!-- debrief: asked YYYY-MM-DD -->` in the recommendation file. Max 1 debrief per session. If 3 consecutive debriefs get no response → pause debriefs for 30 days.

Skip debrief for active multi-round searches — if the most recent round in `cities/{city}.md` is < 7 days old with no feedback-log entry AND has an active exclusion list, the search is still in progress.

---

## Record a visit

Read feedback-log.md first. New entries follow the **visit protocol** — asymmetric question batch (peak / end / disconfirm / return) with decimal scoring on the 9.0+ tier. See `references/visit-protocol.md` for the full question template, decimal rule, and entry format.

Existing entries (the 33 captured in older format) remain unchanged — the new format applies only to new captures going forward.

If the place already exists in feedback-log.md (e.g. from onboarding or a previous visit), add a new dated entry — it's a revisit, not a duplicate. Multiple entries per place are expected and help track taste evolution.

After recording:
1. Update the `## Reference` block in feedback-log.md — power spots, the strong tier, best source, context frames, provenance. **Do NOT compute a log-wide average or any by-city/by-axis/by-type distribution.** Those were removed in v1.4: the average pooled incompatible `Context` frames and fed a drift scan that had no action attached. Reasoning is recorded in `references/visit-protocol.md` → "Drift detection — removed" and in the log's own "Why there is no average" section. If a number is ever needed, compute it inside one frame and name the frame
2. Update cities/{city}.md — write using Bash tool, do not show content in chat
3. If 10/10 → suggest adding to taste-profile references

### Calibration (after every 5th visit, count >= 10):
Scan ratings by cuisine and anti-pattern. If a cuisine has 3+ entries averaging 8+ but is below Top tier → propose promotion. If an anti-pattern has 3+ entries rated 6-7 → propose softening to "soft" filter. Present max 2 tweaks, one at a time: "[Current] → [Proposed]. Evidence: {places+ratings}. Apply? (y/n)". On yes → update taste-profile.md. On no → suppress that tweak for 10 more entries. No calibration below 10 entries. Full analysis at every 15th entry or on request.

---

## Analyze Preferences

If feedback-log has fewer than 5 dated entries (excluding Block 6 historical entries) → respond: "Not enough visit data yet. Record a few more visits and try again."

Read feedback-log.md, taste-profile.md, all cities/*.md. Find patterns in high-rated (8-10) and low-rated (1-5) visits, **reading each rating against its `Context:` frame** — an 8 with a `rural` frame and an 8 with an `absolute` frame are not the same evidence. Compare with the current profile: what's confirmed, what's new, what's questionable. Propose specific updates to taste-profile.md, show to user, wait for confirmation. Refresh the `## Reference` block in feedback-log.md. Summarize key findings.

**Do not compute a log-wide average or by-city/by-axis/by-type distributions.** They count without informing anything, and the average is actively misleading across frames — removed in v1.4, see `references/visit-protocol.md`. Group by `Context` frame or by cuisine instead; the cuisine calibration below is the mechanism that actually changes the profile.

Never change profile without explicit user confirmation.

---

## Onboarding

**Trigger:** config.yml missing, OR taste-profile.md empty/missing/template-only, OR required blocks incomplete (1, 2, 6).

Full block-by-block protocol: see `references/onboarding-blocks.md`. Loaded only when onboarding triggers; not consulted on routine searches.
