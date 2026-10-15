#!/usr/bin/env bash
#
# codex-config installer
#
# Installs a portable [tui] block into your Codex CLI configuration so the
# terminal UI shows your usage limits, context window usage, and other session
# info in the footer.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/hgpt185/codex-config/main/install.sh | sh
#
#   ./install.sh --preset verbose
#   ./install.sh --dry-run
#   ./install.sh --uninstall
#
# The presets embedded below are the single source of truth for the installer.
# They mirror ./config.toml and ./presets/*.toml, which exist for people who
# prefer to install by hand. `./scripts/verify-sync.sh` checks that they match.

set -euo pipefail

REPO_URL="https://github.com/hgpt185/codex-config"

PRESET="balanced"
MODE="install"
DRY_RUN=0
CODEX_HOME_DIR="${CODEX_HOME:-$HOME/.codex}"

# --- output helpers -------------------------------------------------------

if [ -t 1 ]; then
  BOLD=$'\033[1m'; DIM=$'\033[2m'; GREEN=$'\033[32m'
  YELLOW=$'\033[33m'; RED=$'\033[31m'; RESET=$'\033[0m'
else
  BOLD=""; DIM=""; GREEN=""; YELLOW=""; RED=""; RESET=""
fi

info()  { printf '%s\n' "$*"; }
ok()    { printf '%s✓%s %s\n' "$GREEN" "$RESET" "$*"; }
warn()  { printf '%s!%s %s\n' "$YELLOW" "$RESET" "$*" >&2; }
die()   { printf '%s✗%s %s\n' "$RED" "$RESET" "$*" >&2; exit 1; }
head_() { printf '\n%s%s%s\n' "$BOLD" "$*" "$RESET"; }

usage() {
  cat <<EOF
${BOLD}codex-config installer${RESET}

Add usage limits, context usage, and session info to the Codex CLI footer.

${BOLD}USAGE${RESET}
  install.sh [options]

${BOLD}OPTIONS${RESET}
  -p, --preset <name>   Preset to install: minimal | balanced | verbose
                        (default: balanced)
  -n, --dry-run         Print the resulting config without writing it
  -u, --uninstall       Remove the managed [tui] block
  -c, --codex-home DIR  Use DIR instead of \$CODEX_HOME or ~/.codex
  -h, --help            Show this help

${BOLD}EXAMPLES${RESET}
  curl -fsSL ${REPO_URL}/raw/main/install.sh | sh
  curl -fsSL ${REPO_URL}/raw/main/install.sh | sh -s -- --preset verbose
  ./install.sh --dry-run --preset minimal
EOF
}

# --- presets --------------------------------------------------------------
#
# NOTE: these bodies are duplicated in ./config.toml and ./presets/*.toml.
# Run ./scripts/verify-sync.sh after editing either copy.

preset_minimal() {
  cat <<'EOF'
# ---------------------------------------------------------------------------
# codex-config · preset: minimal
# Rendered as: GPT-6.1-Sol default · Context 62% left · 5h 88% left
# ---------------------------------------------------------------------------

[tui]
status_line = [
  "model-with-reasoning",
  "context-remaining",
  "five-hour-limit",
]
status_line_use_colors = true
terminal_title = ["spinner", "project", "context-remaining"]
EOF
}

preset_balanced() {
  cat <<'EOF'
# ---------------------------------------------------------------------------
# codex-config · preset: balanced
# Rendered as: GPT-6.1-Sol default · main · ~/Projects/my-app · 272k window ·
#              Context 62% left · 5h 88% left · weekly 98% left · 128k used
# ---------------------------------------------------------------------------

[tui]
status_line = [
  "model-with-reasoning",
  "git-branch",
  "current-dir",
  "context-window-size",
  "context-remaining",
  "five-hour-limit",
  "weekly-limit",
  "used-tokens",
]
status_line_use_colors = true
terminal_title = ["spinner", "project", "model-with-reasoning", "context-remaining"]
EOF
}

