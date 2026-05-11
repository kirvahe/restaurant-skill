# Onboarding Blocks

The full block-by-block onboarding protocol. Loaded only when running first-time setup or filling in skipped sections later.

## Trigger conditions

Run onboarding when ANY of:

- `~/.claude/skills/restaurant/config.yml` is missing
- `taste-profile.md` is empty / missing / contains only template placeholders
- A required block is incomplete (Block 1, Block 2, or Block 6)

Required blocks are 1, 2, and 6. Others are optional and can be filled later.

## Format

Ask questions in **blocks (batched)**, not one by one. User answers in free text. Tell user: "It takes ~10 min for essentials, ~20 min full. Blocks can be skipped and filled later."

## Blocks

| Block | Required? | Topic | Key questions | After block |
|---|---|---|---|---|
| 1 | **Yes** | Setup | City, address, companions, budget, diet, restaurants-as-hobby, saved places source | Create config.yml, data_dir, initial files. If saved places → ask user to export/share data |
| 2 | **Yes** | Cuisines | Top 3 cuisines, avoid list, 2-3 comfort dishes, spicy/offal/raw/seafood preferences | Update taste-profile.md Cuisine section |
| 3 | No | Food philosophy | Product vs concept, returnability, sharing plates, seasonality | Update Taste Compass |
| 4 | No | Atmosphere & drinks | Room type, design, wine, cocktails, coffee, service style | Update Atmosphere/Wine/Cocktails/Coffee/Service |
| 5 | No | Anti-patterns | Present checklist from taste-profile-template.md. Ask for a disappointing experience example | Update Anti-patterns |
| 6 | **Yes** | Reference restaurants | 5-10 loved places (name, city, cuisine, /10, why). 2-3 disappointing places (what went wrong) | Update References. Add all to feedback-log.md (use "--" for unknown fields, approximate date or "--" for Date, "(historical)" in Notes) |
| 7 | No | Ritual & sources | Evening format, booking style, travel distance, new vs familiar, seasonality, trusted/distrusted sources | Read local-critics.md for home country. Update Evening ritual + Sources |

## Before Block 6

Show the rating scale + decimal rule (see `visit-protocol.md`) so the user calibrates consistently from the start.

## After all blocks

1. Show a summary of the assembled profile (key points, not full file) — ask user to review
2. Wait for confirmation, save final taste-profile.md
3. Create cities/ and recommendations/ directories
4. Confirm: "Setup complete. Try: `/restaurant [city] [mood/cuisine]`"

## Skipped blocks

Mark skipped sections with `[SKIPPED]` in `taste-profile.md`. After 3-5 new visits post-onboarding (not counting Block 6 historical entries), prompt to fill in skipped sections.
