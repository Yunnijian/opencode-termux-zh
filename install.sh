#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# One-click installer for opencode-termux-zh (OpenCode for Termux with
# touch/IME support and the Chinese locale plugin).
#
# Usage:
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/Yunnijian/opencode-termux-zh/main/install.sh)"

export PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
export HOME="${HOME:-/data/data/com.termux/files/home}"
export PATH="$PREFIX/bin:$PATH"
export LD_LIBRARY_PATH="$PREFIX/lib"
export TMPDIR="${TMPDIR:-$PREFIX/tmp}"
mkdir -p "$TMPDIR"

if [ "$(id -u)" = "0" ]; then
  TERMUX_UID="$(stat -c %u "$PREFIX/..")"
  if [ -f "$0" ]; then
    echo "◇ Detected root; re-running as Termux user (uid $TERMUX_UID, inet group)…"
    exec su -g "$TERMUX_UID" -G 3003 "$TERMUX_UID" -c \
      "env PREFIX='$PREFIX' HOME='$HOME' PATH='$PREFIX/bin:/system/bin' LD_LIBRARY_PATH='$PREFIX/lib' TMPDIR='$TMPDIR' '$PREFIX/bin/bash' '$0'"
  else
    echo "Error: pkg refuses to run as root. Download this script to a file and run:" >&2
    echo "  su -g $TERMUX_UID -G 3003 $TERMUX_UID -c 'bash /data/local/tmp/opencode-zh-install.sh'" >&2
    exit 1
  fi
fi

REPO_URL="${REPO_URL:-https://github.com/Yunnijian/opencode-termux-zh.git}"
INSTALL_DIR="${INSTALL_DIR:-$HOME/opencode-termux-zh}"

if ! command -v pkg >/dev/null 2>&1; then
  echo "Error: this installer must run inside Termux (pkg was not found)." >&2
  exit 1
fi

if [ "${SKIP_UPGRADE:-0}" != "1" ]; then
  echo "◇ Refreshing Termux package index…"
  pkg update -y
  echo "◇ Upgrading Termux packages (fixes curl/OpenSSL library mismatches)…"
  pkg upgrade -y
fi

echo "◇ Installing Termux dependencies (nodejs, git, curl)…"
pkg install -y nodejs git curl

if [ -d "$INSTALL_DIR/.git" ]; then
  echo "◇ Updating existing checkout at $INSTALL_DIR…"
  git -C "$INSTALL_DIR" pull --ff-only
else
  echo "◇ Cloning opencode-termux-zh into $INSTALL_DIR…"
  git clone --depth 1 "$REPO_URL" "$INSTALL_DIR"
fi

echo "◇ Installing opencode wrapper globally…"
npm install -g "$INSTALL_DIR"

echo
echo "✓ Installation complete."
echo "  Run 'opencode' to start. First launch will download the OpenCode"
echo "  runtime and enable the Chinese plugin automatically."