preset_verbose() {
  cat <<'EOF'
# ---------------------------------------------------------------------------
# codex-config · preset: verbose
# Needs a wide terminal (120+ columns). Includes safety posture and live task
# progress. Rendered as: Working · GPT-6.1-Sol high · Fast on · main · +12 -3 ·
# PR #123 · 272k window · Context 62% left · 5h 88% left · 128k used · ...
# ---------------------------------------------------------------------------

[tui]
status_line = [
  "status",
  "model-with-reasoning",
  "reasoning",
  "fast-mode",
  "current-dir",
  "git-branch",
  "branch-changes",
  "pull-request-number",
  "context-window-size",
  "context-remaining",
  "five-hour-limit",
  "weekly-limit",
  "used-tokens",
  "total-input-tokens",
  "total-output-tokens",
  "permissions",
  "approval-mode",
  "task-progress",
  "codex-version",
]
status_line_use_colors = true
terminal_title = ["spinner", "project", "model-with-reasoning", "status", "context-remaining"]
EOF
}

preset_body() {
  case "$1" in
    minimal)  preset_minimal  ;;
    balanced) preset_balanced ;;
    verbose)  preset_verbose  ;;
    *)        die "Unknown preset '$1'. Choose: minimal, balanced, verbose" ;;
  esac
}

# --- helpers --------------------------------------------------------------

# Remove anything this installer previously wrote, plus any [tui] table.
#
# TOML forbids defining the same table twice, so appending a new [tui] block to
# a config that already has one is a hard parse error and Codex refuses to
# start. Two cases to handle:
#
#   1. A block we wrote before, wrapped in # >>> / # <<< sentinels. Removing
#      the whole block also cleans up its comment header, which keeps repeat
#      installs byte-for-byte idempotent.
#   2. A [tui] table someone wrote by hand. We drop the table so we can append
#      ours, but leave any comments above it alone rather than guessing which
#      ones belonged to it.
strip_managed_config() {
  awk '
    /^[ \t]*#[ \t]*>>>[ \t]*codex-config/ { skip = 1; next }
    /^[ \t]*#[ \t]*<<<[ \t]*codex-config/ { skip = 0; next }
    /^\[/ { skip = ($0 ~ /^\[tui\](\.|$)/) }
    !skip  { lines[++n] = $0 }
    END {
      last = n
      while (last > 0 && lines[last] ~ /^[[:space:]]*$/) last--
      for (i = 1; i <= last; i++) print lines[i]
    }
  '
}

BLOCK_BEGIN="# >>> codex-config managed block — edit in-session with /statusline, or re-run install.sh"
BLOCK_END="# <<< codex-config managed block"

validate_preset_items() {
  # Warn about item IDs that look wrong. Codex silently ignores unknown status
  # line items, so a typo just makes the item disappear with no error.
  local body="$1"
  local known
  known="model-name model-with-reasoning reasoning current-dir project-name \
hostname git-branch pull-request-number branch-changes status run-state \
permissions approval-mode approval context-remaining context-used \
five-hour-limit weekly-limit codex-version context-window-size used-tokens \
total-input-tokens total-output-tokens thread-credits estimated-thread-cost \
thread-id session-id fast-mode daybreak raw-output thread-name thread-title \
workspace-headline task-progress app-name project project-root thread"

  local warned=0 item
  while IFS= read -r item; do
    [ -z "$item" ] && continue
    case " $known " in
      *" $item "*) ;;
      *) warn "Unknown status line item '$item' — Codex will ignore it."; warned=1 ;;
    esac
  done < <(printf '%s\n' "$body" \
           | sed 's/[[:space:]]*#.*$//' \
           | sed -n '/^[[:space:]]*status_line[[:space:]]*=/,/]/p' \
           | grep -o '"[^"]*"' \
           | tr -d '"' || true)

  return "$warned"
}

check_codex_installed() {
  if ! command -v codex >/dev/null 2>&1; then
    warn "codex is not on your PATH."
    warn "Install it with:  npm install -g @openai/codex"
    warn "The config applies as soon as Codex is installed."
    return 0
  fi

  local version
  version="$(codex --version 2>/dev/null | awk '{print $NF}' || true)"
  [ -n "$version" ] && ok "Found codex $version"

  # Rather than guess a minimum version number, ask the binary directly:
  # only builds with the status line feature contain these identifiers.
  # grep follows symlinks, so a `codex` shim is fine as-is.
  if LC_ALL=C grep -aq 'five-hour-limit' "$(command -v codex)" 2>/dev/null; then
    ok "This build supports tui.status_line"
  else
    warn "Could not confirm this build supports tui.status_line."
    warn "If the footer looks unchanged, run 'codex update', then open"
    warn "Codex and type /statusline to check."
  fi
}

