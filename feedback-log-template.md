# Feedback Log

*Last analysis: —*
*Scale: /10 (one decimal required on the 9.0+ tier; .5 increments allowed mid-tier)*

---

## Rating scale

Tiers are defined by behaviour signals, not by fixed reference places. Full definitions: `references/visit-protocol.md`.

| Rating | Meaning |
|---|---|
| **10** | Power spot — return mandatory, would travel specifically for it. Rare |
| **9** | Strong peak, no disconfirm — goes regularly or wants to |
| **8** | Return mandatory + at least one clear strength |
| **7** | Would go again if convenient — solid, no spark |
| **6–6.5** | Passable — fallback only |
| **5 and below** | Real disappointment |

---

## Entry format

```
### {Name} — {City} | {N.M}/10 | visited {X} · logged {YYYY-MM-DD}
- Type: {format/cuisine}
- Peak: {one specific moment that defined the meal in memory}
- End: {how it closed — last dish, coffee, farewell, the bill experience}
- Disconfirm: {what didn't work / what could be better; "—" only if truly nothing}
- Axis: {food / food + wine / food + atmosphere / food + concept / etc.}
- Context: {absolute / rural / neighbourhood / expectation-adjusted / constrained / composite / format-adjusted / occasion-specific / memory}
- Company: {couple / friends (N) / solo / colleagues}
- Ordered: {the actual dishes, named}
- Return: {yes mandatory / yes situational + context / maybe / no}
- Source: {chef / Reddit / want-to-go / walk-in / recommendation / ...}
- Notes: {address + neighbourhood, anything else}
```

`visited` is when the meal happened, `logged` is when it was written down. `visited` accepts a date (`YYYY-MM-DD`), a month (`YYYY-MM`), an approximation (`~YYYY-MM`), `ongoing (regular)`, or `unknown` — never reuse the logging date as a guess. `Context` records what the rating was measured against; see `references/visit-protocol.md` for the frames.

---

## Visits

<!-- Entries go here. Example:

### Septime — Paris | 9.0/10 | visited 2026-01 · logged 2026-01-15
- Type: neo-bistro
- Peak: seasonal tasting menu where every plate made sense
- End: unhurried last glass from a deep natural wine list
- Disconfirm: —
- Axis: food + wine
- Context: absolute
- Company: couple
- Ordered: tasting menu + wine pairing
- Return: yes mandatory
- Source: friends
- Notes: Book 3 weeks ahead minimum. Lunch is easier to get than dinner.

-->

---

## Reference

<!-- Refreshed after each visit or analysis. Lookups only — no log-wide average, no by-city/by-axis/by-type distributions. Format:

- **Power spots (10/10):** —
- **Strong (8.5–9):** —
- **Best source:** — (which sources produced the highest-rated visits)
- **Context frames:** — (entries per frame, e.g. `absolute` (0) · `neighbourhood` (0) · `rural` (0))
- **Provenance:** — (`scale-converted` / `manually corrected` / `carried-over` entries, if any)

-->

### Why there is no average

A log-wide average pools ratings given in different `Context` frames — a 7 meaning "disappointing for a starred place" and a 7 meaning "a pleasant surprise for a village" — so it cannot be read literally. If a number is ever needed, compute it within one frame and name the frame. Reasoning: `references/visit-protocol.md` → "No drift scan, no log-wide average".
