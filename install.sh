#!/usr/bin/env bash
set -euo pipefail

# /restaurant skill installer
# Usage: ./install.sh [--data-dir DIR] [--uninstall] [--help]

DEFAULT_SKILL_DIR="$HOME/.claude/skills/restaurant"
DEFAULT_DATA_DIR="$HOME/Documents/restaurant-data"
SKILL_DIR=""
DATA_DIR=""
UNINSTALL=false
NON_INTERACTIVE=false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_SCRIPT_NAME="sync-restaurant-skill.sh"
HOOK_SCRIPT_DEST="$HOME/.claude/scripts/$HOOK_SCRIPT_NAME"
SETTINGS_FILE="$HOME/.claude/settings.json"

# Colors (only if terminal)
if [ -t 1 ]; then
  GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
else
  GREEN=''; RED=''; YELLOW=''; NC=''
fi

log()  { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}!${NC} $1"; }
die()  { echo -e "${RED}✗${NC} $1" >&2; exit 1; }

# Read a value from flat YAML config (key: value format)
# Handles: double/single quotes, trailing comments, tilde expansion
read_config() {
  local file="$1" key="$2"
  local val
  val=$(awk -F': ' -v k="$key" '$1==k {print $2; exit}' "$file")
  val="${val%\"}" ; val="${val#\"}"   # strip double quotes
  val="${val%\'}" ; val="${val#\'}"   # strip single quotes
  val="${val%%#*}"                    # strip trailing comment
  val="${val%"${val##*[![:space:]]}"}" # strip trailing whitespace
  val="${val/#\~/$HOME}"             # expand leading tilde
  printf '%s' "$val"
}

# Copy a directory of *.md files from repo into skill dir.
# Args: $1 = directory name (e.g., "references")
# - Validates source dir has >=1 *.md file
# - find -maxdepth 1 -type f rejects symlinks and recursion
copy_dir() {
  local name="$1"
  local src="$SCRIPT_DIR/$name"
  local dst="$SKILL_DIR/$name"
  [ -d "$src" ] || die "Directory $src not found in repo."
  local count
  count=$(find "$src" -maxdepth 1 -type f -name '*.md' | wc -l | tr -d ' ')
  [ "$count" -gt 0 ] || die "No *.md files in $src."
  mkdir -p "$dst"
  find "$src" -maxdepth 1 -type f -name '*.md' -exec cp {} "$dst"/ \;
  log "Installed $count file(s) to $dst"
}

# Print the SessionStart hook JSON snippet for manual addition to ~/.claude/settings.json
print_hook_snippet() {
  echo ""
  echo "Add this to ~/.claude/settings.json under hooks.SessionStart[0].hooks:"
  echo ""
  echo "  {"
  echo "    \"type\": \"command\","
  echo "    \"command\": \"$HOOK_SCRIPT_DEST\","
  echo "    \"async\": true"
  echo "  }"
  echo ""
}

# Add the SessionStart hook to settings.json using jq.
# Idempotent — won't duplicate if command already present.
# Backs up settings.json before modifying.
add_hook_to_settings() {
  if ! command -v jq >/dev/null 2>&1; then
    warn "jq not found — cannot auto-modify settings.json"
    print_hook_snippet
    return 0
  fi

  mkdir -p "$(dirname "$SETTINGS_FILE")"
  if [ -f "$SETTINGS_FILE" ]; then
    cp "$SETTINGS_FILE" "$SETTINGS_FILE.bak-$(date +%s)"
  else
    echo '{}' > "$SETTINGS_FILE"
  fi

  local new_hook
  new_hook=$(jq -n --arg cmd "$HOOK_SCRIPT_DEST" \
    '{type:"command", command:$cmd, async:true}')

  local tmp="$SETTINGS_FILE.tmp"
  if jq --argjson new "$new_hook" '
    .hooks //= {} |
    .hooks.SessionStart //= [{matcher:"startup", hooks:[]}] |
    if (.hooks.SessionStart | length) == 0 then
      .hooks.SessionStart = [{matcher:"startup", hooks:[]}]
    else . end |
    (.hooks.SessionStart[0].hooks // []) as $existing |
    if any($existing[]; .command == $new.command) then .
    else .hooks.SessionStart[0].hooks = $existing + [$new]
    end
  ' "$SETTINGS_FILE" > "$tmp" 2>/dev/null; then
    mv "$tmp" "$SETTINGS_FILE"
    log "Auto-update hook added to $SETTINGS_FILE"
  else
    rm -f "$tmp"
    warn "Could not parse $SETTINGS_FILE — leaving it untouched"
    print_hook_snippet
  fi
}

# Remove our SessionStart hook from settings.json (jq-based, with backup).
remove_hook_from_settings() {
  [ -f "$SETTINGS_FILE" ] || return 0
  command -v jq >/dev/null 2>&1 || return 0

  cp "$SETTINGS_FILE" "$SETTINGS_FILE.bak-$(date +%s)"
  local tmp="$SETTINGS_FILE.tmp"
  if jq --arg cmd "$HOOK_SCRIPT_DEST" '
    if (.hooks.SessionStart // []) | length > 0 then
      .hooks.SessionStart[0].hooks = (
        (.hooks.SessionStart[0].hooks // []) | map(select(.command != $cmd))
      )
    else . end
  ' "$SETTINGS_FILE" > "$tmp" 2>/dev/null; then
    mv "$tmp" "$SETTINGS_FILE"
    log "Auto-update hook removed from $SETTINGS_FILE"
  else
    rm -f "$tmp"
    warn "Could not modify $SETTINGS_FILE (keep manually editing)"
  fi
}

# Deploy the sync script and offer to wire up the SessionStart hook.
# In --non-interactive mode (used by sync script itself): deploy script, skip hook prompt.
setup_auto_update() {
  [ -f "$SCRIPT_DIR/scripts/$HOOK_SCRIPT_NAME" ] || return 0

  mkdir -p "$(dirname "$HOOK_SCRIPT_DEST")"
  cp "$SCRIPT_DIR/scripts/$HOOK_SCRIPT_NAME" "$HOOK_SCRIPT_DEST"
  chmod +x "$HOOK_SCRIPT_DEST"
  log "Installed sync script to $HOOK_SCRIPT_DEST"

  if [ "$NON_INTERACTIVE" = true ]; then
    return 0
  fi

  echo ""
  echo "Enable automatic updates?"
  echo "  Adds a SessionStart hook that pulls upstream every 24h and re-runs install."
  echo "  Your config.yml and data are preserved."
  read -r -p "  [Y/n] " reply
  case "$reply" in
    n|N|no|No|NO)
      log "Auto-update declined — to enable later, see the hook JSON below:"
      print_hook_snippet
      ;;
    *)
      add_hook_to_settings
      ;;
  esac
}

usage() {
  echo "Usage: ./install.sh [OPTIONS]"
  echo ""
  echo "Install the /restaurant skill for Claude Code."
  echo ""
  echo "Options:"
  echo "  --skill-dir DIR    Set skill directory (default: ~/.claude/skills/restaurant)"
  echo "  --data-dir DIR     Set data directory (default: ~/Documents/restaurant-data)"
  echo "  --uninstall        Remove skill files (preserves your data + config.yml)"
  echo "  --non-interactive  Skip all prompts (used by the auto-update sync script)"
  echo "  --help             Show this help"
  echo ""
  echo "What it does:"
  echo "  - Copies SKILL.md, local-critics.md, references/, evals/ to the skill dir"
  echo "  - Copies templates to your data directory (won't overwrite existing files)"
  echo "  - Creates cities/ and recommendations/ directories"
  echo ""
  echo "Quick start after install: type /restaurant in Claude Code"
}

# Parse args
while [[ $# -gt 0 ]]; do
  case $1 in
    --skill-dir)
      if [[ -z "${2:-}" ]] || [[ "$2" == --* ]]; then
        die "--skill-dir requires a directory path"
      fi
      SKILL_DIR="$2"; shift 2
      ;;
    --data-dir)
      if [[ -z "${2:-}" ]] || [[ "$2" == --* ]]; then
        die "--data-dir requires a directory path"
      fi
      DATA_DIR="$2"; shift 2
      ;;
    --uninstall) UNINSTALL=true; shift ;;
    --non-interactive) NON_INTERACTIVE=true; shift ;;
    --help) usage; exit 0 ;;
    *) die "Unknown option: $1. Use --help for usage." ;;
  esac
