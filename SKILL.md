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
4. Check if onboarding is complete: taste-profile.md must have a filled **Reference restaurants** section (not empty, not template placeholders). If missing → resume Onboarding from the first incomplete required block (1, 2, or 6)
5. If complete → proceed to Routing

### Config file: `~/.claude/skills/restaurant/config.yml`

Created during onboarding. Contains:

```yaml
home_city: Berlin          # set during onboarding
home_address: "Kastanienallee 7"
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

## Routing

**City + mood** → Find a spot (below)
**"rate" / "visited" / "went to"** → Record a visit (below)
**"learn" / "analyze" / "patterns"** → Analyze preferences (below)
**Empty / unclear** → Ask: find a spot, record a visit, or analyze?

---

## Taste Criteria (summary — full detail in taste-profile.md)

Read `taste-profile.md` BEFORE every recommendation. The summary below is a fallback — always prefer the full profile.

The taste profile defines:
- **What fits** — cuisine philosophy, atmosphere, format preferences
- **What kills it** — anti-patterns that disqualify a place
- **Cuisine hierarchy** — ranked preferences
- **Vibe references** — calibration restaurants (internal only, NEVER mention in output)
- **Special search modes** — cuisine-specific rules

---

## Sources

These are defaults. User's taste-profile.md overrides them.

### Trusted (use these)
Reddit (city subs, diaspora) · Conde Nast Traveller · Eater · The Infatuation · Monocle · Gambero Rosso · OAD · Noble Rot · Punch (drinks) · La Liste · Gault & Millau · Raw Wine · Wine Spectator (wine lists) · Serious Eats · Vittles · Fare Magazine · Raisin (natural wine) · Michelin Guide (Bib Gourmand, recs) · World's 50 Best · Google Maps

**Local critics by country** (top sources — full database in `local-critics.md`):

| Country | Key local sources |
|---|---|
| Spain | Guia Repsol, El Comidista, 7 Canibales |
| France | Le Fooding, Gault&Millau, Le Pudlo |
| Italy | Gambero Rosso, Slow Food Osterie d'Italia, Dissapore |
| Germany | Falstaff, Feinschmecker, Gusto, Berlin Food Stories |
| UK | Vittles, Harden's, Hot Dinners |
| Japan | Tabelog (dominant), Dancyu |
| USA | Eater (city editions), The Infatuation, James Beard |
| Portugal | Boa Cama Boa Mesa, NIT, Time Out Lisboa |
| Greece | FNL Guide, Athinorama, Gastronomos |
| Turkey | Vedat Milor / Gastromondiale, Culinary Backstreets |
| South Korea | Blue Ribbon Survey (dominant), Mangoplate |
| Thailand | Wongnai (dominant), BK Magazine Top Tables |
| Denmark/Sweden | White Guide Nordic, Falstaff Nordic |
| Netherlands | Lekker, Gault&Millau NL |
| Belgium | Gault&Millau Belgium |
| Austria | Gault&Millau Austria, Falstaff, A la Carte |
| Mexico | Guia Mexico Gastronomico / Los 250 |
| Peru | Summum |
| India | EazyDiner, Vir Sanghvi (Hindustan Times) |
| Australia | Good Food Guide (SMH), Gourmet Traveller |
| Singapore | Makansutra |
| Hong Kong | OpenRice (dominant), Tatler Dining |
| Israel | Al Hashulchan |
| Czech Republic | Maurer's Grand Restaurant |
| Argentina | Pick Up the Fork |
| Poland | Gault&Millau Polska |

For countries not listed, read `local-critics.md` for extended coverage.

### Banned — NEVER use
TripAdvisor · Yelp · TheFork · Instagram · Tourist guides · AI-generated listicles · GetYourGuide/Viator

---

## Search Rules

### Language rule — always search in up to 3 languages:
1. Country language FIRST (Spanish for Madrid, French for Paris) — local critics are strongest
2. English (Reddit international, Eater, Conde Nast)
3. Cuisine language (Greek restaurants → also search in Greek)

**Language priority depends on context:**
- {Cuisine} in {country of that cuisine}: cuisine language > EN (e.g. Italian in Rome → IT > EN)
- {Cuisine} in another country: country language > EN > cuisine language (e.g. Italian in Madrid → ES > EN > IT)

**Reddit: always 3 queries** — country language + cuisine language + English. Example for Italian in Madrid:
- `site:reddit.com r/madrid restaurante italiano pasta`
- `site:reddit.com r/italy ristorante italiano Madrid`
- `site:reddit.com r/madrid italian restaurant authentic`

### Diaspora pattern (mandatory for ethnic cuisines):
- Search the diaspora's own communities, not just local city subs
- Example: Greek in Madrid → `site:reddit.com r/greece greek restaurant madrid`
- Diaspora knows authenticity better than locals

### Anti-recommendation search:
- `site:reddit.com {city} overrated restaurant avoid`
- Build a blacklist BEFORE recommending

### Minimum: 4 queries. Target: 6-8.
### If < 5 candidates after first round → run a second round with different patterns.
### Quality bar: better 2 strong picks than 3 mediocre ones. Every recommendation needs a clear story — why THIS place specifically fits. If research doesn't yield enough strong candidates for a second round, say so honestly rather than padding with weaker options.

### Priority: Reddit first → specialized source by type → Conde Nast / Eater → Michelin → fresh articles (last 2 years)

### Validation: reliable if mentioned in 2+ independent sources, OR detailed Reddit review with specifics, OR Michelin rec.

### Local sources lookup:
For the target city's country, check the local sources table in the Sources section above. If the country is not in the table, read `local-critics.md` for extended coverage (30 countries, named critics, publications).

### Dominant local platforms (country-specific):
When searching in these countries, prioritize the local platform over general web search:
- **Japan:** Tabelog (tabelog.com) — anything above 3.5/5 is exceptional. Professional critics matter less here
- **South Korea:** Blue Ribbon Survey (bluer.co.kr) — Korea's Michelin equivalent, created by/for Koreans
- **Thailand:** Wongnai (wongnai.com) — 26M users, Thai-language primary
- **Hong Kong:** OpenRice (openrice.com) — universally used, annual Best Restaurants awards
- **Singapore:** Makansutra (makansutra.com) — the authority for hawker/street food

### Saved places lists (if connected):
When searching in home city and `saved_places_source` is not `none`:
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
2. **Cards** — 3-5 places, sorted by relevance (best match first, weakest last). NO labels.
3. **Proximity note** — ONLY when planning an evening (restaurant + bar) or exploring a new city. NEVER suggest walking from restaurant to restaurant.

### Card format:
```
### N. {Name}
**{Type} · {Neighbourhood}**

