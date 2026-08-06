#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/termux-mouse-default.sh"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_unset() {
  if [ -n "${OPENCODE_DISABLE_MOUSE:-}" ]; then
    fail "$1 (expected unset, got '${OPENCODE_DISABLE_MOUSE}')"
  fi
}

assert_eq() {
  if [ "${OPENCODE_DISABLE_MOUSE:-}" != "$1" ]; then
    fail "$2 (expected '$1', got '${OPENCODE_DISABLE_MOUSE:-<unset>}')"
  fi
}

# Case 1: no tui.json -> default disable
(
  unset OPENCODE_DISABLE_MOUSE
  TMP="$(mktemp -d "$HOME/.termux-mouse-test-XXXXXX")"
  XDG_CONFIG_HOME="$TMP" HOME="$TMP"
  opencode_termux_default_mouse
  assert_eq 1 "case 1: no config should disable mouse"
  rm -r "$TMP"
)

# Case 2: tui.json "mouse": true -> leave unset
(
  unset OPENCODE_DISABLE_MOUSE
  TMP="$(mktemp -d "$HOME/.termux-mouse-test-XXXXXX")"
  mkdir -p "$TMP/opencode"
  printf '{"mouse": true}\n' > "$TMP/opencode/tui.json"
  XDG_CONFIG_HOME="$TMP" HOME="$TMP"
  opencode_termux_default_mouse
  assert_unset "case 2: explicit mouse true should stay enabled"
  rm -r "$TMP"
)

# Case 3: tui.json "mouse": false -> disable
(
  unset OPENCODE_DISABLE_MOUSE
  TMP="$(mktemp -d "$HOME/.termux-mouse-test-XXXXXX")"
  mkdir -p "$TMP/opencode"
  printf '{"mouse": false}\n' > "$TMP/opencode/tui.json"
  XDG_CONFIG_HOME="$TMP" HOME="$TMP"
  opencode_termux_default_mouse
  assert_eq 1 "case 3: explicit mouse false should disable"
  rm -r "$TMP"
)

# Case 4: user env override stays
(
  export OPENCODE_DISABLE_MOUSE=0
  TMP="$(mktemp -d "$HOME/.termux-mouse-test-XXXXXX")"
  XDG_CONFIG_HOME="$TMP" HOME="$TMP"
  opencode_termux_default_mouse
  assert_eq 0 "case 4: user env override should be respected"
  rm -r "$TMP"
)

echo "PASS: all termux-mouse-default cases"
