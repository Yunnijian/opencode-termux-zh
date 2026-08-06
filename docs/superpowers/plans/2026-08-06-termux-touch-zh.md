# Termux Touch/IME and Chinese Plugin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make opencode-termux work well with Termux touch input by default and enable the `opencode-zh-plugin` Chinese locale plugin during installation.

**Architecture:** The bash wrapper sources a small helper that exports `OPENCODE_DISABLE_MOUSE=1` unless the user opted in via environment or `tui.json`. `install.js` invokes a small script that runs `opencode plugin opencode-zh-plugin --global`, which idempotently updates the user's global config.

**Tech Stack:** Bash, Node.js (`install.js`), OpenCode CLI plugin system, npm packaging.

## Global Constraints

- OpenCode version floor: `>= 1.18.0` (the plugin requires this; package targets `1.18.13-0`).
- Platform: Termux on aarch64 only.
- Do not overwrite existing `opencode.json` / `opencode.jsonc` / `tui.json` content; plugin registration is done with the idempotent `opencode plugin` command.
- Default mouse capture must be disabled unless the user explicitly opts in via `OPENCODE_DISABLE_MOUSE` or `tui.json` `"mouse": true`.
- Plugin install failure must warn and not block opencode startup.
- Do not attempt full TUI hardcoded-string localization; only plugin-covered surfaces are in scope.
- Every production change needs a failing test observed first (configuration/installer behavior is verified with shell tests and local integration checks).

---

## File Structure

- `scripts/termux-mouse-default.sh` — new; defines `opencode_termux_default_mouse()`.
- `scripts/install-zh-plugin.sh` — new; installs `opencode-zh-plugin` via the opencode CLI.
- `scripts/test-termux-mouse-default.sh` — new; tests mouse default behavior.
- `scripts/test-install-zh-plugin.sh` — new; tests plugin installer with a fake opencode binary.
- `bin/opencode` — modify; source and call mouse default helper.
- `install.js` — modify; call plugin installer after runtime setup.
- `package.json` — modify; include `scripts/` in npm `files`.
- `README.md` — modify; document touch/IME and Chinese mode.

---

### Task 1: Termux Mouse Default Helper

**Files:**
- Create: `scripts/termux-mouse-default.sh`
- Test: `scripts/test-termux-mouse-default.sh`
- Modify: `bin/opencode`

**Interfaces:**
- Consumes: `$HOME`, `$XDG_CONFIG_HOME`, `$OPENCODE_DISABLE_MOUSE`.
- Produces: `opencode_termux_default_mouse()` — a function that may export `OPENCODE_DISABLE_MOUSE=1`; `bin/opencode` calls it after sourcing the file.

- [ ] **Step 1: Write the failing test**

Create `scripts/test-termux-mouse-default.sh`:

```bash
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash scripts/test-termux-mouse-default.sh`

Expected: FAIL with `No such file or directory` when sourcing `termux-mouse-default.sh`.

- [ ] **Step 3: Create the helper**

Create `scripts/termux-mouse-default.sh`:

```bash
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
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash scripts/test-termux-mouse-default.sh`

Expected: `PASS: all termux-mouse-default cases`

- [ ] **Step 5: Wire the helper into the wrapper**

Modify `bin/opencode`: after the `DIR="$(cd "$(dirname "$SOURCE")/.." && pwd)"` line, add:

```bash
source "$DIR/scripts/termux-mouse-default.sh"
opencode_termux_default_mouse
```

- [ ] **Step 6: Integration-check mouse sequences**

Run:

```bash
TMP="$(mktemp -d "$HOME/oc-mouse-check-XXXXXX")"
mkdir -p "$TMP/opencode"
printf '{"plugin":[]}\n' > "$TMP/opencode/tui.json"
XDG_CONFIG_HOME="$TMP" script -q -c "timeout 5 ./bin/opencode --print-logs" "$HOME/oc-mouse-check.log" >/dev/null 2>&1
grep -aoP '\x1b\[\?100[0236][hl]' "$HOME/oc-mouse-check.log" | sort | uniq -c
```

Expected: no lines containing `?1000h`, `?1002h`, `?1003h`, or `?1006h`.
Run from the repository root so `./bin/opencode` is the worktree's modified wrapper.

- [ ] **Step 7: Commit**

```bash
git add scripts/termux-mouse-default.sh scripts/test-termux-mouse-default.sh bin/opencode
git commit -m "feat: disable TUI mouse capture by default for Termux touch input"
```

---

### Task 2: Chinese Plugin Installer

**Files:**
- Create: `scripts/install-zh-plugin.sh`
- Test: `scripts/test-install-zh-plugin.sh`
- Modify: `install.js`
- Modify: `package.json`

**Interfaces:**
- Consumes: `$OPENCODE_BIN` (path to opencode binary), `$HOME`, `$XDG_CONFIG_HOME`.
- Produces: global `opencode.json` / `tui.json` updated with `"plugin": ["opencode-zh-plugin"]` when the real opencode CLI runs.
- `install.js` calls `bash scripts/install-zh-plugin.sh` with `OPENCODE_BIN` and runtime env set.

- [ ] **Step 1: Write the failing test**

Create `scripts/test-install-zh-plugin.sh`:

```bash
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash scripts/test-install-zh-plugin.sh`

Expected: FAIL with `No such file or directory` when running `install-zh-plugin.sh`.

- [ ] **Step 3: Create the installer script**

