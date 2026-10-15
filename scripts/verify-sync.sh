#!/usr/bin/env bash
#
# Guards against drift between install.sh's embedded presets and the
# human-readable copies in ./config.toml and ./presets/*.toml.
#
# Run this before committing:
#   ./scripts/verify-sync.sh

set -euo pipefail

cd "$(dirname "$0")/.."

RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; DIM=$'\033[2m'; RESET=$'\033[0m'
[ -t 1 ] || { RED=""; GREEN=""; YELLOW=""; DIM=""; RESET=""; }

fails=0

# Every status line item identifier Codex 0.53+ understands.
KNOWN_ITEMS="model-name model-with-reasoning reasoning current-dir project-name \
hostname git-branch pull-request-number branch-changes status run-state \
permissions approval-mode approval context-remaining context-used \
five-hour-limit weekly-limit codex-version context-window-size used-tokens \
total-input-tokens total-output-tokens thread-credits estimated-thread-cost \
thread-id session-id fast-mode daybreak raw-output thread-name thread-title \
workspace-headline task-progress"

# Strip trailing `#` comments. Must happen before anything else: a comment
# like `# e.g. "GPT-6.1-Sol"` contains quotes and would confuse extraction.
strip_comments() {
  sed 's/[[:space:]]*#.*$//' "$1"
}

# Strip comments/blank lines/trailing space so only real config remains.
normalize() {
  strip_comments "$1" \
    | grep -vE '^\s*$' \
    | sed 's/[[:space:]]\+$//'
}

# Items listed in a status_line array, one per line.
items_in() {
  strip_comments "$1" \
    | sed -n '/^[[:space:]]*status_line[[:space:]]*=/,/]/p' \
    | grep -o '"[^"]*"' \
    | tr -d '"' || true
}

check_items() {
  local file="$1" label="$2" item
  while IFS= read -r item; do
    [ -z "$item" ] && continue
    case " $KNOWN_ITEMS " in
      *" $item "*) ;;
      *) printf '%s✗%s %s: unknown item %s\n' "$RED" "$RESET" "$label" "$item"; fails=$((fails + 1)) ;;
    esac
  done < <(items_in "$file")
}

echo "== checking status line item identifiers =="
for f in config.toml presets/*.toml; do
  check_items "$f" "$f"
done
[ "$fails" -eq 0 ] && printf '%s✓%s all item identifiers are valid\n' "$GREEN" "$RESET"

echo
echo "== checking presets match install.sh =="

TMP_HOME="$(mktemp -d)"
trap 'rm -rf "$TMP_HOME"' EXIT

sync_check() {
  local preset="$1" src="$2"
  local generated="$TMP_HOME/$preset.toml"

  # Install into an empty CODEX_HOME and take the result.
  ./install.sh --preset "$preset" --codex-home "$TMP_HOME" >/dev/null
  cp "$TMP_HOME/config.toml" "$generated"

  if diff -u <(normalize "$src") <(normalize "$generated") >"$TMP_HOME/$preset.diff"; then
    printf '%s✓%s %s matches install.sh\n' "$GREEN" "$RESET" "$src"
  else
    printf '%s✗%s %s does NOT match install.sh\n' "$RED" "$RESET" "$src"
    cat "$TMP_HOME/$preset.diff"
    fails=$((fails + 1))
  fi
}

sync_check minimal  presets/minimal.toml
sync_check balanced presets/balanced.toml
sync_check verbose  presets/verbose.toml

echo
if [ "$fails" -eq 0 ]; then
  printf '%s✓%s everything is in sync\n' "$GREEN" "$RESET"
  exit 0
else
  printf '%s✗%s %d problem(s) found\n' "$RED" "$RESET" "$fails"
  exit 1
fi
