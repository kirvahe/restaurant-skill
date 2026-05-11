# Hidden Gems Mandate

Every recommendation output reserves a slot for an under-the-radar candidate. This is a deliberate counter to the popularity-bias dynamics inherent in recommendation systems.

## Why this exists

Three convergent findings:

1. **Popularity bias is universal** — 2024 academic survey (Springer 2024) shows recommender systems reliably over-recommend already-popular items, creating self-reinforcing loops. The most-recommended restaurant in a city is often the worst recommendation for a returning traveler with strong taste.
2. **Filter bubble compounding** — when the user has well-developed taste (the case here), the easiest path is to keep recommending similar places. Filter bubble risk is intra-user, not inter-user.
3. **User feedback alignment** — the user's "fire in eyes not polished" preference directly maps to under-the-radar discoveries. Los Fueros (Bilbao 9/10) was an off-cache discovery that 4 prior search rounds missed precisely because the heritage-revival angle wasn't surfaced through standard ranking.

Mandating one hidden gem per output forces the search to look beyond the obvious convergent picks.

## The Rule

Every output with 3+ recommendations must include AT LEAST one slot explicitly labeled as a hidden gem. For outputs of exactly 3 picks, this is one slot. For 5 picks, can be 1-2 slots.

## Selection Criteria — City-Relative

A "hidden gem" is defined relative to the city's restaurant density, not absolutely:

| City type | Review-count threshold for "low" |
|---|---|
| Major capital (Madrid, Barcelona, Paris, NYC) | <500 reviews |
| Mid-size (Bilbao, Lisbon, Belgrade) | <200 reviews |
| Smaller (Yerevan, Marbella, Tarifa) | <100 reviews |

In all cases, "low review count" is the bottom 25th percentile of comparable venues (same city, similar cuisine/format). When a TSV cache exists for the city, this can be derived from the data. When it doesn't, use rough thresholds above.

The candidate must ALSO have a strong editorial signal:
- Mentioned in a trusted source (any [A] or [B] tier source per `source-confidence.md`)
- OR cited in a chef interview / Eater / Infatuation hit list / local food critic
- OR off-cache discovery from a deep search (a place that came up in research but was excluded from prior searches for axis mismatch)

A "hidden" place with no editorial signal is just an unknown — that's not the goal.

## Fallback when review counts unavailable

When review counts can't be retrieved (search happened without TSV cross-check, or new city without data), use the **editorial-source-rare** proxy:

- A candidate mentioned in fewer than 2 editorial sources (vs the convergent picks mentioned in 3+) = "editorial-source-rare" hidden gem
- This catches places that fly below the editorial radar even if their Maps review count isn't known

## Output labeling

In the output, the hidden gem slot is explicitly labeled:

```markdown
## Recommendations

### 1. {Convergent pick — high tier, likely top of every list}
...

### 2. {Strong second pick}
...

## Hidden Gem (under-the-radar slot)

### 3. {Place with low review count + editorial signal}
> ... · GM 4.2 (87 reviews) · **Sources:** [B] Eater Madrid 2025 — "untouched neighborhood gem"
> Hidden because: locals' lunchtime spot, no English menu, no reservations
```

The "Hidden because:" line is required — it makes the editorial reasoning explicit so the user can decide if the under-the-radar nature is desirable for their occasion.

## When NOT to apply this rule

Skip the hidden gem slot when:

- The user explicitly requests "safe / known / proven" only
- The output is for a celebration / once-in-a-lifetime context where exploration appetite is low
- Round 2+ of a multi-round search where prior rounds already exhausted the obvious picks (the entire round is now exploration territory; one of the candidates being labeled "hidden gem" is redundant)

In all these cases, document the skip in the Overview line: "No hidden-gem slot — request was for safe picks only."

## Implementation note

This is a constraint on output composition, not a re-ranking. Rank all candidates normally; AFTER ranking, allocate one slot to the highest-ranked candidate that passes the low-review-count + editorial-signal threshold. Quality preserved, popularity-loop broken.