Create `scripts/install-zh-plugin.sh`:

```bash
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
```

Then make the new scripts executable:

```bash
chmod +x scripts/install-zh-plugin.sh scripts/test-install-zh-plugin.sh
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash scripts/test-install-zh-plugin.sh`

Expected: `PASS: install-zh-plugin tests`

- [ ] **Step 5: Call the installer from install.js**

Modify `install.js`: after `fs.writeFileSync(VERSION_FILE, ...)` and before `success(...)`, add:

```js
try {
  execFileSync("bash", [path.join(__dirname, "scripts", "install-zh-plugin.sh")], {
    stdio: "inherit",
    env: {
      ...process.env,
      OPENCODE_BIN: path.join(OPENCODE_DIR, "opencode"),
      LD_PRELOAD: path.join(OPENCODE_DIR, "ld-musl-aarch64.so.1"),
      LD_LIBRARY_PATH: OPENCODE_DIR,
      SSL_CERT_FILE: CERTIFICATE_FILE,
      OPENCODE_DISABLE_AUTOUPDATE: "1",
    },
    timeout: 120000,
  });
} catch (error) {
  console.warn(`Warning: could not install Chinese plugin: ${commandError(error)}`);
}
```

- [ ] **Step 6: Include scripts/ in the npm package**

Modify `package.json` `files` array:

```json
"files": [
  "bin/",
  "install.js",
  "release-checksums.json",
  "scripts/",
  "README.md"
],
```

- [ ] **Step 7: Integration-check plugin install in a temp config**

Run:

```bash
TMP="$(mktemp -d "$HOME/oc-plugin-check-XXXXXX")"
LD_PRELOAD="$HOME/.opencode/ld-musl-aarch64.so.1" \
LD_LIBRARY_PATH="$HOME/.opencode" \
SSL_CERT_FILE=/data/data/com.termux/files/usr/etc/tls/cert.pem \
XDG_CONFIG_HOME="$TMP/.config" \
"$HOME/.opencode/opencode" plugin opencode-zh-plugin --global
cat "$TMP/.config/opencode/opencode.jsonc"
cat "$TMP/.config/opencode/tui.json"
```

Expected: both files contain `opencode-zh-plugin`.

- [ ] **Step 8: Commit**

```bash
git add scripts/install-zh-plugin.sh scripts/test-install-zh-plugin.sh install.js package.json
git commit -m "feat: install opencode-zh-plugin by default"
```

---

### Task 3: Documentation, Final Verification, and Push

**Files:**
- Modify: `README.md`
- Modify: `docs/superpowers/specs/2026-08-06-termux-touch-zh-design.md` (already committed; no changes)

**Interfaces:**
- Consumes: behavior from Tasks 1 and 2.
- Produces: user-facing documentation for touch/IME and Chinese mode.

- [ ] **Step 1: Document touch/IME behavior**

In `README.md`, after the "How it works" table, add:

```markdown
## Termux touch input

Termux only shows the soft keyboard on tap while a TUI app is not capturing
the mouse. OpenCode captures the mouse by default, so this package exports
`OPENCODE_DISABLE_MOUSE=1` unless you explicitly opt in.

To re-enable mouse capture:

```json
// ~/.config/opencode/tui.json
{ "mouse": true }
```

or run opencode with `OPENCODE_DISABLE_MOUSE=0 opencode`.
```

- [ ] **Step 2: Document Chinese mode**

In `README.md`, add a section after "Termux touch input":

```markdown
## Chinese mode (中文模式)

Installation automatically registers the `opencode-zh-plugin` plugin in the
global config. It localizes the TUI home screen, sidebar title, slash
commands, and AI replies/reasoning. TUI hardcoded strings that OpenCode does
not expose to plugins remain English.

To disable it, remove `"opencode-zh-plugin"` from the `plugin` arrays in
`~/.config/opencode/opencode.json` and `~/.config/opencode/tui.json`.
```

- [ ] **Step 3: Run all unit tests**

Run:

```bash
bash scripts/test-termux-mouse-default.sh
bash scripts/test-install-zh-plugin.sh
```

Expected: both print PASS.

- [ ] **Step 4: Final integration verification**

Run:

```bash
TMP="$(mktemp -d "$HOME/oc-final-check-XXXXXX")"
mkdir -p "$TMP/.config/opencode"
printf '{"plugin":[]}\n' > "$TMP/.config/opencode/tui.json"
XDG_CONFIG_HOME="$TMP/.config" script -q -c "timeout 5 ./bin/opencode --print-logs" "$HOME/oc-final.log" >/dev/null 2>&1
grep -aoP '\x1b\[\?100[0236][hl]' "$HOME/oc-final.log" | sort | uniq -c
```

Expected: no `?1000h` / `?1002h` / `?1003h` / `?1006h` output.
Run from the repository root so `./bin/opencode` is the worktree's modified wrapper.

- [ ] **Step 5: Commit documentation**

```bash
git add README.md
git commit -m "docs: document Termux touch input and Chinese mode"
```

- [ ] **Step 6: Merge to main and push to GitHub**

```bash
git checkout main
git merge termux-touch-zh
git push origin main
```

Expected: `main` updated on `origin` (`https://github.com/C04-wq/opencode-termux.git`). This is the final step after the whole-branch review is clean; run it from the main checkout, not from a feature-branch subagent. If authentication fails, stop and report the exact error; do not force-push.
