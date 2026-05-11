# Smoke-Test Eval Prompts

Three manual smoke-test prompts to run in chat after a refactor. Type each prompt into a fresh `/restaurant` invocation and check outputs against the verification points.

## Eval 1 — Group Occasion + Source Confidence

**Prompt:**
```
/restaurant Madrid asian dinner for 5 people
```

**Verifications:**
1. Group occasion inferred (no question asked; "5 people" should trigger `group` mode automatically)
2. Sources line in each card starts with `[A]`, `[B]`, or `[C]` tier prefix
3. At least 1 of 3 picks labeled as Hidden Gem in its own section
4. Restaurants are appropriate for sharing format (large tables, sharing menus, 4+ seat capacity)
5. No tourist-bias annotation appears on local-resident-area picks (non-tourist neighborhoods)
6. Output ends with link to saved .md file

**Failure modes to catch:**
- Tier prefix missing → source-confidence.md not wired into Output Format
- Hidden gem label missing → hidden-gems.md not consulted
- Solo or counter-only restaurants returned → group occasion inference broken
- Skill asks "is this for a group?" → inference rules in occasion-taxonomy.md not applied

## Eval 2 — Multi-Round Exclusion + Hidden Gem

**Prompt (after a previous Bilbao search has been run in same week):**
```
/restaurant Bilbao R5 wine bars — need new places not seen in R1-R4
```

**Verifications:**
1. Round detection fires (looks at cities/bilbao.md for prior `## Searched` entries)
2. Exclusion list loaded from `## Excluded (with reason)` — none of those names reappear
3. `## Mentioned (researched, not yet selected)` from prior rounds is checked first
4. At least 1 candidate is from the Mentioned list, promoted to Recommended
5. Tier prefixes appear; hidden gem slot present
6. Output saved as updated recommendation file (not new file)

**Failure modes:**
- Excluded restaurants reappear → multi-round exclusion broken
- All candidates are completely fresh (Mentioned list ignored) → Mentioned section workflow lost
- Tier prefixes missing on Round N+ output → output format hooks not applied to multi-round path

## Eval 3 — New City Cold-Start + Tourist Bias

**Prompt:**
```
/restaurant Tarifa seafood — never been there
```

**Verifications:**
1. No prior cities/tarifa.md exists → skill creates one
2. Skill projects from similar visited cities (other Andalusian: Marbella, Seville) for prior — does NOT just dump Google Maps top results
3. Tourist-bias annotation appears on candidates in known tourist zones of Tarifa (the casco antiguo, near the kitesurf strip)
4. Hidden gem slot triggered via editorial-source-rare fallback (Tarifa likely has no TSV cache for review-count comparison)
5. New city onboarding question asked if needed (e.g., "Old town or kitesurfer beach?")
6. Sources predominantly editorial (chef interviews, local Andalusian food press, Reddit r/Tarifa or r/Cadiz) rather than aggregator scores

**Failure modes:**
- Output is just GM 4.5+ list with no editorial signal → cold-start fell back to default Maps ranking
- No tourist-bias annotation → source-confidence.md trigger conditions not consulted
- Hidden gem slot omitted with no documented skip reason → mandate not enforced
- Skill asks for taste profile from scratch → cold-start protocol failed to project from similar cities

## How to run

For each eval:

1. Open a fresh chat window (clean context)
2. Type the prompt
3. Read output once, scoring verifications mentally (1-6 in each)
4. Note any failure mode triggered
5. If 2+ failures across the 3 evals, the refactor introduced regression — investigate

These three cover the three main code paths: single-shot occasion inference, multi-round continuation, and cold-start. Smoke test, not proof of correctness — add new evals only when a specific bug needs a regression check.
