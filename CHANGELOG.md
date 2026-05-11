# Changelog

All notable changes to this project are documented here.
Format follows [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/); the project uses 2-part `vMAJOR.MINOR` versioning aligned with its commit-title history (v0.9.0 retains its 3-part shape from the original beta tag; subsequent releases use 2-part `vX.Y`).

Note: entries for v0.9.0, v1.0, and v1.1 were backfilled retroactively on 2026-05-11 — they were never formally tagged at the time of their commits.

## [Unreleased]

## [v1.2] — 2026-05-11

Bundles the never-publicly-tagged v1.1 install/PII hardening with new v1.2 features: Google Maps Auto-Sync, multi-round search, modular `references/`, `evals/` spec, occasion taxonomy, Raisin.digital integration, chef-story criterion. Existing v1.0 users on default config keep working unchanged.

### Added
- **Google Maps Auto-Sync** — background TSV sync every 24h, cuisine→list matching (favorites / want-to-go / italian / japanese / cocktail-bar / etc.), grep-based cross-check against saved lists. Optional config keys: `gmaps_data_dir`, `gmaps_sync_script`, `gmaps_timestamp`.
- **Multi-round search** — round detection from refinement signals ("she didn't like any", "actually lunch not dinner"), persistent exclusion list with causal reasons, criteria-changes tracking, `## Mentioned (researched, not yet selected)` section in city files for candidates surfaced but not yet picked.
- **Modular `references/` folder** — five focused modules loaded conditionally:
  - `visit-protocol.md` (peak/end/disconfirm protocol + decimal scoring rule)
  - `source-confidence.md` (A/B/C tier model + tourist-bias annotation)
  - `hidden-gems.md` (under-the-radar slot mandate)
  - `occasion-taxonomy.md` (7-occasion inference model)
  - `onboarding-blocks.md` (full 7-block onboarding protocol)
- **`evals/evals.md`** — three-eval smoke-test framework (group occasion, multi-round exclusion, cold-start tourist bias) for regression testing after refactors.
- **Occasion taxonomy inference** — 7 occasions inferred from query language before scoring candidates (date-night vs solo-lunch produce different ranks from the same taste profile).
- **Raisin.digital integration** — natural wine / wine bar quality signal. Cross-reference against Raisin presence when searching wine bars.
- **Chef story as search criterion** — chef's personal narrative now factors into selection.
- **`config.yml.example`** — repo-tracked template with version `"1.2"` for manual setup.
- **`--skill-dir` flag** in `install.sh` — mirrors `--data-dir`, enables test/prod isolation.
- **Installer now deploys** `references/` and `evals/` directories alongside `SKILL.md` and `local-critics.md`.

### Changed
- **Setup mandate strengthened** — onboarding completeness check is mandatory before every response; HTML-comment-aware (`<!-- -->` alone = template placeholder, not filled). `[SKIPPED]` markers respected (do not re-ask).
- **`local-critics.md`** — 30 → 31 countries (added one country to TIER 2/3).
- **Rating semantics** — current opinion, not average across visits. A new rating replaces the prior rating.
- **Stats** — recalculated on every skill run (no stale aggregates).
- **Search-tool fallback** — empty results ≠ tool error; reformulate query before switching tools.
- **Web search tool order** — Exa first (semantic), then Firecrawl (keyword), then any other MCP, then built-in WebSearch, then degraded mode.

### Fixed
- **Vibe-references contradiction** — internal scoring conflict resolved (the "fire-in-eyes" signal no longer competes with "polished-perfectionism" from the same source class).
- **Search accuracy rules** — incorporated lessons from Trattoria Popolare analysis (brand presence ≠ format match, rating ≠ quality).
- **Banned-list non-overridable** — user's trusted-sources can extend defaults but cannot override the Banned list. Banned entries always excluded.

### Security
- Continued PII protection from v1.1: `config.yml` and `data_dir/` PII files remain `.gitignore`d in repo + auto-deployed `.gitignore` in user `data_dir`.
- `docs/plans/*` added to `.gitignore` so internal planning artifacts (which may reference earlier-version PII tokens) stay untracked.

### Migration (from v1.0)
- **MUST** — re-run `./install.sh`. Silently preserves your `config.yml` via v1.1's install-safety hardening; deploys the new `references/` and `evals/` directories.
- **SHOULD (optional)** — add `gmaps_*` keys to your `config.yml` if you want Google Maps integration. See `config.yml.example` for the exact field names.
- **NO-OP** — users on default v1.0 config without Google Maps continue working unchanged. New features activate only when explicitly enabled.

## [v1.1] — 2026-03-28 *(backfilled — never publicly tagged before v1.2)*

CE review hardening: install safety, correctness, PII protection.

### Added
- `.gitignore` in repo root (covers `config.yml`, `taste-profile.md`, `feedback-log.md`, `cities/`, `recommendations/`, `saved-places-data.md`, `.DS_Store`).
- `LICENSE` (MIT).
- `read_config()` awk-based YAML parser in `install.sh` (handles quoted values, trailing comments, tilde expansion).
- Path-sanitization rule with regex validation for city/type file names (kebab-case, ASCII-only).

### Changed
- `install.sh` uninstall uses targeted `rm -f` on repo-managed files only (preserves user's `config.yml`).
- `install.sh` reinstall reads existing `config.yml` for `data_dir` when no `--data-dir` flag is passed.
- Block 1 of onboarding now updates `taste-profile.md` "Who" section in the After-block.
- Template placeholder detection: a section with HTML comments only is still a template placeholder; `[SKIPPED]` is treated as intentionally skipped.

### Fixed
- `--data-dir` flag without a value previously crashed bash (`set -u`); now errors clearly.
- `--data-dir --uninstall` previously consumed the flag as a path value; now rejected.
- Uninstall on a missing `SKILL_DIR` previously crashed with `set -u`; now safe.
- Rating-tier mismatch between templates (`Ok` tier 5-7 vs 6-7 inconsistency).
- Country count drift (`30 countries` in some files, `31` in others; partially aligned in v1.1, fully aligned in v1.2).

### Security
- `.gitignore` auto-deployed in `data_dir` during install (prevents accidental commits of user dining habits).

## [v1.0] — 2026-03 *(backfilled — commit `abe342a`)*

Resilience, calibration, MCP independence, simplification.

### Added
- Degraded-mode fallback paths for missing data files (`taste-profile.md`, `feedback-log.md`, Google Maps).
- Source-confidence calibration: A/B/C tiers + tourist-bias rule.
- MCP independence: multiple search-tool fallback chain.
- 30-country `local-critics.md` reference (editorial food sources by country).

### Changed
- `SKILL.md` simplification pass (366 → 260 lines).
- README rewritten with 4-layer documentation structure.
- `ROADMAP.md` added for future iterations.

## [v0.9.0] — 2026-02 *(backfilled — public beta, commit `b96103f`)*

First public beta. SKILL.md, three template files, basic onboarding flow.

### Added
- Initial public beta release.
- `SKILL.md`, `taste-profile-template.md`, `feedback-log-template.md`, `cities-template.md`.
- Basic onboarding flow.
