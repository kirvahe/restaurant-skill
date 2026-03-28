---
title: "refactor: CE review hardening -- install safety, SKILL.md correctness, PII protection"
type: refactor
status: completed
date: 2026-03-28
deepened: 2026-03-28
---

# CE Review Hardening

Resolve 25 findings from a 9-agent Compound Engineering review. Four P1 critical issues (installer data loss, rating mismatch, PII exposure), ten P2 important issues (onboarding mapping errors, stale tools, path sanitization, state tracking), and eleven P3 documentation polish items.

## Enhancement Summary

**Deepened on:** 2026-03-28
**Research agents used:** bash-best-practices, skill-authoring, security-reviewer, correctness-reviewer, maintainability-reviewer, simplicity-reviewer
**Sections enhanced:** 4 phases + architecture + acceptance criteria

### Key Improvements from Deepening
1. **Bug found in plan:** `ACTUAL_DATA_DIR` unbound in uninstall else-path crashes with `set -u`
2. **Simplified YAML parsing:** replaced fragile sed regex with `awk` (80 chars -> 20 chars)
3. **Better argument guard:** catches `--data-dir --uninstall` (flag consumed as path)
4. **Scope reduced:** cut 6 items from Phase 4, cut F12 (state markers LLM can't reliably use)
5. **Security hardening:** .gitignore in data_dir too, path validation for parsed config values
6. **Upgrade migration:** existing users won't be caught in onboarding loops after F13

### Items Cut After Deepening
- **F12** (calibration/debrief state markers) -- LLM can count entries; HTML comment state is fragile and accumulates without cleanup. The existing `<!-- debrief: asked -->` marker is sufficient.
- **F15** (README line counts) -- trivial, do inline if editing README anyway
- **F17** (cities-template reference) -- Claude sees the template in data_dir already
- **F20** (verbatim onboarding questions) -- LLM paraphrases anyway; adds 30-50 lines for marginal consistency gain
- **F21** (Overview example) -- Claude derives this from "text, bullets, or a mix" instruction
- **F22** (per-country dates) -- adding same date to 31 headings tells nothing; useful only when verified independently
- **F24** (compound intent routing) -- edge case LLM handles naturally

**Remaining: 18 items across 4 phases.**

---

## Overview

The restaurant-skill is a Claude Code skill (SKILL.md + templates + bash installer + reference data) at v1.0. A CE review with 9 parallel agents surfaced 25 findings across security, correctness, architecture, agent-readiness, and maintainability. No outright broken functionality, but several issues that would bite users on install, uninstall, upgrade, or onboarding resume paths.

The fixes are organized into 4 batches following the dependency graph from SpecFlow analysis.

## Problem Statement

1. **install.sh has 4 bugs** -- crashes on `--data-dir` without value, deletes config.yml on uninstall (user data loss), shows wrong data path on uninstall, and ignores existing config on reinstall
2. **SKILL.md has correctness errors** -- country count wrong (30 vs 31), rating tier mismatch between templates, onboarding Block 1/3 write to wrong sections, phantom search tools
3. **No PII protection** -- no .gitignore, home address in plaintext config, no privacy note
4. **Agent execution gaps** -- template placeholder undefined, path sanitization missing

## Proposed Solution

Four batches of fixes, ordered by dependency graph. Each batch is independently shippable.

## Technical Approach

### Architecture

**Key decision: config.yml stays in `~/.claude/skills/restaurant/` but uninstall uses targeted deletion instead of `rm -rf`.**

Moving config.yml to `$DATA_DIR/config.yml` creates a chicken-and-egg problem (need config to find data_dir, config is in data_dir). Moving to `~/.config/restaurant-skill/` adds a third location. The simplest fix: change uninstall from `rm -rf $SKILL_DIR` to `rm -f` on specific repo-managed files (SKILL.md, local-critics.md), preserving config.yml.

> **Post-uninstall state:** SKILL_DIR may contain only config.yml. The uninstall message explicitly tells the user this: "Config preserved at $SKILL_DIR/config.yml -- reinstall will reuse your settings."

### Shared utility: YAML config reader

**Research insight:** The original plan used a 80-char sed regex duplicated in two places. Both the simplicity and bash-best-practices agents recommended `awk` or `cut` instead. Extract into a function:

```bash
# Read a value from flat YAML config (key: value format)
# Handles: double quotes, single quotes, trailing comments, tilde expansion
# Does NOT handle: nested YAML, multiline values, flow syntax
read_config() {
  local file="$1" key="$2"
  local val
  val=$(awk -F': ' -v k="$key" '$1==k {print $2; exit}' "$file")
  # Strip surrounding quotes (single or double)
  val="${val%\"}" ; val="${val#\"}"
  val="${val%\'}" ; val="${val#\'}"
  # Strip trailing comment
  val="${val%%#*}"
  # Strip trailing whitespace
  val="${val%"${val##*[![:space:]]}"}"
  # Expand leading tilde only
  val="${val/#\~/$HOME}"
  printf '%s' "$val"
}
```

**Why this is better than sed:**
- Handles both single and double quotes (sed only handled double)
- Strips trailing YAML comments (`data_dir: /path  # my data`)
- Strips trailing whitespace
- Tilde expansion anchored to start only (sed was unanchored)
- One function, used in both uninstall and reinstall paths

### Implementation Phases

#### Phase 1: install.sh Hardening (F1, F2, F7, F11)

**F1: Guard `--data-dir` argument**

`install.sh:44-45`

```bash
# Before:
--data-dir) DATA_DIR="$2"; shift 2 ;;

# After:
--data-dir)
  if [[ -z "${2:-}" ]] || [[ "$2" == --* ]]; then
    die "--data-dir requires a directory path"
  fi
  DATA_DIR="$2"; shift 2
  ;;
```

> **Research insight:** The `"${2:-}"` pattern prevents `set -u` crash. The `--*` check catches `./install.sh --data-dir --uninstall` (flag consumed as path value).

**F2 + F7: Fix uninstall to preserve config.yml and show correct data path**

`install.sh:55-66`

```bash
# After:
if [ "$UNINSTALL" = true ]; then
  # Initialize ACTUAL_DATA_DIR before the conditional (prevents set -u crash)
  ACTUAL_DATA_DIR="$DATA_DIR"
  if [ -d "$SKILL_DIR" ]; then
    # Read actual data_dir from config before removing anything
    if [ -f "$SKILL_DIR/config.yml" ]; then
      PARSED_DIR=$(read_config "$SKILL_DIR/config.yml" "data_dir")
      [ -n "$PARSED_DIR" ] && ACTUAL_DATA_DIR="$PARSED_DIR"
    fi
    # Remove only repo-managed files, preserve config.yml
    rm -f "$SKILL_DIR/SKILL.md" "$SKILL_DIR/local-critics.md"
    log "Removed skill files from $SKILL_DIR"
    # Remove dir only if empty
    if rmdir "$SKILL_DIR" 2>/dev/null; then
      log "Removed empty $SKILL_DIR"
    else
      log "Config preserved at $SKILL_DIR/config.yml -- reinstall will reuse your settings"
    fi
  else
    warn "Skill directory not found at $SKILL_DIR"
  fi
  echo ""
  echo "Your data at $ACTUAL_DATA_DIR was NOT removed."
  echo "Delete it manually if you no longer need it."
  exit 0
fi
```

> **Bug fix from deepening (C9):** Original plan assigned `ACTUAL_DATA_DIR` inside the `if` block only. With `set -u`, referencing it after the block when SKILL_DIR doesn't exist would crash bash. Now initialized before the conditional.

> **Security insight (SEC-1):** After parsing, validate the path is absolute:
> ```bash
> [[ "$PARSED_DIR" =~ ^/ ]] || [[ "$PARSED_DIR" =~ ^~ ]] || { warn "Invalid data_dir in config -- using default"; PARSED_DIR=""; }
> ```

**F11: Reinstall reads existing config.yml for data_dir**

`install.sh:52` (after argument parsing, before DATA_DIR fallback)

```bash
if [ -z "$DATA_DIR" ] && [ -f "$SKILL_DIR/config.yml" ]; then
  PARSED_DIR=$(read_config "$SKILL_DIR/config.yml" "data_dir")
  if [ -n "$PARSED_DIR" ]; then
    DATA_DIR="$PARSED_DIR"
    log "Using data_dir from existing config: $DATA_DIR"
  fi
fi
DATA_DIR="${DATA_DIR:-$DEFAULT_DATA_DIR}"
```

**Checklist:**

- [x] Add `read_config()` function at top of install.sh
- [x] Guard `--data-dir` with `"${2:-}"` and `--*` check (F1)
- [x] Initialize `ACTUAL_DATA_DIR` before conditional in uninstall (F2 bug fix)
- [x] Uninstall uses targeted `rm -f` instead of `rm -rf` (F2)
- [x] Uninstall reads config.yml via `read_config` for actual data path (F7)
- [x] Reinstall reads existing config.yml to honor data_dir (F11)
- [x] Validate parsed path is absolute (security hardening)
- [x] Run `shellcheck -x -S warning install.sh` -- fix all findings
- [x] Test: `./install.sh --data-dir` (no value) -- helpful error
- [x] Test: `./install.sh --data-dir --uninstall` -- rejects flag as path
- [ ] Test: install, uninstall, verify config.yml preserved
- [ ] Test: install with `--data-dir /tmp/test`, reinstall without flag, verify /tmp/test used
- [ ] Test: uninstall when SKILL_DIR doesn't exist -- no crash
- [ ] Test: config.yml with tilde path, single-quoted path, trailing comment

#### Phase 2: Template & SKILL.md Correctness (F3, F4, F8, F9, F13)

**F3: Align rating tiers**

`taste-profile-template.md:131-135`

```markdown
# Before:
### Ok, but doesn't spark (5-7/10)

# After:
### Ok, but doesn't spark (6-7/10)
### Disappointing (5/10 and below)
```

> **Correctness note (C8):** The "5 and below" tier merges feedback-log's "Disappointing (5)" and "Fail (1-4)". This is acceptable for the taste-profile reference section -- users won't list 1-4 rated places as reference restaurants. The tier exists for calibration: "places that actively disappointed."

**F4: Create .gitignore (repo + data_dir)**

New file in repo root: `.gitignore`

```
# User data (contains PII -- home address, dining habits)
config.yml
taste-profile.md
feedback-log.md
cities/
recommendations/
saved-places-data.md

# OS
.DS_Store
```

> **Security insight (SEC-2):** The repo .gitignore only protects the repo directory. Also deploy a `.gitignore` in `$DATA_DIR` during install:

```bash
# In install.sh, after creating DATA_DIR:
if [ ! -f "$DATA_DIR/.gitignore" ]; then
  cat > "$DATA_DIR/.gitignore" << 'GITIGNORE'
# This directory contains personal data. Do not commit.
*
!.gitignore
GITIGNORE
  log "Created .gitignore in data directory"
fi
```

> **Correctness note (C4):** The `!taste-profile-template.md` negation lines in the original plan were unnecessary -- git exact-match patterns don't cross-match different filenames. Removed for clarity.

**F8: Block 1 After-block includes Who section update**

`SKILL.md:240` -- Change Block 1 row:

```markdown
# Before After-block:
Create config.yml, data_dir, initial files. If saved places → ask user to export/share data

# After:
Create config.yml, data_dir, initial files. Update taste-profile.md Who section. If saved places → note for post-onboarding setup
```

**F9: Block 3 remove seasonality (already in Block 7)**

`SKILL.md:242` -- Remove "seasonality" from Block 3 key questions. Verified: Block 7 (line 246) already lists "seasonality" in its key questions, and taste-profile-template.md has Seasonality under "## Evening ritual" (line 99), not Taste Compass.

**F13: Define template placeholder detection**

`SKILL.md:14-18`

```markdown
# After:
4. Check if onboarding is complete -- taste-profile.md must have all three required sections filled:
   - A section is **filled** if it contains any text outside HTML comments (`<!-- -->`), is not just whitespace, and does not only contain `[SKIPPED]`
   - `[SKIPPED]` = intentionally skipped (not incomplete -- do not re-ask)
   - HTML comments alone = still a template placeholder (incomplete)
```

> **Upgrade migration (from maintainability review):** Existing users who completed onboarding but left optional sections as HTML-comment-only won't be affected because only the 3 *required* sections (Who, Cuisine, References) are checked. Optional sections with comments are not re-triggered. If a required section somehow has only comments post-onboarding, Claude should fill it from context rather than re-asking Block 1 questions.

**Checklist:**

- [ ] Split taste-profile tier: "Ok" = 6-7, add "Disappointing" = 5 and below (F3)
- [ ] Create `.gitignore` in repo root (F4)
- [ ] Deploy `.gitignore` in `$DATA_DIR` during install (F4 hardening)
- [ ] Block 1 After-block: add "Update taste-profile.md Who section" (F8)
- [ ] Block 3: remove seasonality from key questions (F9)
- [ ] Define template placeholder detection explicitly (F13)
- [ ] Verify: interrupted onboarding resumes correctly with new detection rules

#### Phase 3: Runtime Quality (F5, F6, F10)

**F5: Country count 30 to 31**

Grep-and-replace:
- `SKILL.md:48` -- "30 countries" to "31 countries"
- `SKILL.md:100` -- "30 countries" to "31 countries"
- `README.md:3` -- "30 countries" to "31 countries"
- `README.md:15` -- "30 countries" to "31 countries"

> **Maintainability note:** README lines 98, 107, 142, 169 already say "31". Some may be rewritten by F19 (Phase 4). After all phases, run `grep -rn "30 countries\|31 countries" *.md` to verify consistency.

**F6: Remove phantom search tools**

`SKILL.md:110-116`:

```markdown
# After:
1. `mcp__exa__web_search_exa` (semantic -- best for editorial/Reddit)
2. `mcp__firecrawl__firecrawl_search` (keyword -- best for structured extraction)
3. Any other available web search MCP tool
4. Built-in WebSearch/WebFetch (limited, no site: filtering)
5. None available -> Degraded Mode (see Resilience section)
Once a tool works, keep using it for the conversation. If it errors (timeout, auth failure), try the next. Empty results = reformulate query, not a tool error.
```

Also update:
- `README.md:70` -- remove "Brave Search" from requirements
- `ROADMAP.md:49` -- update MCP independence section (currently references "Brave, Tavily, Exa, Perplexity")

> **Skill authoring insight:** The distinction between "tool error" (try fallback) and "empty results" (reformulate query) is critical for consistent agent behavior. Added explicitly.

**F10: Path sanitization for file names**

Add after `SKILL.md:183`:

```markdown
**File naming:** Use lowercase kebab-case for city and type in file paths. Strip diacritics. Remove characters outside `[a-z0-9-]`. Collapse multiple hyphens. Examples: `kuala-lumpur`, `sao-paulo`, `tel-aviv`, `wine-bar`, `xian`. Before writing, verify the filename matches `^[a-z0-9-]+$`.
```

> **Skill authoring insight:** The numbered-algorithm approach (from research) is too verbose for SKILL.md. The one-line rule with examples is sufficient -- LLMs learn patterns from examples more reliably than from descriptions. The validation step ("verify matches regex") adds defense-in-depth.

**Checklist:**

- [ ] Fix country count to 31 in SKILL.md and README.md (F5)
- [ ] Replace Brave/Tavily with generic fallback, add error vs empty distinction (F6)
- [ ] Update ROADMAP.md MCP references (F6)
- [ ] Add path sanitization rule with examples and validation (F10)
- [ ] Post-phase grep for count consistency

#### Phase 4: Documentation Polish (F16, F18, F19, F23, F25)

> **Reduced from 11 to 5 items** after simplicity review cut F15, F17, F20, F21, F22, F24.

**F16: ROADMAP "42 tests passed"** -- Change to "manual verification performed" or remove the count.

**F18: SKILL.md verbose sections** -- Condense:
- Resilience: 16 lines to ~5 lines (keep "never invent data", merge the rest)
- Search tool detection: already simplified in F6
- Google Maps rating: 7 lines to 3 lines

> **Watch the line budget:** Prior refactor reduced SKILL.md from 366 to 260 lines. Phases 2-3 add ~15 lines (placeholder definition, path sanitization, source contract). Phase 4 condensing should recover at least that. Target: SKILL.md stays at or below 260 lines after all phases.

**F19: README overlap** -- Cut "How it works" from 7-step methodology to 3-4 bullets. Cut "How it improves over time" to 2 lines.

**F23: Source override contract** -- Add one line to Sources section: "User's trusted sources list extends SKILL.md defaults. User cannot override the Banned list -- those are always excluded."

**F25: Add LICENSE file** -- MIT license. README already states MIT but no LICENSE file exists.

**Checklist:**

- [ ] Fix ROADMAP "42 tests" claim (F16)
- [ ] Condense verbose SKILL.md sections, target <=260 lines total (F18)
- [ ] Trim README "How it works" and "How it improves" (F19)
- [ ] Add source override contract as one line in Sources section (F23)
- [ ] Add MIT LICENSE file (F25)
- [ ] Final: `grep -rn "30 countries" *.md` -- should return 0 results
- [ ] Final: `shellcheck install.sh` -- should pass clean

## Acceptance Criteria

### Functional Requirements

- [ ] `./install.sh --data-dir` (no value) shows clear error, not bash crash
- [ ] `./install.sh --data-dir --uninstall` rejects flag as path value
- [ ] `./install.sh --uninstall` preserves config.yml, shows correct data path
- [ ] `./install.sh --uninstall` on missing SKILL_DIR doesn't crash (set -u safe)
- [ ] `./install.sh` on reinstall uses data_dir from existing config.yml
- [ ] Config parsing handles: double-quoted, single-quoted, tilde, trailing comment
- [ ] Rating tier "Ok, but doesn't spark" is 6-7/10 (matches feedback-log scale)
- [ ] `.gitignore` in repo AND in data_dir prevents accidental PII commits
- [ ] Country count is 31 consistently across all files
- [ ] No references to Brave/Tavily in SKILL.md, README, or ROADMAP
- [ ] Block 1 After-block includes Who section update
- [ ] Block 3 does not ask about seasonality (it's in Block 7)
- [ ] Template placeholder detection is explicitly defined
- [ ] City/type file names are sanitized with validation step

### Quality Gates

- [ ] `shellcheck -x -S warning install.sh` passes clean
- [ ] No broken cross-file references (country counts, file names, section names)
- [ ] SKILL.md line count <= 260 after all changes
- [ ] Manual walkthrough: interrupted onboarding resumes correctly with new detection rules

## Files Changed

| File | Phases | Changes |
|---|---|---|
| `install.sh` | 1 | read_config function, --data-dir guard, targeted uninstall, config reading, .gitignore deployment |
| `SKILL.md` | 2, 3, 4 | Block 1/3 fix, placeholder def, country count, tools, path sanitization, condensing |
| `taste-profile-template.md` | 2 | Rating tier split (5-7 -> 6-7 + 5-below) |
| `README.md` | 3, 4 | Country count, requirements, trim overlap |
| `ROADMAP.md` | 3, 4 | MCP references, "42 tests" claim |
| `.gitignore` | 2 | New file (repo root) |
| `LICENSE` | 4 | New file (MIT) |

## Sources & References

### Research (from /deepen-plan)
- Bash argument parsing: SO 2.6k+ score answer, `"${2:-}"` + `--*` prefix guard pattern
- Safe uninstall: targeted `rm -f` on manifest, `rmdir` as safety net
- YAML in bash: `awk -F': '` for flat config, `yq` for complex (not needed here)
- ShellCheck: `shellcheck -x -S warning` for CI, SC2155 split-declare pattern
- Skill authoring: CE `create-agent-skills` reference library (13 files), Anthropic skill docs
- State persistence: HTML comments reliable for simple markers only, fragile for complex state
- Path sanitization: rule-with-examples outperforms algorithmic description for LLMs

### Bugs Found During Deepening
- **C9:** `ACTUAL_DATA_DIR` unbound in uninstall else-path (would crash with set -u)
- **C3:** sed tilde substitution unanchored (replaced mid-string tildes)
- **C6:** `--data-dir --uninstall` silently consumed flag as path
- **C1:** Single-quoted YAML values left quotes intact
- **SEC-2:** .gitignore only in repo, not in data_dir where PII actually lives
