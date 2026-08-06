#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# Installs opencode-zh-plugin into OpenCode's global config.
# OPENCODE_BIN overrides the opencode binary used (default: ~/.opencode/opencode).
OPENCODE_BIN="${OPENCODE_BIN:-$HOME/.opencode/opencode}"

if [ ! -x "$OPENCODE_BIN" ]; then
  echo "Warning: opencode binary not found at $OPENCODE_BIN; skipping Chinese plugin install." >&2
  exit 0
fi

if ! "$OPENCODE_BIN" plugin opencode-zh-plugin --global; then
  echo "Warning: failed to install opencode-zh-plugin; opencode will start in English." >&2
  exit 0
fi
