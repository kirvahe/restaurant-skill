# /restaurant — Claude Code Skill

A restaurant recommendation skill for Claude Code. Finds restaurants, bars, wine bars, and cocktail bars that match your personal taste profile.

**What it does:**
- Searches trusted sources (Reddit, Michelin, Eater, local critics) in multiple languages
- Filters through your taste profile, anti-patterns, and dining history
- Outputs structured recommendation cards with addresses, prices, and Google Maps links
- Records and analyzes your visits over time to improve recommendations

## Quick Start

### 1. Install the skill

```bash
mkdir -p ~/.claude/skills/restaurant
cp SKILL.md ~/.claude/skills/restaurant/SKILL.md
cp local-critics.md ~/.claude/skills/restaurant/local-critics.md
```

### 2. Run onboarding

Open Claude Code and type:

```
/restaurant
```

Claude will detect that the skill is not configured and start the onboarding conversation. It asks questions in batches:

| Block | Topic | Time | Required? |
|---|---|---|---|
| 1 | City, companions, budget, diet, saved places | ~2 min | Yes |
| 2 | Cuisines, comfort dishes, ingredients | ~3 min | Yes |
| 3 | Food philosophy (product vs concept, returnability) | ~3 min | Recommended |
| 4 | Atmosphere, wine, cocktails, coffee, service | ~3 min | Recommended |
| 5 | Anti-patterns (what kills a restaurant for you) | ~2 min | Recommended |
| 6 | Reference restaurants (5-10 places you love) | ~5 min | Yes |
| 7 | Evening ritual, booking style, trusted sources | ~2 min | Recommended |

You can skip blocks 3-5, 7 and fill them later. Minimum setup: blocks 1 + 2 + 6 (~10 min). Full setup: ~20 min.

Onboarding creates all necessary files and folders automatically.

### Alternative: Manual setup

If you prefer to fill the profile by hand instead of going through onboarding:

```bash
mkdir -p ~/Documents/restaurant-data
cp taste-profile-template.md ~/Documents/restaurant-data/taste-profile.md
cp feedback-log-template.md ~/Documents/restaurant-data/feedback-log.md
```

Then create `~/.claude/skills/restaurant/config.yml`:

```yaml
home_city: Berlin          # your city from onboarding
home_address: "Kastanienallee 7"
data_dir: "/Users/yourname/Documents/restaurant-data"
saved_places_source: none  # or google_maps / apple_maps
```

Fill in `taste-profile.md` — replace HTML comments with your answers.

## Requirements

- **Claude Code** with skill support
- **Web search** — the skill needs to search Reddit, Google, and food critic sites. Make sure you have a web search MCP server configured (Brave Search, Tavily, Exa, or similar)

## Usage

```
/restaurant Madrid sushi          # find sushi in Madrid
/restaurant Paris wine bar        # find a wine bar in Paris
/restaurant                       # Claude asks what you need
```

**Record a visit:**
```
> went to Septime in Paris, 9/10
```

**Analyze patterns:**
```
> analyze my restaurant preferences
```

## File structure

```
~/.claude/skills/restaurant/
  SKILL.md                     # Skill definition (search rules, output format, onboarding)
  local-critics.md             # Editorial food sources by country (30 countries, 750+ entries)
  config.yml                   # Home city, address, settings (created during onboarding)

~/Documents/restaurant-data/   # Your data (path configured in config.yml)
  taste-profile.md             # Your taste profile
  feedback-log.md              # Visit log with ratings
  cities/                      # City recommendation caches
    madrid.md
    paris.md
  recommendations/             # Saved recommendation outputs
    madrid-sushi-2026-03-20.md
  saved-places-data.md         # Optional: exported saved places
```

## How it improves over time

- Every visit you record helps calibrate future recommendations
- After 3-5 visits, Claude suggests filling in skipped profile sections
- After visiting a new city, Claude prompts you to add neighbourhood notes
- After a 10/10 visit, Claude suggests adding it to your reference restaurants
- Running "analyze" periodically finds patterns and proposes profile updates

## Credits

Built on top of hard-won search patterns, taste calibration methods, and output formats refined over months of real-world use.
