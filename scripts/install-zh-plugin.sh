#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# Installs opencode-zh-plugin into OpenCode's global config.
# OPENCODE_BIN overrides the opencode binary used (default: ~/.opencode/opencode).
OPENCODE_BIN="${OPENCODE_BIN:-$HOME/.opencode/opencode}"
OPENCODE_DIR="${OPENCODE_DIR:-$(dirname "$OPENCODE_BIN")}"

if [ ! -x "$OPENCODE_BIN" ]; then
  echo "Warning: opencode binary not found at $OPENCODE_BIN; skipping Chinese plugin install." >&2
  exit 0
fi

run_opencode() {
  if [ -f "$OPENCODE_DIR/ld-musl-aarch64.so.1" ]; then
    env LD_PRELOAD="$OPENCODE_DIR/ld-musl-aarch64.so.1" LD_LIBRARY_PATH="$OPENCODE_DIR" "$OPENCODE_BIN" "$@"
  else
    "$OPENCODE_BIN" "$@"
  fi
}

if ! run_opencode plugin opencode-zh-plugin --global; then
  echo "Warning: failed to install opencode-zh-plugin; opencode will start in English." >&2
  exit 0
fi
