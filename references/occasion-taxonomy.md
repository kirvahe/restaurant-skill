# Occasion Taxonomy

The same person has radically different restaurant needs depending on the occasion. This taxonomy makes occasion a first-class input to ranking, not an afterthought applied as a filter at the end.

## Why this exists

Three convergent observations:

1. **Booking.com "travel hats"** — same user wears different "hats" each session (husband on romantic vacation vs businessman). Personalization that ignores this produces context-mismatched recommendations.
2. **Spotify Daylist** — taste is not a single point but a distribution over context. Daylist achieves 70% weekly return by combining microgenre + time/day signal.
3. **iFood Candunga** — context (meal shift, day, season) is a first-class personalization signal, not a downstream filter. Combining content + context outperforms each alone.

For restaurants, an "Italian dinner" recommendation that doesn't account for whether it's solo Tuesday lunch vs anniversary dinner produces the wrong place even when the cuisine is right.

## The Seven Occasions

| Occasion | Definition | Ranking modifier |
|---|---|---|
| **date** | Romantic dinner with partner; conversation-friendly required | Down-weight loud places, counter-only formats; up-weight design + ambiance + reservation availability |
| **solo** | Eating alone; counter or small table; can be lunch or dinner | Up-weight counter formats, walk-in availability, single-portion friendliness; down-weight tasting-menu-only and large-table formats |
| **group** | 4+ people; sharing format preferred; reservation usually needed | Up-weight large tables, sharing menus, noise tolerance; down-weight tiny rooms (<8 seats), counter-only |
| **celebration** | Anniversary, birthday, milestone — occasion-worthy required | Up-weight memorability + service warmth + interior; tolerate higher price; deprioritize "casual neighborhood spot" |
| **quick** | Time-constrained meal; under 75 minutes total; not a destination | Up-weight walk-in, fast service, near-current-location; down-weight tasting menus + reservation-only |
| **explorer** | Travel mode; exploring a new city or neighborhood; willing to detour | Up-weight unique-to-this-city formats, hidden gems, off-the-beaten-path; tolerate inconvenience |
| **impress-local** | Eating with someone from this city who has high standards (e.g., a local food friend) | Up-weight insider picks, places without tourist trace, chef-cited spots local would respect |

## Inference Rules — Detect Don't Ask

Inspect the user's query for occasion signals BEFORE asking. Ask only when genuinely ambiguous.

### Inference signals

| Signal in query | Inferred occasion |
|---|---|
| "with wife / Nastya / couple / for two / anniversary" | date or celebration (further disambiguation: anniversary/birthday → celebration; default → date) |
| "alone / solo / by myself / lunch break" | solo |
| "for 4 / 5 / 6 / group / friends visiting / company dinner" | group |
| "tonight before [event] / quick / fast / before train / lunch in 1 hour" | quick |
| "in [city we don't live in] / weekend trip / visiting / first time in" | explorer (default for travel queries) |
| "showing [name] around / impress / they know food / local foodie" | impress-local |
| Generic "where to eat in X" with no context | use city + time-of-day defaults; if ambiguous after that, ask one short question |

### When to ask

If the inference is genuinely 50/50 (e.g., "восemь вечера в Чамбери" — could be casual solo or planned date), ask ONE short question:

> Это под какой контекст? (1) спокойно вдвоём, (2) быстрый перекус, (3) исследую район?

Three named options, no jargon, request-language. If user picks none, default to most-likely (solo for weekday, date for Friday/Saturday evening).

## Ranking modifier as composition, not filter

Modifiers above are composed into the candidate score, not used as hard filters (except where structurally incompatible — e.g., a tasting-menu-only place can't satisfy `quick`).

## Output convention

The Overview line at the top of every recommendation output should explicitly state the inferred occasion (one short phrase) so the user knows what frame the recommendations were built around:

```markdown
## Overview

**Occasion:** date dinner in Chamberí (Friday evening, ambiance + reservation prioritized)
...
```

If the user disagrees with the inferred occasion, they can correct it and the search re-runs with the right modifier.

## Multi-occasion contexts

Some queries blend occasions ("celebrate Nastya's birthday with our friends" = celebration + group). Apply both modifier sets and composite. Up-weights stack; down-weights take the most restrictive.

Travel queries (city != home_city) default to `explorer` unless the query has an explicit occasion signal — exploration is the usual reason for being there.
