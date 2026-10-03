# Visit Protocol

How to capture a visit so the resulting feedback log entry is rich enough to drive future recommendations. This protocol replaces the older "place name + rating" capture for new entries; existing entries in `feedback-log.md` remain in their original format.

## Contents
- Why this exists (peak-end rule, confirmation bias)
- Protocol — asymmetric question sequence (the 4-question batch)
- Decimal scoring rule
- Feedback-log entry template (date convention, `Company` and `Ordered`)
- Context frames — what the number was measured against (+ provenance modifiers)
- Calibration — tier definitions, drift detection (removed), format-specific anchor
- Cache correction discipline
- When the user gives only a rating

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

Record the decimal the user gave; never round it for storage. (There is no log-wide average to feed — see "Drift detection — removed" below.)

## Feedback-log entry template

```markdown
### {Place Name} — {City} | {N.M}/10 | visited {X} · logged {YYYY-MM-DD}
- Type: {format/cuisine}
- Peak: {one specific moment that defined the meal in memory}
- End: {how it closed — last dish, coffee, farewell, the bill experience}
- Disconfirm: {what didn't work / what could be better; "—" only if truly nothing}
- Axis: {food / food + wine / food + atmosphere / food + concept / etc.}
- Context: {absolute / rural / neighbourhood / expectation-adjusted / constrained / composite / format-adjusted / occasion-specific / memory — see Context frames below}
- Company: {couple / friends (N) / solo / colleagues — who was there, because it changes which venues fit}
- Ordered: {the actual dishes, named. This is what makes an entry reusable}
- Return: {yes mandatory / yes situational + context / maybe / no}
- Source: {how we found it — chef, Reddit, want-to-go, walk-in, recommendation}
- Notes: {address + neighbourhood, anything else; calibration notes if relevant}
```

**Date convention.** The header carries two dates, because they are not the same thing and are easily conflated: `visited` is when the meal happened, `logged` is when it was written down. The gap can be years — a meal remembered from a long-ago trip and logged today. `visited` accepts a date (`YYYY-MM-DD`), a month (`YYYY-MM`), an approximation (`~YYYY-MM`), `ongoing (regular)` / `ongoing (N+ visits)` for places the user goes to repeatedly, or `unknown` when the date cannot be established. Write `unknown` rather than reusing the logging date — a guessed visit date silently corrupts any recency reasoning.

**`Company` and `Ordered` were dropped in the v1.2 redesign and restored in v1.4.** That was a regression, not a simplification: `Company` decides which venues fit at all (couple vs a noisy six-person sharing dinner are different searches), and `Ordered` is what makes an entry reusable later — an entry is only useful a year on if it says which dish worked and which did not.

The Pros/Cons fields from the older format are subsumed by Peak/Disconfirm. The Pros field tended to invite confirmation-biased lists; Peak forces a single specific moment which is more diagnostic.

## Context frames — what the number was measured against

Identical scores mean different things depending on the context they were given in.

The tier table below answers *how good was it*. It does not answer *good compared to what*, and without that second axis the log silently pools incomparable numbers. A single trip can produce two 7s that mean opposite things — a Michelin-starred restaurant that disappointed, and a village osteria that pleasantly surprised.

Record the frame in `Context:`. **Never adjust the user's number to normalise it.** The number is the user's; the frame is the metadata that makes it readable later.

| Frame | Meaning | Signal in the user's wording (EN · RU) |
|---|---|---|
| `absolute` | Judged against a full option set in a real city. The default. | No qualifier given, in any language |
| `rural` | Judged against what a small town or village can realistically deliver. The same food in a capital would score lower. | "good for a small town", "for what it is out here" · «для маленького городка отлично», «для такой глуши очень достойно» |
| `expectation-adjusted` | A star, a big name or a high price raised the bar. A mid number here means disappointment, not adequacy. | "for a starred place…", "at those prices…" · «для ресторана со звездой…», «за такие деньги…» |
| `constrained` | The choice set was degraded — holiday closures, Sunday, late night, nothing else open. The venue was not really chosen on merit. | "it was the only thing open", "everything else was shut" · «больше ничего не работало», «всё остальное было закрыто» |
| `neighbourhood` | A local regular, judged with convenience priced in. Not a claim that it beats destination venues. | "our local", "round the corner from home" · «наше место рядом с домом», «в двух шагах от дома» |
| `composite` | The user gave two numbers — food alone and overall. Record both; the headline number is not a food score. | "food alone X, overall Y" · «по еде X, в целом Y» |
| `format-adjusted` | Judged as what it is — an aperitivo counter, a takeaway window — not as a restaurant. Structural ceiling, not a verdict. | "an aperitivo stop, not a dinner", "takeaway only" · «это скорее на аперитив, чем на ужин», «только навынос» |
| `occasion-specific` | Rated for one craving or occasion, not as an all-purpose venue. | "my go-to when I crave X" · «хожу туда, когда хочется X» |
| `memory` | Scored years after the visit. A durable emotional anchor, not current information about the venue. | "I was there years ago" · «был там много лет назад» |

### Provenance modifiers — how the number itself was produced

Separate from the frame, and worth recording when it applies, because it changes how much the number can bear:

- **`scale-converted`** — a rating originally given on another scale (e.g. 4/5 during a bulk import), converted arithmetically and possibly rounded under a blanket rule. Those numbers are arithmetic, not judgement, and should not be treated as precise.
- **`manually corrected`** — a converted rating the user then overrode by hand. These are the most reliable entries of a converted batch — a deliberate number beats a derived one.
- **`carried-over`** — a revisit where the user declined to re-score and kept the previous number. The number is the previous rating held, not a fresh judgement of that visit.

A rating whose provenance is `scale-converted` and never corrected should not be used as evidence in a calibration argument without saying so.

Consequences for how the log is read:

- **Averages are computed within a frame, not across.** A flat log-wide mean mixes a rural 8 with an absolute 8 and means little.
- **Recommendations inherit the frame.** A `rural` 8 does not license recommending that venue to someone with city alternatives; an `expectation-adjusted` 7 is a warning about a well-reviewed place, not a mild endorsement.
- **Frames are why there is no log-wide average.** A run of `rural` entries drags a pooled mean down and a run of `neighbourhood` entries pushes it up, without either saying anything about the user's standards. Averaging across frames produces a number that looks meaningful and is not.

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

### Drift detection — removed in v1.4

There is no periodic drift scan, and this is deliberate.

What replaces it: **nothing aggregate.** The `Context:` field makes each rating readable on its own terms, with no cross-year comparison required, and the cuisine calibration in `SKILL.md` is where an actual profile change gets proposed.

**Do not re-introduce a log-wide average or a drift scan.** If drift ever genuinely needs measuring, do it inside one frame (`absolute` only) and name the frame.

#### Old patterns

<details>
<summary>Periodic drift scan and log-wide average (v1.2 – v1.3, removed in v1.4)</summary>

The mechanism existed here from v1.2 until v1.4, and was removed because there was no good answer to what it was for.

It asked three questions after every 15 visits, and its own closing instruction was *"present findings and let the user decide… Never auto-recalibrate"* — an observation with no action attached. Run against a real log, it produced a few lines of text and changed nothing. Two of its questions led nowhere. The third (*"is a format scoring 8+ but still tagged non-Top?"*) duplicated the cuisine calibration in `SKILL.md`, which does have an Apply y/n step and a file to write to.

Its only input was the log-wide average, which pooled nine incompatible `Context` frames and therefore could not be read literally. The average has been removed from `feedback-log.md` for the same reason. A guard whose only job was to protect a number nobody could use.
</details>

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