done

# Apply defaults after arg parsing (mirrors DATA_DIR pattern)
SKILL_DIR="${SKILL_DIR:-$DEFAULT_SKILL_DIR}"

# On reinstall: honor data_dir from existing config if no --data-dir was passed
if [ -z "$DATA_DIR" ] && [ -f "$SKILL_DIR/config.yml" ]; then
  PARSED_DIR=$(read_config "$SKILL_DIR/config.yml" "data_dir")
  if [[ -n "$PARSED_DIR" ]] && [[ "$PARSED_DIR" =~ ^/ ]]; then
    DATA_DIR="$PARSED_DIR"
    log "Using data_dir from existing config: $DATA_DIR"
  fi
fi
DATA_DIR="${DATA_DIR:-$DEFAULT_DATA_DIR}"

# Uninstall
if [ "$UNINSTALL" = true ]; then
  ACTUAL_DATA_DIR="$DATA_DIR"
  if [ -d "$SKILL_DIR" ]; then
    # Read actual data_dir from config before removing anything
    if [ -f "$SKILL_DIR/config.yml" ]; then
      PARSED_DIR=$(read_config "$SKILL_DIR/config.yml" "data_dir")
      if [[ -n "$PARSED_DIR" ]] && [[ "$PARSED_DIR" =~ ^/ ]]; then
        ACTUAL_DATA_DIR="$PARSED_DIR"
      fi
    fi
    # Remove only repo-managed files, preserve config.yml
    rm -f "$SKILL_DIR/SKILL.md" "$SKILL_DIR/local-critics.md"
    rm -rf "$SKILL_DIR/references" "$SKILL_DIR/evals" "$SKILL_DIR/.source"
    rm -f "$SKILL_DIR/.last-sync"
    log "Removed skill files from $SKILL_DIR"
    # Remove the sync script + SessionStart hook
    if [ -f "$HOOK_SCRIPT_DEST" ]; then
      rm -f "$HOOK_SCRIPT_DEST"
      log "Removed sync script $HOOK_SCRIPT_DEST"
    fi
    remove_hook_from_settings
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