# --- arg parsing ----------------------------------------------------------

while [ $# -gt 0 ]; do
  case "$1" in
    -p|--preset)      PRESET="${2:-}"; shift 2 ;;
    -n|--dry-run)     DRY_RUN=1; shift ;;
    -u|--uninstall)   MODE="uninstall"; shift ;;
    -c|--codex-home)  CODEX_HOME_DIR="${2:-}"; shift 2 ;;
    -h|--help)        usage; exit 0 ;;
    *)                die "Unknown option '$1'. Run with --help." ;;
  esac
done

# --- main -----------------------------------------------------------------

CONFIG_FILE="$CODEX_HOME_DIR/config.toml"

head_ "codex-config"

if [ "$MODE" = "uninstall" ]; then
  [ -f "$CONFIG_FILE" ] || die "No config found at $CONFIG_FILE"

  BACKUP="$CONFIG_FILE.backup-$(date +%Y%m%d-%H%M%S)"
  cp "$CONFIG_FILE" "$BACKUP"

  TMP="$(mktemp)"
  strip_managed_config < "$CONFIG_FILE" > "$TMP"
  mv "$TMP" "$CONFIG_FILE"

  ok "Removed the [tui] block from $CONFIG_FILE"
  info "${DIM}Backup: $BACKUP${RESET}"
  info ""
  info "Restart Codex to apply."
  exit 0
fi

BODY="$(preset_body "$PRESET")"

check_codex_installed
validate_preset_items "$BODY" || true

EXISTING=""
[ -f "$CONFIG_FILE" ] && EXISTING="$CONFIG_FILE"

if [ "$DRY_RUN" -eq 1 ]; then
  head_ "Dry run — result would be written to $CONFIG_FILE"
  info "${DIM}--- existing config (minus its [tui] tables) ---${RESET}"
  if [ -n "$EXISTING" ]; then
    strip_managed_config < "$EXISTING"
  else
    info "${DIM}(no existing config)${RESET}"
  fi
  info "${DIM}--- appended ---${RESET}"
  printf '%s\n' "$BLOCK_BEGIN"
  printf '%s\n' "$BODY"
  printf '%s\n' "$BLOCK_END"
  exit 0
fi

mkdir -p "$CODEX_HOME_DIR"

if [ -n "$EXISTING" ]; then
  BACKUP="$CONFIG_FILE.backup-$(date +%Y%m%d-%H%M%S)"
  cp "$CONFIG_FILE" "$BACKUP"
  ok "Backed up to $BACKUP"
fi

TMP="$(mktemp)"
if [ -n "$EXISTING" ]; then
  strip_managed_config < "$EXISTING" > "$TMP"
fi
{
  [ -s "$TMP" ] && printf '\n'
  printf '%s\n' "$BLOCK_BEGIN"
  printf '%s\n' "$BODY"
  printf '%s\n' "$BLOCK_END"
} >> "$TMP"

# keep the destination's original permissions (config.toml is often 0600)
if [ -f "$CONFIG_FILE" ]; then
  chmod --reference="$CONFIG_FILE" "$TMP" 2>/dev/null || chmod 600 "$TMP"
else
  chmod 600 "$TMP"
fi

mv "$TMP" "$CONFIG_FILE"
ok "Wrote preset '$PRESET' to $CONFIG_FILE"

head_ "Next steps"
info "1. Restart Codex (or start a new session)."
info "2. The footer now shows your model, context usage, and plan limits."
info ""
info "${BOLD}Useful in-session:${RESET}"
info "  ${BOLD}/statusline${RESET}  interactive picker with live preview"
info "  ${BOLD}/status${RESET}      full rate-limit panel with reset times"
info ""
info "Want a different set of fields? Run:"
info "  ${DIM}$REPO_URL${RESET}"
info "and see ${BOLD}Available status line items${RESET} in the README."
