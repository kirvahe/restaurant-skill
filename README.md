# /restaurant — Claude Code Skill

A personalized restaurant recommendation engine that lives inside Claude Code. Builds a taste profile through conversation, then searches 30 countries of editorial sources to find places that actually match how you eat.

For people who take restaurants seriously but are tired of TripAdvisor scores and Instagram hype.

## Why this exists

Generic restaurant recommendations fail because they optimize for the average visitor. You are not the average visitor. You have specific opinions about cuisine, atmosphere, wine, and what kills an evening.

This skill solves that by maintaining a persistent taste profile — your cuisine hierarchy, anti-patterns, reference restaurants, trusted sources — and applying it every time you search. It searches Reddit diaspora communities in 3 languages, cross-references editorial critics specific to each country, and filters results through your personal calibration. The more you use it, the better it gets.

## What it does

- **Find** — searches trusted editorial sources (Reddit, Michelin, Eater, 30 countries of local critics) in up to 3 languages per query
- **Filter** — every result passes through your taste profile, anti-patterns, and dining history before you see it
- **Record** — log visits with /10 ratings, building a feedback loop that sharpens future recommendations
- **Analyze** — periodic pattern analysis reveals what actually drives your ratings and proposes profile updates
- **Evolve** — the profile grows with every visit, every new city, every 10/10 discovery

## Who is this for

Anyone who uses Claude Code and cares about where they eat. The skill is city-agnostic (tested across Madrid, Paris, Berlin, Tokyo, Bangkok, and more) and cuisine-agnostic. It works best if you:

- Have opinions about food beyond "is it good"
- Visit restaurants regularly (couple, friends, or solo)
- Want recommendations backed by editorial sources, not crowd averages
- Are willing to spend 20 minutes on onboarding to calibrate the system

## Quick Start

### 1. Install

```bash
git clone https://github.com/kirvahe/restaurant-skill.git && cd restaurant-skill && ./install.sh
```

Or manually:
```bash
mkdir -p ~/.claude/skills/restaurant
cp SKILL.md ~/.claude/skills/restaurant/SKILL.md
cp local-critics.md ~/.claude/skills/restaurant/local-critics.md
```

### 2. Run onboarding

```
/restaurant
```

Claude detects the skill is unconfigured and starts a guided conversation. Questions come in batches, not one by one:

| Block | Topic | Time | Required? |
|---|---|---|---|
| 1 | City, companions, budget, diet, saved places | ~2 min | Yes |
| 2 | Cuisines, comfort dishes, ingredients | ~3 min | Yes |
| 3 | Food philosophy (product vs concept, returnability) | ~3 min | Recommended |
| 4 | Atmosphere, wine, cocktails, coffee, service | ~3 min | Recommended |
| 5 | Anti-patterns (what kills a restaurant for you) | ~2 min | Recommended |
| 6 | Reference restaurants (5-10 places you love) | ~5 min | Yes |
| 7 | Evening ritual, booking style, trusted sources | ~2 min | Recommended |

Minimum setup: blocks 1 + 2 + 6 (~10 min). Full setup: ~20 min. Skip blocks 3-5, 7 and fill them later.

Onboarding creates all files and folders automatically.

## Requirements

- **Claude Code** with skill support
- **Web search MCP server** (Exa, Firecrawl, Brave Search, or similar) — the skill auto-detects available search tools. Works best with web search, but has a degraded mode without it.

## Usage

**Find a spot:**
```
/restaurant Madrid sushi
/restaurant Paris wine bar
/restaurant Bangkok street food
/restaurant                       # Claude asks what you need
```

**Record a visit:**
```
went to Septime in Paris, 9/10
```

**Analyze patterns:**
```
analyze my restaurant preferences
```

## How it works

The skill operates in three modes (find, record, analyze), routed by what you type.

**Search methodology (find mode):**
1. Reads your taste profile before every recommendation
2. Determines target city's country, selects local editorial sources from a 31-country database
3. Searches in up to 3 languages (country + English + cuisine language)
4. Runs Reddit queries across city subs, diaspora communities, and cuisine subs
5. Builds an anti-recommendation blacklist before selecting candidates
6. Cross-checks candidates against your feedback log and saved places
7. Outputs 2-5 structured cards sorted by relevance, saves to file

**Country-specific intelligence:**
- Dominant local platforms override general search in Japan (Tabelog), South Korea (Blue Ribbon Survey), Thailand (Wongnai), Hong Kong (OpenRice), Singapore (Makansutra)
- 31-country editorial database with named critics, publications, and guides (local-critics.md)
- Diaspora search pattern mandatory for ethnic cuisines — the diaspora knows authenticity better than locals

**Quality rules:**
- Google Maps rating shown but never used as a filter (3.7-rated places can be 9/10)
- Better 2 strong picks than 3 mediocre ones — every recommendation needs a clear story
- No labels, no comparisons to your reference restaurants, no "what to order"

### Alternative: Manual setup

If you prefer to fill the profile by hand instead of onboarding:

```bash
mkdir -p ~/Documents/restaurant-data
cp taste-profile-template.md ~/Documents/restaurant-data/taste-profile.md
cp feedback-log-template.md ~/Documents/restaurant-data/feedback-log.md
```

Create `~/.claude/skills/restaurant/config.yml`:

```yaml
version: "1.0"
home_city: Berlin
home_address: "Musterstrasse 42"
data_dir: "/Users/yourname/Documents/restaurant-data"
saved_places_source: none  # or google_maps / apple_maps
```

Fill in `taste-profile.md` — replace HTML comments with your answers.

## File structure

```
~/.claude/skills/restaurant/
  SKILL.md                     # Skill definition (search rules, output format, onboarding)
  local-critics.md             # Editorial food sources by country (31 countries, 180+ sources)
  config.yml                   # Home city, address, settings (created during onboarding)

~/Documents/restaurant-data/   # Your data (path configured in config.yml)
  taste-profile.md             # Your taste profile
  feedback-log.md              # Visit log with ratings
  cities/                      # City recommendation caches
  recommendations/             # Saved recommendation outputs
  saved-places-data.md         # Optional: Google Maps / Apple Maps export
```

## How it improves over time

The taste profile is not static. It grows through use:

- Every visit you record recalibrates future recommendations
- After 3-5 visits, Claude suggests filling in skipped profile sections
- After visiting a new city, Claude prompts you to add neighbourhood notes and city quirks
- After a 10/10 visit, Claude suggests adding it to your reference restaurants
- Running "analyze" periodically finds patterns in your ratings and proposes profile updates
- No profile changes happen without your explicit confirmation

## What's included

| File | Lines | Purpose |
|---|---|---|
| SKILL.md | 260 | Core skill: search rules, output format, onboarding, resilience |
| local-critics.md | 778 | Editorial food sources for 31 countries (named critics, publications, platforms) |
| taste-profile-template.md | 146 | Empty taste profile with all sections and guidance comments |
| feedback-log-template.md | 71 | Visit log template with rating scale and entry format |
| cities-template.md | 17 | Template for city recommendation caches |
| install.sh | 95 | One-command installer with --uninstall support |

## Credits

Built on search patterns, taste calibration methods, and output formats refined over months of real-world use across multiple cities and cuisines.

## License

MIT
