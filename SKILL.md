---
name: restaurant
description: Find restaurants, bars, wine bars, and cocktail bars matching taste profile. This skill should be used when the user asks for restaurant, bar, wine bar, or cocktail bar recommendations, wants to rate a visited place, or asks to analyze dining patterns. Triggers on food/drink venue recommendations, "where to eat", "want a drink", "bar", "wine", "cocktails", city names with food/drink context.
argument-hint: [city mood/type]
version: "1.3"
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
version: "1.1"
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
Reddit (city subs, diaspora) · Conde Nast Traveller · Eater · The Infatuation · Monocle · Gambero Rosso · OAD · Noble Rot · Punch (drinks) · La Liste · Gault & Millau · Raw Wine · Wine Spectator (wine lists) · Serious Eats · Vittles · Fare Magazine · Raisin (natural wine) · Michelin Guide (Bib Gourmand, recs) · World's 50 Best · Google Maps · Madrid Secreto (madridsecreto.co — CCAA Madrid only)

**Local critics:** For every recommendation, look up the target country in `local-critics.md` (31 countries, named critics, publications, dominant platforms).

### Banned — NEVER use
TripAdvisor · Yelp · TheFork · Instagram · Tourist guides · AI-generated listicles · GetYourGuide/Viator

---

## Search Rules

### Search tool detection — route by query type (hybrid)
There is no single "primary" tool. The project routing rule `.claude/rules/web_search.md` is a per-task-type table, not a blanket preference — honor it by picking the tool by what the query actually needs:

- **Exa** (`mcp__exa__web_search_exa` / `mcp__exa__web_fetch_exa`) → Reddit (ALWAYS — Firecrawl cannot scrape Reddit), editorial/diaspora consensus, and semantic discovery ("places similar to X", "natural-wine bars like Y"). This is the bulk of restaurant discovery.
- **Firecrawl** (`mcp__firecrawl__firecrawl_search` / `firecrawl_scrape`) → structured local-business lookups (exact address, opening hours, "near me"), scraping a specific known URL (a venue's own site, a Michelin page), and Madrid Secreto category pages.
- **Built-in WebSearch/WebFetch** → last resort only (no site: filtering).
- None available → Degraded Mode (see Resilience section).

Reddit is a top-priority source queried 3×/cuisine, and Firecrawl returns "We do not support this site" on it — so route Reddit straight to Exa instead of wasting a Firecrawl call first. Cache the tool chosen per purpose for the session; re-detect only on error.

### Language rule — search in up to 3 languages:
1. Country language FIRST — local critics are strongest
2. English (Reddit, Eater, Conde Nast)
3. Cuisine language if different from country language
- {Cuisine} in its home country: cuisine language > EN
- {Cuisine} in another country: country language > EN > cuisine language

### Reddit: always 3 queries per cuisine — country language + cuisine language + English. Include diaspora communities for ethnic cuisines (diaspora knows authenticity better than locals).

### Madrid Secreto (madridsecreto.co): MANDATORY for every search where target city is Madrid OR anywhere in Comunidad de Madrid (Alcalá de Henares, Aranjuez, Chinchón, San Lorenzo de El Escorial, etc.). Same enforcement level as Reddit — never skip, regardless of cuisine or occasion. Search `site:madridsecreto.co {cuisine OR neighborhood OR query}` via Exa/Firecrawl, or fetch a relevant category page directly. Strong local editorial signal for hidden gems, neighborhood scenes, and trend spots. A positive mention on Madrid Secreto counts as one of the 2+ independent validations required by the Validation rule below.

### Raisin (raisin.digital): ALWAYS check for wine bar / natural wine searches. Search `raisin.digital {city}` or fetch `raisin.digital/en/explore/{country}/{region}/{city}/`. Cross-reference every candidate against Raisin — presence on Raisin is a strong quality signal for natural/organic/biodynamic wine venues.

### Anti-recommendation search: search for overrated/avoid mentions in the target city. Build blacklist BEFORE recommending. In Round 2+, user/companion exclusions replace the anti-recommendation search — run anti-rec search only in Round 1.

### Multi-round exclusion:
When continuing a previous search (Round 2+):
- ALL restaurants from prior rounds are excluded — never re-recommend a rejected candidate
- Load exclusion list from `cities/{city}.md` `## Excluded (with reason)` section
- Add every new exclusion with a one-line causal reason. Use companion's words when available, preserve original language (e.g., "Wife: 'пош, не уютно'" not "Decor mismatch")
- Exclusion reasons are causal: "Too far without car", "Lunch only, need dinner", "No panoramic views"
- If user explicitly reinstates a previously excluded restaurant, remove it from the exclusion list

### Quality: minimum 4 queries, target 6-8. If < 5 candidates → second round with different patterns. Better 2 strong picks than 3 mediocre ones — never pad with weak options.

### Priority: Reddit → Madrid Secreto (CCAA Madrid only) → Raisin (for wine) → local critics (from `local-critics.md`) → Conde Nast / Eater → Michelin → fresh articles (last 2 years)

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
- For home city: include neighbourhood + distance from home address
- `---` between cards

### Multi-round extensions (Round 2+ only)

These elements are FORBIDDEN in single-shot output but PERMITTED in Round 2+:

- **Logistics tags** after the price line in cards: `All-weather (panoramic windows)` or `Terrace only — weather dependent`. Plain text, no emoji
- **Comparison table** after all cards — only when 3+ candidates AND the search involves trade-offs the user needs to weigh (view vs food quality, price vs distance). Columns: only attributes that actually differ between candidates. No decorative columns
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
1. Recalculate statistics in feedback-log.md (total visits, average rating, power spots, best source)
2. Update cities/{city}.md — write using Bash tool, do not show content in chat
3. If 10/10 → suggest adding to taste-profile references

### Calibration (after every 5th visit, count >= 10):
Scan ratings by cuisine and anti-pattern. If a cuisine has 3+ entries averaging 8+ but is below Top tier → propose promotion. If an anti-pattern has 3+ entries rated 6-7 → propose softening to "soft" filter. Present max 2 tweaks, one at a time: "[Current] → [Proposed]. Evidence: {places+ratings}. Apply? (y/n)". On yes → update taste-profile.md. On no → suppress that tweak for 10 more entries. No calibration below 10 entries. Full analysis at every 15th entry or on request.

---

## Analyze Preferences

If feedback-log has fewer than 5 dated entries (excluding Block 6 historical entries) → respond: "Not enough visit data yet. Record a few more visits and try again."

Read feedback-log.md, taste-profile.md, all cities/*.md. Compute statistics (total visits, average rating, distributions by city/type/axis, best source). Find patterns in high-rated (8-10) and low-rated (1-5) visits. Compare with current profile — what's confirmed, what's new, what's questionable. Propose specific updates to taste-profile.md, show to user, wait for confirmation. Recalculate statistics in feedback-log.md. Summarize key findings.

Never change profile without explicit user confirmation.

---

## Onboarding

**Trigger:** config.yml missing, OR taste-profile.md empty/missing/template-only, OR required blocks incomplete (1, 2, 6).

Full block-by-block protocol: see `references/onboarding-blocks.md`. Loaded only when onboarding triggers; not consulted on routine searches.
