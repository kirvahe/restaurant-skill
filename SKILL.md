---
name: restaurant
description: Find restaurants, bars, wine bars, and cocktail bars matching taste profile. This skill should be used when the user asks for restaurant, bar, wine bar, or cocktail bar recommendations, wants to rate a visited place, or asks to analyze dining patterns. Triggers on food/drink venue recommendations, "where to eat", "want a drink", "bar", "wine", "cocktails", city names with food/drink context.
argument-hint: [city mood/type]
---

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
version: "1.0"
home_city: Berlin          # set during onboarding
home_address: "Musterstrasse 42"
data_dir: "/Users/yourname/Documents/restaurant-data"
saved_places_source: google_maps  # or apple_maps / none
```

All data files live at the path specified in `data_dir`.

## Data Files

All paths relative to `data_dir` from config.yml:

| File | Purpose |
|---|---|
| `taste-profile.md` | Full taste profile — read BEFORE every action |
| `feedback-log.md` | Visit log, /10 scale — rating scale and entry format defined here |
| `cities/{city}.md` | City recommendation caches |
| `recommendations/` | Saved recommendation outputs |
| `saved-places-data.md` | Saved places lists (optional — Google Maps, Apple Maps, etc.) |

**Reference file** (lives next to SKILL.md in `~/.claude/skills/restaurant/`):
- `local-critics.md` — Editorial food sources by country (30 countries). Read when searching new countries or during onboarding.

## Resilience

### Before any action, check data files:
- **taste-profile.md missing or empty** → STOP. Tell user: "Taste profile not found. Run `/restaurant` to start onboarding." Do not guess preferences.
- **feedback-log.md missing or empty** → continue without visit cross-checks. Note in output: "No visit history loaded."
- **saved-places data broken/missing** → continue without saved-places cross-check. Note: "Saved places unavailable."
- **cities/{city}.md missing** → normal for first search in a city. No warning needed. Will be created on save.
- **recommendations/ or cities/ directory missing** → create with `mkdir -p` before saving. Never fail on missing directory.

### Web search failure:
- If primary search tool returns error or empty results → try fallback tool (see Search tool detection below).
- If ALL search tools fail → use training knowledge only. Add to Overview: "Web search unavailable — recommendations based on training data only. Verify independently."
- Never silently degrade. If any data source was unavailable, state which one and what was skipped.

### Data integrity:
- If a file exists but cannot be parsed (garbled content, broken markdown) → treat as missing. Tell user: "File appears corrupted — proceeding without it."
- One missing enhanced data source is normal. Two or more missing → add a disclaimer to the output.
- Never invent data to fill gaps (fake ratings, imagined visit history, fabricated sources).

## Routing

Default mode is **Find a spot.** Switch only when confident the user intends Record or Analyze.

**Record a visit** — user is reporting on a place they already went to.
Signals: past tense, gives a rating, evaluates a specific place, mentions what they ordered.
Examples: "went to Septime, 9/10" · "I was at that sushi place, solid 8" · "tried the new Georgian, disappointed"

**Analyze preferences** — user wants to understand their own patterns.
Signals: asks about patterns, statistics, what they like/dislike, profile updates.
Examples: "analyze my preferences" · "what do I actually like?" · "my stats"

**Everything else → Find a spot.** If ambiguous, ask.

---

## Taste Profile

Read `taste-profile.md` BEFORE every action. If the file is empty, missing required sections, or contains only template placeholders — do NOT recommend. Run onboarding first. Never guess preferences without a profile.

Reference restaurants from the profile are internal calibration — NEVER mention them in output.

---

## Sources

These are defaults. User's taste-profile.md overrides them.

### Trusted (use these)
Reddit (city subs, diaspora) · Conde Nast Traveller · Eater · The Infatuation · Monocle · Gambero Rosso · OAD · Noble Rot · Punch (drinks) · La Liste · Gault & Millau · Raw Wine · Wine Spectator (wine lists) · Serious Eats · Vittles · Fare Magazine · Raisin (natural wine) · Michelin Guide (Bib Gourmand, recs) · World's 50 Best · Google Maps

**Local critics:** For every recommendation, look up the target country in `local-critics.md` (30 countries, named critics, publications, dominant platforms).

### Banned — NEVER use
TripAdvisor · Yelp · TheFork · Instagram · Tourist guides · AI-generated listicles · GetYourGuide/Viator

---

## Search Rules

### Search tool detection
On first search of session, check available tools in this priority order:
1. `mcp__exa__web_search_exa` (semantic — best for editorial/Reddit)
2. `mcp__firecrawl__firecrawl_search` (web — best for structured extraction)
3. `mcp__brave__brave_web_search` / `mcp__tavily__*` (keyword — general)
4. Built-in WebSearch/WebFetch (limited, no site: filtering)
5. None available → Degraded Mode (see Resilience section)
Cache the selected tool for the session. Re-detect only on error.

### Language rule — search in up to 3 languages:
1. Country language FIRST — local critics are strongest
2. English (Reddit, Eater, Conde Nast)
3. Cuisine language if different from country language
- {Cuisine} in its home country: cuisine language > EN
- {Cuisine} in another country: country language > EN > cuisine language

### Reddit: always 3 queries per cuisine — country language + cuisine language + English. Include diaspora communities for ethnic cuisines (diaspora knows authenticity better than locals).

### Anti-recommendation search: search for overrated/avoid mentions in the target city. Build blacklist BEFORE recommending.

### Quality: minimum 4 queries, target 6-8. If < 5 candidates → second round with different patterns. Better 2 strong picks than 3 mediocre ones — never pad with weak options.

### Priority: Reddit → local critics (from `local-critics.md`) → Conde Nast / Eater → Michelin → fresh articles (last 2 years)

### Validation: reliable if mentioned in 2+ independent sources, OR detailed Reddit review with specifics, OR Michelin rec.

### Saved places lists (if connected):
When `saved_places_source` is not `none`, check saved-places-data.md for lists matching the target city:
- Read the relevant thematic list/file from saved-places-data.md
- EVERY place from the user's thematic list is a candidate — do not skip by rating or brand association
- Cross-check: is it in Favorites? In feedback-log? → priority candidate
- If a group/brand is known for one format (pizza) but has another format (trattoria, bistro) → evaluate each format separately ("brand ≠ format" rule)
- Family business with 2-4 locations is NOT a "chain". Chain = corporate (soulless, "for everyone")

### Google Maps rating — information, NOT a filter:
- Always show rating + review count in the card
- Do NOT filter by rating. Threshold: 3.0+ = consider
- High rating ≠ good place. Low rating ≠ bad place
- Factors that deflate ratings: authentic cuisine without adaptation, no English menu, small/no-frills service, family business not chasing reviews
- Factors that inflate ratings: tourist wow-effect, beautiful interior masking average food, managed reviews
- Decision is made by sources, format, and taste profile match — not by the number

---

## Output Format

### Structure:
1. **Overview** (always this word, even in non-English output) — can be text, bullets, or a mix (e.g. one intro line + bullets). Key facts, practical summary.
2. **Cards** — 2-5 places, sorted by relevance (best match first, weakest last). NO labels. Never pad with weak options to reach a count.
3. **Proximity note** — ONLY when planning an evening (restaurant + bar) or exploring a new city. NEVER suggest walking from restaurant to restaurant.

### Card format:
```
### N. {Name}
**{Type} · {Neighbourhood}**

