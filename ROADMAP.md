# Plan: Future Iterations for /restaurant skill

## Context

v0.9 public beta shipped (github.com/kirvahe/restaurant-skill). 8 files, ~1,700 lines. Before closing the project, need a roadmap for two axes: (1) quality — making recommendations better, (2) scalability — making the skill easier to distribute, adapt, and extend.

## Axis 1: Quality — making recommendations better

### 1.1 Calibration loop
**Problem:** Onboarding captures initial taste, but the profile doesn't auto-update from visit patterns.
**Iteration:** After every 5th recorded visit, auto-run lightweight "analyze" and propose 1-2 profile tweaks. Not a full analysis — just "you've rated 4 Italian places 9+, but Italian isn't in your Top tier. Want to promote it?"

### 1.2 Recommendation debrief
**Problem:** No feedback loop on recommendations themselves. Did you go? Did it work?
**Iteration:** After recommending, save candidate list. 2 weeks later (or next session), ask: "Did you try any of these? How was it?" This closes the loop and feeds feedback-log automatically.

### 1.3 Wine integration
**Problem:** Wine is in the taste profile but not in the search methodology. No wine-bar-specific search patterns.
**Iteration:** Add wine-specific search rules: natural wine directories (Raisin, Raw Wine maps), sommelier-led lists, wine bar vs wine restaurant distinction. Wine pairing context in cards.

### 1.4 Negative calibration
**Problem:** Anti-patterns are binary (kills it / doesn't). No nuance.
**Iteration:** Weighted anti-patterns from visit history. If user consistently rates "scene places" 6-7 (not terrible), soften the filter. If "adapted ethnic" always gets 4-5, harden it.

### 1.5 Seasonal recommendations
**Problem:** Seasonality exists in profile but doesn't influence search queries.
**Iteration:** Detect current month → adjust search (terrace queries in summer, hearty/stew queries in winter). Seasonal menu restaurants surfaced when relevant.

### 1.6 City learning
**Problem:** First search in a new city is cold — no neighbourhood map, no quirks.
**Iteration:** After 3+ visits in a city, auto-generate neighbourhood map and city quirks from visit patterns. "You've been to Kreuzberg 3 times — marking it as your zone for casual dining."

### 1.7 Source credibility tracking
**Problem:** All sources weighted equally. Reddit tip could be gold or garbage.
**Iteration:** Track which sources led to high-rated visits. After 20+ visits: "Reddit-sourced places average 8.2, Michelin-sourced average 7.1 for you." Adjust search priority accordingly.

## Axis 2: Scalability — distribution, adaptation, extension

### 2.1 One-command install
**Problem:** Current install = 3 cp commands. Works but not zero-friction.
**Iteration:** Install script (`install.sh`) or `npx`-style one-liner. Detects OS, creates dirs, copies files, validates Claude Code setup.

### 2.2 Skill marketplace readiness
**Problem:** Not in any Claude Code skill registry/marketplace.
**Iteration:** Add metadata for skill discovery: tags, category, screenshots of output, version field. Track marketplace requirements as they emerge.

### 2.3 MCP server independence
**Problem:** Requires specific web search MCP. Different users have different MCPs.
**Iteration:** Abstract search layer — detect available MCP (Exa, Firecrawl, or any web search tool) and adapt queries. Graceful fallback if no web search available (use only saved places + feedback-log). ✓ Shipped in v1.0.

### 2.4 Multi-user profiles
**Problem:** One profile per install. Couples with different tastes can't share.
**Iteration:** Named profiles in config.yml (`profiles: [kirvahe, nastya]`). Switch with `/restaurant --profile nastya`. Shared feedback-log with per-profile ratings.

### 2.5 Skill template framework
**Problem:** The pattern (taste profile + onboarding + search + record + analyze) is reusable but locked to restaurants.
**Iteration:** Extract the pattern into a generic "taste skill" template. Apply to: hotels (already exists as /hotel), coffee shops, wine shops, bookstores. Template: `SKILL-TEMPLATE.md` with placeholders for domain-specific sections.

### 2.6 Local critics as a service
**Problem:** local-critics.md is a static snapshot. Food critics change, publications close.
**Iteration:** Version local-critics.md with a "last verified" date per country. Annual refresh cycle. Community contributions via PR. Potentially split into per-country files for easier maintenance.

### 2.7 Google Maps sync automation
**Problem:** Saved places integration requires manual export.
**Iteration:** Google Takeout automation guide. Or: MCP tool that reads Google Maps saved lists directly. Apple Maps equivalent for iOS users.

### 2.8 Exportable recommendations
**Problem:** Recommendations saved as .md files. Not shareable in a social way.
**Iteration:** Generate shareable HTML cards or Google Maps list links. "Share this recommendation set with a friend" → exports a mini-page or a Google Maps list.

### 2.9 i18n
**Problem:** SKILL.md instructions and output format are English-only. Onboarding questions are English.
**Iteration:** Detect user's language from Block 1 answer. Adjust onboarding questions and output language. SKILL.md stays English (it's for Claude, not the user), but user-facing text adapts.

### 2.10 Analytics dashboard
**Problem:** "Analyze" is text-only. No visual patterns.
**Iteration:** Generate an HTML dashboard with charts: ratings over time, cuisine distribution, city map of visits, source effectiveness. Save as `analytics/dashboard-YYYY-MM.html`.

## Priority matrix

| Iteration | Impact | Effort | Priority |
|---|---|---|---|
| 1.1 Calibration loop | High | Low | **v1.0 ✓** |
| 1.2 Recommendation debrief | High | Medium | **v1.0 ✓** |
| 2.1 One-command install | Medium | Low | **v1.0 ✓** |
| 2.3 MCP independence | High | Medium | **v1.0 ✓** |
| 1.5 Seasonal recs | Medium | Low | v1.1 |
| 1.6 City learning | Medium | Medium | v1.1 |
| 2.5 Skill template | High | High | v1.1 |
| 2.6 Local critics refresh | Medium | Medium | v1.1 |
| 1.3 Wine integration | Medium | Medium | v1.2 |
| 1.7 Source credibility | High | Medium | v1.2 |
| 2.4 Multi-user profiles | Medium | Medium | v1.2 |
| 2.7 Google Maps automation | Medium | High | v1.2 |
| 1.4 Negative calibration | Low | Medium | v2.0 |
| 2.2 Marketplace readiness | Medium | Low | when available |
| 2.8 Exportable recs | Low | Medium | v2.0 |
| 2.9 i18n | Medium | High | v2.0 |
| 2.10 Analytics dashboard | Low | High | v2.0 |

## v1.0 (shipped)
- ✓ Calibration loop (1.1)
- ✓ Recommendation debrief (1.2)
- ✓ One-command install (2.1)
- ✓ MCP server independence (2.3)
- ✓ Error handling / resilience section
- ✓ Intent-based routing (replaces keyword matching)
- ✓ SKILL.md simplified from 366 → 260 lines

## v1.1 target (next iteration)
- Seasonal recommendations (1.5)
- City learning (1.6)
- Local critics refresh process (2.6)
- Skill template framework (2.5)
