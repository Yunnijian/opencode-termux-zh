#!/data/data/com.termux/files/usr/bin/bash

# Termux only shows the soft keyboard on tap while mouse tracking is inactive.
# OpenCode enables mouse capture by default, so opencode-termux disables it
# unless the user explicitly opts in via OPENCODE_DISABLE_MOUSE or tui.json.
opencode_termux_default_mouse() {
  if [ -n "${OPENCODE_DISABLE_MOUSE:-}" ]; then
    return 0
  fi

  local config_file="${XDG_CONFIG_HOME:-$HOME/.config}/opencode/tui.json"
  if [ -f "$config_file" ] && grep -qE '"mouse"[[:space:]]*:[[:space:]]*true' "$config_file" 2>/dev/null; then
    return 0
  fi

  export OPENCODE_DISABLE_MOUSE=1
}
