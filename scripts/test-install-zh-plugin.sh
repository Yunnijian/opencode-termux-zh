#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP="$(mktemp -d "$HOME/.zh-plugin-test-XXXXXX")"
trap 'rm -r "$TMP"' EXIT

FAIL=0

FAKE="$TMP/fake-opencode"
cat > "$FAKE" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
printf '%s\n' "$@" > "$RECORD_FILE"
mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
printf '{"plugin":["opencode-zh-plugin"]}\n' > "${XDG_CONFIG_HOME:-$HOME/.config}/opencode/opencode.json"
exit "${FAKE_EXIT:-0}"
EOF
chmod +x "$FAKE"

# Success path
RECORD_FILE="$TMP/args"
export RECORD_FILE
FAKE_EXIT=0 OPENCODE_BIN="$FAKE" XDG_CONFIG_HOME="$TMP/xdg" \
  "$SCRIPT_DIR/install-zh-plugin.sh" >/dev/null 2>&1 || FAIL=1
if [ ! -f "$RECORD_FILE" ]; then
  echo "FAIL: success path did not invoke opencode" >&2
  FAIL=1
fi
if ! grep -q '^plugin$' "$RECORD_FILE" || ! grep -q '^opencode-zh-plugin$' "$RECORD_FILE" || ! grep -q '^--global$' "$RECORD_FILE"; then
  echo "FAIL: success path args wrong: $(tr '\n' ' ' < "$RECORD_FILE")" >&2
  FAIL=1
fi
if [ ! -f "$TMP/xdg/opencode/opencode.json" ]; then
  echo "FAIL: success path did not write config" >&2
  FAIL=1
fi

# Failure path: fake exits 1; installer must still exit 0 and warn
RECORD_FILE="$TMP/args2"
export RECORD_FILE
FAKE_EXIT=1 OPENCODE_BIN="$FAKE" XDG_CONFIG_HOME="$TMP/xdg2" \
  "$SCRIPT_DIR/install-zh-plugin.sh" >/dev/null 2>"$TMP/err.log" || FAIL=1
if ! grep -q 'failed to install opencode-zh-plugin' "$TMP/err.log"; then
  echo "FAIL: failure path should warn" >&2
  FAIL=1
fi

# Missing binary path: skip quietly with a warning
OPENCODE_BIN="$TMP/nope" XDG_CONFIG_HOME="$TMP/xdg3" \
  "$SCRIPT_DIR/install-zh-plugin.sh" >/dev/null 2>"$TMP/err2.log" || FAIL=1
if ! grep -q 'skipping Chinese plugin install' "$TMP/err2.log"; then
  echo "FAIL: missing binary should warn and skip" >&2
  FAIL=1
fi

if [ "$FAIL" -ne 0 ]; then
  echo "FAIL: install-zh-plugin tests" >&2
  exit 1
fi
echo "PASS: install-zh-plugin tests"