{Why this place fits — 2-3 sentences about the place itself. NO comparisons to other restaurants. NO vibe references. Just what this place is and why it works.}

**{local currency} XX-YY for two** · caveat if any (reservation, unusual hours, etc.)

> {Street address} · {distance from home if in home city}
> [Google Maps](https://www.google.com/maps/search/{Name+City}) · {Rating} ({N reviews}) · **Sources:** {source list}
```

### Rules:
- NO labels (strong pick / solid / speculative) — sorting does the job
- NO comparisons to reference restaurants
- NO italic (unreadable in terminal)
- NEVER start a line with `~` (renders as strikethrough in Claude Code)
- Google Maps link: always `https://www.google.com/maps/search/{Name+City}`
- For home city: include neighbourhood + distance from home address
- `---` between cards

### After delivering response:
1. Save as `recommendations/{city}-{type}-YYYY-MM-DD.md` — write using Bash tool, do not show file content in chat
2. Update `cities/{city}.md` cache — write using Bash tool, do not show file content in chat
3. Last line of chat: link to saved .md file

**Always end with the .md file link** — every response (find, record, analyze) must finish with a link to the saved/updated file.

### Before outputting, cross-check each candidate against:
- feedback-log (already visited? what rating?)
- saved-places-data (in Favorites? in Want to go?) — if connected
- cities/{city}.md cache (previously recommended?)

### Debrief
On every /restaurant invocation (before routing, skip if message contains Record signals): check recommendations/ for files from last 30 days with no matching feedback-log entries. If found AND not previously asked: "Last time I recommended {N} places in {city}. Tried any? A quick rating helps me learn." Then proceed with user's actual request. Mark asked batches with `<!-- debrief: asked YYYY-MM-DD -->` in the recommendation file. Max 1 debrief per session. If 3 consecutive debriefs get no response → pause debriefs for 30 days.

---

## Record a visit

Read feedback-log.md first. Ask in ONE message (not one by one):
- Place name, city, rating /10

Optional (extract from context if given): type, axis, what ordered, what worked/didn't, would return, company, source, notes. Infer Type and Axis from place name/context; ask only if ambiguous.

Use the rating scale and entry format defined in feedback-log.md.

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

**Trigger:** config.yml missing, OR taste-profile.md empty/missing/template-only, OR required blocks incomplete.

**Format:** Ask questions in blocks (batch), not one by one. User answers in free text. Tell user it takes ~10 min (essentials) or ~20 min (full). Blocks can be skipped and filled later.

### Blocks

| Block | Required? | Topic | Key questions | After block |
|---|---|---|---|---|
| 1 | **Yes** | Setup | City, address, companions, budget, diet, restaurants-as-hobby, saved places source | Create config.yml, data_dir, initial files. If saved places → ask user to export/share data |
| 2 | **Yes** | Cuisines | Top 3 cuisines, avoid list, 2-3 comfort dishes, spicy/offal/raw/seafood preferences | Update taste-profile.md Cuisine section |
| 3 | No | Food philosophy | Product vs concept, returnability, sharing plates, seasonality | Update Taste Compass |
| 4 | No | Atmosphere & drinks | Room type, design, wine, cocktails, coffee, service style | Update Atmosphere/Wine/Cocktails/Coffee/Service |
| 5 | No | Anti-patterns | Present checklist from taste-profile-template.md. Ask for a disappointing experience example | Update Anti-patterns |
| 6 | **Yes** | Reference restaurants | 5-10 loved places (name, city, cuisine, /10, why). 2-3 disappointing places (what went wrong) | Update References. Add all to feedback-log.md (use "--" for unknown fields, approximate date or "--" for Date, "(historical)" in Notes) |
| 7 | No | Ritual & sources | Evening format, booking style, travel distance, new vs familiar, seasonality, trusted/distrusted sources | Read local-critics.md for home country. Update Evening ritual + Sources |

**Before Block 6:** show the rating scale from feedback-log.md so user calibrates consistently.

### After all blocks:
1. Show a summary of the assembled profile (key points, not full file) — ask user to review
2. Wait for confirmation, save final taste-profile.md
3. Create cities/ and recommendations/ directories
4. Confirm: "Setup complete. Try: `/restaurant [city] [mood/cuisine]`"

### Skipped blocks:
Mark skipped sections with `[SKIPPED]` in taste-profile.md. After 3-5 new visits post-onboarding (not counting Block 6 historical entries), prompt to fill in skipped sections.

### Profile evolution:
The profile grows over time. After "analyze" → propose updates. After a new city with 3+ visits → suggest neighbourhood notes. After a 10/10 visit → suggest adding to references. After a revisit that downgrades a reference below 9 → suggest moving tier. Never change profile without explicit user confirmation.