{Why this place fits — 2-3 sentences about the place itself. NO comparisons to other restaurants. NO vibe references. Just what this place is and why it works.}

**EUR XX-YY for two** · caveat if any (reservation, unusual hours, etc.)

> {Street address} · {distance from home if in home city}
> [Google Maps](https://www.google.com/maps/search/{Name+City}) · {Rating} ({N reviews}) · **Sources:** {source list}
```

### Google Maps links:
- **ALWAYS:** `https://www.google.com/maps/search/{Name+City}`
- **ALWAYS** include street address as fallback
- **NEVER** use coordinate URLs or `/place/` URLs

### Rules:
- NO labels (strong pick / solid / speculative) — sorting does the job
- NO comparisons to reference restaurants (no "like X", "closer to X than Y")
- NO flowery prose in Overview (no painting a scene — just facts)
- NO "what to order" (user prefers discovery)
- NO italic (unreadable in terminal)
- NEVER start a line with `~` (renders as strikethrough in Claude Code). Use "EUR XX-YY" or "approx." instead
- Google Maps link + rating in one line at the end of card (don't duplicate)
- `---` between cards
- Est. year only if known, don't guess
- For home city: include neighbourhood + distance from home address

### After delivering response:
1. Save as `recommendations/{city}-{type}-YYYY-MM-DD.md` — silently via Bash (no diffs in IDE)
2. Update `cities/{city}.md` cache — silently via Bash (no diffs in IDE)
3. Last line of chat: link to saved .md file

**Always end with the .md file link** — every response (find, record, analyze) must finish with a link to the saved/updated file.

### Before outputting, cross-check each candidate against:
- feedback-log (already visited? what rating?)
- saved-places-data (in Favorites? in Want to go?) — if connected
- cities/{city}.md cache (previously recommended?)

---

## Record a visit

Read feedback-log.md first. Ask in ONE message (not one by one):
- Place name, city, rating /10

Optional (extract from context if given): what ordered, what worked/didn't, would return, company, source.

Use the rating scale and entry format defined in feedback-log.md.

If the place already exists in feedback-log.md (e.g. from onboarding or a previous visit), add a new dated entry — it's a revisit, not a duplicate. Multiple entries per place are expected and help track taste evolution.

After recording:
1. Recalculate statistics in feedback-log.md (total visits, average rating, power spots, best source)
2. Update cities/{city}.md silently
3. If 10/10 → suggest adding to taste-profile references

---

## Analyze Preferences

Read: feedback-log.md (all), taste-profile.md, all cities/*.md.

1. **Statistics:** total visits, average rating, distribution by city/type/axis, best source
2. **High-rating patterns (8-10):** what's common — type, size, axis, cuisine, design words in pros
3. **Low-rating patterns (1-5):** what's common — cons words, venue types that fail, cities that fail
4. **Compare with profile:** what's confirmed, what's new, what's questionable
5. **Propose updates** to taste-profile.md — show to user, wait for confirmation
6. **Recalculate statistics** in feedback-log.md
7. **Report:** summary with key findings

Never change profile without explicit user confirmation.

---

## Onboarding

**Trigger:** config.yml is missing, OR taste-profile.md is empty/missing/contains only template placeholders, OR required blocks are incomplete (Reference restaurants section is empty).

**Goal:** Build a complete taste profile through a guided conversation. Ask questions in blocks (batch), not one by one. User answers in free text.

**Before starting:** tell the user what this is ("I'll set up your restaurant recommendation profile"), that it takes ~20 min for the full version or ~10 min for the essentials, and that they can skip blocks to fill in later.

### Block 1: Setup (required)

Ask all at once:
- What city do you live in? Street address (for distance calculations in recommendations)
- Who do you usually dine with? (partner, friends, solo, mix)
- Budget: is there a ceiling, or no limit if the place is worth it?
- Any diet restrictions or allergies?
- What are restaurants to you? (hobby, lifestyle, occasional treat, social ritual?)
- Do you save restaurants somewhere? (Google Maps lists, Apple Maps, a spreadsheet, etc.) If yes — we can connect your saved places for smarter recommendations. If not — no problem, we'll work with web sources.

**After this block:** ask the user where to store restaurant data (suggest `~/Documents/restaurant-data`). Create `config.yml` at `~/.claude/skills/restaurant/config.yml` with home_city, home_address, data_dir, saved_places_source. Create the data directory. If user has saved places → ask them to export/share the data and save as `saved-places-data.md` in the data directory. Write initial taste-profile.md and feedback-log.md (from templates) in data_dir. Fill the Who section in taste-profile.md.

### Block 2: Cuisines & taste (required)

Ask all at once:
- What are your top 3 favourite cuisines?
- Any cuisines or ingredients you actively avoid?
- Name 2-3 comfort dishes — the ones you'd eat any time, anywhere
- How do you feel about: spicy food? offal? raw fish/meat? seafood?

**After this block:** update taste-profile.md with Cuisine section.

### Block 3: Food philosophy (recommended)

Ask all at once:
- What matters more to you: the quality of the product itself, or the creative concept/presentation?
- Do you prefer places you'd return to regularly, or one-time "wow" experiences?
- Sharing plates or individual dishes?
- Does seasonality matter to you (seasonal menu vs stable menu)?

**After this block:** update taste-profile.md with Food philosophy in Taste Compass.

### Block 4: Atmosphere & drinks (recommended)

Ask all at once:
- What kind of room do you enjoy? (bar counter, intimate/small, noisy bistro, grand hall, terrace, doesn't matter)
- How important is interior design/aesthetics?
- Wine: do you drink wine? Any preferences? (natural, classic, red vs white, by the glass vs bottle)
- Cocktails: do you drink cocktails? What kind of bar do you enjoy?
- Coffee: specialty/third wave, or just caffeine?
- What style of service do you enjoy? (invisible professional, friendly/chatty, chef comes to the table)

**After this block:** update taste-profile.md with Atmosphere, Wine, Cocktails, Coffee, Service sections.

### Block 5: Anti-patterns (recommended)

Present this checklist — ask user to mark what kills it for them and add their own:
- [ ] Tourist trap (menu in 5 languages, food photos, touts)
- [ ] Fine dining protocol (crumb sweeper, long explanations, ritual)
- [ ] Hype > substance (cool concept, mediocre food)
- [ ] Corporate chain (neither here nor there)
- [ ] Scene place (beautiful people, food secondary)
- [ ] Adapted ethnic cuisine (toned down for local palate)
- [ ] Techno-avant-garde (one-time wow, no desire to return)
- [ ] Other: ___

Then ask: "Can you give an example of a disappointing restaurant experience? What specifically ruined it?"

**After this block:** update taste-profile.md with Anti-patterns section.

### Block 6: Reference restaurants (required)

This is the most important block — calibration.

Ask:
- "Name 5-10 restaurants you love. For each: name, city, type of cuisine, your rating /10, and in one sentence — why you love it."
- "Now name 2-3 places that disappointed you. What went wrong?"

**After this block:** update taste-profile.md Reference restaurants section. Add all entries to feedback-log.md (use "--" for unknown fields like Ordered, Source, Notes).

### Block 7: Ritual & sources (recommended)

Ask all at once:
- One restaurant per evening, or do you like planning a route (dinner → bar → etc.)?
- Do you book ahead or go spontaneous?
- Would you travel 30+ min outside the city for a great restaurant?
- Are you constantly exploring new places, or do you prefer returning to your favorites?
- Does your dining change with seasons? (e.g. terraces and light food in summer, hearty dishes in winter)
- Where do you look for restaurant tips? (Reddit, Michelin, friends, food critics, blogs, etc.)
- Any sources you actively distrust? (TripAdvisor, Yelp, Instagram, etc.)

**After this block:** read `local-critics.md` for the user's home country. Present relevant local critics and ask which ones the user trusts or follows. Update taste-profile.md with Evening ritual and Sources sections (including confirmed local critics).

### After all blocks:

1. Show the assembled profile to the user: "Here's your taste profile. Review it — anything to change, add, or remove?"
2. Wait for confirmation
3. Save final taste-profile.md
4. Create empty cities/ and recommendations/ directories
5. Confirm: "Setup complete. Try: `/restaurant [city] [mood/cuisine]`"

### Skipped blocks:

If user skips blocks 3-5 or 7:
- Mark those sections in taste-profile.md with `[SKIPPED]` on the first line under the section header (distinct from template HTML comments)
- After 3-5 recorded visits, prompt: "You've rated a few places now. Want to fill in [skipped section] to make recommendations more precise?"

### Profile evolution:

The taste profile grows over time. After each "analyze" → propose updates. After visiting a new city → prompt to add neighbourhood map and city quirks to taste-profile.md. After a 10/10 visit → suggest adding to reference restaurants. Never change profile without explicit user confirmation.
