# Visit Protocol

How to capture a visit so the resulting feedback log entry is rich enough to drive future recommendations. This protocol replaces the older "place name + rating" capture for new entries; existing entries in `feedback-log.md` remain in their original format.

## Why this exists

Two findings from cognitive science motivate the change:

1. **Peak-end rule** (Kahneman et al. 1993 cold-pressor study; Redelmeier & Kahneman 1996 colonoscopy study) — episodic memory is dominated by the peak moment and the end moment. Duration and average have essentially zero weight. A meal recalled "overall as 8" is actually remembered as a peak experience plus a closing experience; the average is reconstructed, not retrieved.

   *Caveat for restaurants:* peak-end was established for hedonic experiences with clear temporal structure. Restaurant quality is partly hedonic-peak-driven and partly steady-state (a place where every dish is a calm 8 with no fireworks — Casa Julián-style). For consistency-driven entries, Peak may be the steady-state observation itself ("every dish at the same calm level, no spark moment"); do not manufacture a fireworks moment to fill the field. "No-spark, would-return" is a real signal, not a peak-protocol failure.
2. **Confirmation bias in self-report** (Nickerson 1998) — asking "did you love it?" produces affirmative bias. Asking "what didn't work?" surfaces evidence the brain otherwise suppresses.

Capturing peak, end, and disconfirming evidence as separate fields preserves the actual signal instead of collapsing it into one number that loses information immediately after the meal.

## Protocol — Asymmetric Question Sequence

When the user reports a visit ("was at X, 8/10" / "tried Y last night"), ask in ONE batched message — not one by one:

```
Записываю визит. 4 вопроса одним блоком чтобы данные стали полезны для будущих рекомендаций:

1. Peak moment: что был самым кайфовым моментом за вечер? (одно блюдо, 
   момент, разговор)

2. End moment: как закончился ужин? (последнее блюдо, кофе, счёт, 
   прощание — что осталось в памяти после "выхода")

3. Что НЕ сошлось / что могло быть лучше? (если ничего — "—",  
   но подумай секунду)

4. Return: yes (mandatory) / yes (situational) / maybe / no — 
   и в каком контексте если situational?
```

Use the request language. The above is the Russian default; mirror to English when user writes in English.

## Decimal scoring rule

The /10 scale gains decimal granularity on the top tier where editorial discrimination matters:

| Range | Format | Why |
|---|---|---|
| 9.0+ | one decimal required (9.0, 9.4, 9.8) | Top-tier discrimination matters; "all 9s" loses signal |
| 6.0–8.9 | integers OR .5 increments allowed (7, 7.5, 8) | Mid-tier doesn't reward false precision |
| 1.0–5.9 | integers (rarely seen for visits the user actually completes) | — |

Statistics in `feedback-log.md` should compute on the actual decimal values, not rounded. The "average rating" calculation in the Statistics section uses true means.

## Feedback-log entry template

```markdown
### {Place Name} — {City} | {N.M}/10 | YYYY-MM-DD
- Type: {format/cuisine}
- Peak: {one specific moment that defined the meal in memory}
- End: {how it closed — last dish, coffee, farewell, the bill experience}
- Disconfirm: {what didn't work / what could be better; "—" only if truly nothing}
- Axis: {food / food + wine / food + atmosphere / food + concept / etc.}
- Return: {yes mandatory / yes situational + context / maybe / no}
- Source: {how we found it — chef, Reddit, want-to-go, walk-in, recommendation}
- Notes: {address + neighbourhood, anything else; calibration notes if relevant}
```

The Pros/Cons fields from the older format are subsumed by Peak/Disconfirm. The Pros field tended to invite confirmation-biased lists; Peak forces a single specific moment which is more diagnostic.

## Calibration — tier definitions, not fixed places

To prevent rating drift over years, tiers are defined by **observable behavior signals** the protocol fields already capture (peak / end / disconfirm / return). The previous mechanism — three fixed reference restaurants compared against every new rating — is replaced because it forced cross-format comparison (e.g., wine bar vs Basque grill) that was incoherent in practice and produced ratings the calibration ritual could not actually defend. Anchors also drift in memory themselves, importing a new drift problem to solve an old one.

### Tier definitions

| Tier | Behavior signals |
|---|---|
| 10 | Power spot. Return mandatory. Would travel specifically for it. Peak + atmosphere + concept all carry weight together. Rare. |
| 9 | Strong peak with no disconfirm. Goes regularly or wants to. At least one component (food / wine / concept / atmosphere) genuinely shines. |
| 8 | Return mandatory **+** at least one clear strength (peak-driven OR steady-state consistency OR craft signal). Disconfirm minimal. |
| 7 | Would go again if convenient. No pull to choose it specifically. Often "solid, no spark." |
| 6–6.5 | Passable. Fallback only. No peak, mild disconfirm, situational return at best. |
| 5 and below | Real disappointment. Negative disconfirm dominates. Rare for visits the user completes voluntarily. |

The /10 number reads against these definitions. Decimal granularity on 9.0+ remains for editorial discrimination at the top tier.

### Drift detection — periodic scan, not per-rating check

Reference-point drift over years is real (hedonic adaptation). The protocol catches it via **periodic statistical scan** of `feedback-log.md`, not by per-rating comparison to a fixed restaurant.

After every 15 visits added, surface to the user:
- Is the running average creeping upward without proportional growth in mandatory-return entries?
- Has a tier become inflated (e.g., 5+ new 9s in a quarter with no 10s)?
- Is a format consistently scoring 8+ but still tagged as a non-Top tier in `taste-profile.md`?

If yes — present findings and let the user decide whether the bar shifted or the data shifted. Never auto-recalibrate.

### Optional: format-specific anchor when a format has >= 5 entries

For formats where the log has >= 5 entries (e.g., ramen, oyster bar, Basque grill, wine bar), the entries themselves become the anchor — comparison is like-to-like and self-recalibrating as the log grows.

Before assigning >=8 to a new entry in that format, scan the 3 most recent same-format entries:
- Does this visit clear them on at least one dimension (peak, return-strength, craft)?
- Or does it sit in the same band as a prior 7 that the user already labeled "solid, no spark"?

For formats with <5 entries: skip this anchor check. Rely on the tier definitions above and the structured protocol fields. **Do NOT cross-format compare** (a new wine bar vs a Basque grill 8) — that was the previous mechanism's broken default.

## Cache correction discipline

If a visit reveals that prior cache notes were wrong (e.g., Andra Mari's "no panoramic views" was wrong — the terrace has a mountain view), include an explicit `CACHE CORRECTION:` line in Notes describing what was wrong. The next search reads this and fixes the city cache.

## When the user gives only a rating

If the user provides only "X — 8/10" without elaboration, ask the 4-question batch once. If they decline to answer ("just record the 8"), record what you have but mark it `Notes: minimal capture — peak/end/disconfirm not captured`. Don't fabricate fields.
