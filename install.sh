#!/usr/bin/env bash
set -euo pipefail

# /restaurant skill installer
# Usage: ./install.sh [--data-dir DIR] [--uninstall] [--help]

SKILL_DIR="$HOME/.claude/skills/restaurant"
DEFAULT_DATA_DIR="$HOME/Documents/restaurant-data"
DATA_DIR=""
UNINSTALL=false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

usage() {
  echo "Usage: ./install.sh [OPTIONS]"
  echo ""
  echo "Install the /restaurant skill for Claude Code."
  echo ""
  echo "Options:"
  echo "  --data-dir DIR   Set data directory (default: ~/Documents/restaurant-data)"
  echo "  --uninstall      Remove skill files (preserves your data)"
  echo "  --help           Show this help"
  echo ""
  echo "What it does:"
  echo "  - Copies SKILL.md + local-critics.md to ~/.claude/skills/restaurant/"
  echo "  - Copies templates to your data directory (won't overwrite existing files)"
  echo "  - Creates cities/ and recommendations/ directories"
  echo ""
  echo "Quick start after install: type /restaurant in Claude Code"
}

# Parse args
while [[ $# -gt 0 ]]; do
  case $1 in
    --data-dir)
      if [[ -z "${2:-}" ]] || [[ "$2" == --* ]]; then
        die "--data-dir requires a directory path"
      fi
      DATA_DIR="$2"; shift 2
      ;;
    --uninstall) UNINSTALL=true; shift ;;
    --help) usage; exit 0 ;;
    *) die "Unknown option: $1. Use --help for usage." ;;
  esac
done

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

# Validate source files
[ -f "$SCRIPT_DIR/SKILL.md" ] || die "SKILL.md not found in $SCRIPT_DIR. Run from the repo directory."
[ -f "$SCRIPT_DIR/local-critics.md" ] || die "local-critics.md not found in $SCRIPT_DIR."

# Check Claude Code (warn, don't fail)
if ! command -v claude >/dev/null 2>&1; then
  warn "Claude Code CLI not found. Install it first: https://claude.ai/claude-code"
fi

# Install skill files (always overwrite — repo-managed)
mkdir -p "$SKILL_DIR"
cp "$SCRIPT_DIR/SKILL.md" "$SKILL_DIR/SKILL.md"
cp "$SCRIPT_DIR/local-critics.md" "$SKILL_DIR/local-critics.md"
log "Installed skill files to $SKILL_DIR"

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

echo ""
echo "Done! Open Claude Code and type /restaurant to start onboarding."
echo "Data directory: $DATA_DIR"
