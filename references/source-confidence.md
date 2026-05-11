# Source Confidence

How to weight different sources when evaluating a candidate restaurant — and when to discount Google Maps ratings for tourist-bias.

## Why this exists

Most recommendation systems treat all sources equally and rank by aggregate score. This is wrong because:

- A restaurant cited in a chef interview carries ~8 bits of information per Shannon (independent expert judgment, narrative reasoning)
- A 4.5-star rating from 2,000 Google Maps reviews carries ~0.3 bits (dominated by purchasing bias and J-shaped distribution; reviews aren't independent due to social proof cascades)
- Tourist-heavy locations inflate Google ratings ~13.4% (Information Systems Research, DOI: 10.1287/isre.2020.0620) because tourists weight service/environment over food quality

Treating these signals equally produces filter-bubble recommendations dominated by aggregator scores. Treating them by their actual information content lets editorial trust propagate properly.

## Confidence Tiers

Every recommendation in output gets a tier prefix on its Sources line:

| Tier | Definition | Examples |
|---|---|---|
| **[A]** | Chef-cited (named chef recommends in interview) OR editorial consensus (≥2 independent editorial sources: Eater + Infatuation, or Michelin Bib + local critic) | Cañabota in chef interview by Pepe Rodríguez; Bib Gourmand + Guía Repsol Solete |
| **[B]** | Single editorial source (one trusted publication or critic) OR strong local Reddit consensus (multiple specific recommendations with details) OR Raisin/Star Wine List for wine bars | Eater Madrid 38; r/madrid thread with 3 detailed recommendations |
| **[C]** | Google Maps signal only OR aggregator-derived (TripAdvisor mentioned, etc.) OR single Reddit comment | Random GM 4.6 (1,200 reviews) with no editorial trace |

## Output format — where the tier appears

Tier prefix appears at the START of the Sources line in each card:

```
> Calle de Bretón de los Herreros, 54 · 500m from home
> [Google Maps](https://maps.google.com/...) · GM 4.5 (1,600+) · **Sources:** [A] Pepe Rodríguez interview (El Comidista 2024) + Michelin Bib Gourmand 2026
```

vs.

```
> Av. Marbella, 12 · Marbella centre
> [Google Maps](https://maps.google.com/...) · GM 4.6 (842 — likely tourist-inflated, treat as ~4.0) · **Sources:** [C] GM only
```

The tier is informational, not blocking. A [C] candidate can still be recommended if it's the right fit, but the user knows the confidence level at a glance and can choose accordingly.

## Tourist-bias annotation

When a candidate sits in a tourist-heavy location, annotate the GM rating inline rather than discounting silently:

**Triggers for tourist-bias suspicion:**
- Madrid: Sol / Gran Vía / Plaza Mayor / Puerta del Sol radius
- Barcelona: La Rambla / Barri Gòtic / Sagrada Familia radius
- San Sebastián / Bilbao Casco Viejo (mixed — local + tourist; flag if review volume is unusually high vs comparable local spots)
- Marbella casco antiguo / Puerto Banús
- Any city: cruise port adjacency, monument adjacency, beachfront strip in a known resort
- Signal: review volume disproportionate to neighborhood density (a "boutique fish restaurant" with 3,500 reviews in a small zone screams tourist trap)

**Annotation format:**

```
GM 4.6 (842 — likely tourist-inflated, treat as ~4.0)
```

The number is qualitative ("treat as ~4.0") not arithmetic. This honesty matters: the input data doesn't support a precise multiplier, so don't pretend it does.

**Anti-trigger:** if the place is in a tourist area BUT chef-cited or local-Reddit-confirmed, the tourist-bias annotation can be skipped — the editorial source already overrides Maps signal.

## Composite ranking guidance

When ranking candidates in a search:

1. Apply hard vetoes from taste-profile (cuisine adaptations, anti-pattern matches) — filter pre-score
2. Initial ranking by tier: [A] candidates rank above [B] above [C] when other factors comparable
3. Within tier, apply taste-profile match strength
4. Within ranking, apply hidden-gems slot mandate (see `hidden-gems.md`)

Tier is not the only signal — a [B] candidate that's a perfect taste match outranks an [A] candidate that's a poor fit for the occasion. But all else equal, source confidence breaks ties.

The bit estimates (chef:8, critic:5, reddit:2, maps:0.3) are order-of-magnitude approximations, not values used in ranking math. Use the tier (A/B/C). The bits explain *why* tiers differ in weight.