# Validate source files
[ -f "$SCRIPT_DIR/SKILL.md" ] || die "SKILL.md not found in $SCRIPT_DIR. Run from the repo directory."
[ -f "$SCRIPT_DIR/local-critics.md" ] || die "local-critics.md not found in $SCRIPT_DIR."
[ -d "$SCRIPT_DIR/references" ] || die "references/ directory not found in $SCRIPT_DIR."
[ -d "$SCRIPT_DIR/evals" ] || die "evals/ directory not found in $SCRIPT_DIR."

# Check Claude Code (warn, don't fail)
if ! command -v claude >/dev/null 2>&1; then
  warn "Claude Code CLI not found. Install it first: https://claude.ai/claude-code"
fi

# Install skill files (always overwrite — repo-managed)
mkdir -p "$SKILL_DIR"
cp "$SCRIPT_DIR/SKILL.md" "$SKILL_DIR/SKILL.md"
cp "$SCRIPT_DIR/local-critics.md" "$SKILL_DIR/local-critics.md"
log "Installed core skill files to $SKILL_DIR"
copy_dir references
copy_dir evals

# Install templates (copy-if-missing — user-managed)
mkdir -p "$DATA_DIR" "$DATA_DIR/cities" "$DATA_DIR/recommendations"

if [ -f "$SCRIPT_DIR/taste-profile-template.md" ] && [ ! -f "$DATA_DIR/taste-profile.md" ]; then
  cp "$SCRIPT_DIR/taste-profile-template.md" "$DATA_DIR/taste-profile.md"
  log "Created taste-profile.md from template"
else
  [ -f "$DATA_DIR/taste-profile.md" ] && log "taste-profile.md already exists — kept"
fi

if [ -f "$SCRIPT_DIR/feedback-log-template.md" ] && [ ! -f "$DATA_DIR/feedback-log.md" ]; then
  cp "$SCRIPT_DIR/feedback-log-template.md" "$DATA_DIR/feedback-log.md"
  log "Created feedback-log.md from template"
else
  [ -f "$DATA_DIR/feedback-log.md" ] && log "feedback-log.md already exists — kept"
fi

# Protect data directory from accidental git commits
if [ ! -f "$DATA_DIR/.gitignore" ]; then
  cat > "$DATA_DIR/.gitignore" << 'GITIGNORE'
# This directory contains personal data. Do not commit.
*
!.gitignore
GITIGNORE
  log "Created .gitignore in data directory"
fi

log "Data directory ready at $DATA_DIR"

# Auto-update wiring (deploys sync script + optionally adds SessionStart hook)
setup_auto_update

echo ""
echo "Done! Open Claude Code and type /restaurant to start onboarding."
echo "Data directory: $DATA_DIR"
