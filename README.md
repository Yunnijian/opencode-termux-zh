<p align="center">
  <a href="https://opencode.ai">
    <img src="https://raw.githubusercontent.com/C04-wq/opencode-termux/main/opencode-logo.svg" alt="OpenCode" width="64" height="80">
  </a>
</p>

<h1 align="center">opencode-termux</h1>

<p align="center">
  <a href="https://www.npmjs.com/package/opencode-termux"><img src="https://img.shields.io/npm/v/opencode-termux?style=for-the-badge" alt="npm"></a>
  <img src="https://img.shields.io/badge/Platform-Termux-green?style=for-the-badge" alt="Termux">
  <img src="https://img.shields.io/badge/Architecture-aarch64-blue?style=for-the-badge" alt="aarch64">
  <a href="https://github.com/C04-wq/opencode-termux/actions/workflows/auto-update.yml"><img src="https://img.shields.io/github/actions/workflow/status/C04-wq/opencode-termux/auto-update.yml?style=for-the-badge&label=release" alt="Release workflow"></a>
</p>

<p align="center"><b>OpenCode for Android Termux on ARM64 — automatic, verified, and root-free.</b></p>

`opencode-termux` packages OpenCode's official ARM64 musl build with the runtime required by Termux.

## One-click install (Termux)

```bash
pkg install -y curl
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Yunnijian/opencode-termux-zh/main/install.sh)"
```

If `curl` fails with a library mismatch like
`cannot locate symbol "SSL_set_quic_tls_transport_params"`, run
`pkg update -y && pkg upgrade -y` first, then rerun the command.

The script installs Node.js, Git, and this package, then prints how to start
OpenCode. The first launch downloads the OpenCode runtime and enables the
Chinese plugin automatically.

### Install via adb (rooted device)

If Termux is installed on an adb-connected device, run:

```bash
adb shell su -c 'PREFIX=/data/data/com.termux/files/usr; UID=$(stat -c %u $PREFIX/..); curl -fsSL https://raw.githubusercontent.com/Yunnijian/opencode-termux-zh/main/install.sh -o /data/local/tmp/opencode-zh-install.sh; su -g $UID -G 3003 $UID -c "env PREFIX=$PREFIX HOME=$PREFIX/../home PATH=$PREFIX/bin:/system/bin LD_LIBRARY_PATH=$PREFIX/lib TMPDIR=$PREFIX/tmp $PREFIX/bin/bash /data/local/tmp/opencode-zh-install.sh"'
```

The `-G 3003` (`inet`) group is required for DNS/network access on Android;
without it, package installation fails with "Could not resolve host".

This fork disables the upstream npm auto-update so the installed wrapper
keeps the Termux touch/IME and Chinese plugin changes.

## Install

On Termux aarch64:

```bash
npm install -g opencode-termux
opencode
```

The first run prepares everything needed by the runtime automatically. It installs missing Termux packages, downloads the matching release, verifies it, and starts OpenCode.

## First-run experience

Installation is intentionally quiet. Instead of command logs, it only shows short status messages such as:

```text
  ◇ Setting up Termux dependencies…
  ✓ Termux dependencies are ready
  ◇ Preparing OpenCode for Termux…
  ✓ OpenCode 1.18.4-8 is ready
```

Detailed command output is kept hidden unless an error occurs.

## Screenshots

<p align="center">
  <img src="https://raw.githubusercontent.com/C04-wq/opencode-termux/main/screenshots/screenshot-1.png" alt="OpenCode running in Termux" width="49%">
  <img src="https://raw.githubusercontent.com/C04-wq/opencode-termux/main/screenshots/screenshot-2.png" alt="OpenCode session in Termux" width="49%">
</p>

<p align="center">
  <img src="https://raw.githubusercontent.com/C04-wq/opencode-termux/main/screenshots/screenshot-3.png" alt="OpenCode coding workflow in Termux" width="49%">
  <img src="https://raw.githubusercontent.com/C04-wq/opencode-termux/main/screenshots/screenshot-4.png" alt="OpenCode interface in Termux" width="49%">
</p>


## Automatic dependency setup

Before installing or starting OpenCode, the wrapper checks for the runtime prerequisites. When needed, it installs them through Termux's `pkg` command:

- `curl` for release downloads
- `tar` for archive extraction
- `patchelf` for the Termux-compatible ELF interpreter
- `coreutils` for the update timeout command
- `ca-certificates` for HTTPS certificates
- `resolv-conf` for the DNS configuration used by the packaged musl runtime

Node.js and npm are the only prerequisites because npm is used to install this package:

```bash
pkg install nodejs
```

## How it works

| Feature | Behavior |
| --- | --- |
| Verified downloads | The installer checks the release SHA-256 against `release-checksums.json` bundled in npm. |
| Complete runtime | The OpenCode binary, musl loader, `libgcc`, and `libstdc++` are stored in `~/.opencode/`. The packaged musl resolver uses Termux's DNS configuration, so API connections work natively on Android. |
| Safe updates | A newer npm package is installed first. The working runtime is kept if npm or the network fails. |
| Version matching | `~/.opencode/.opencode-termux-version` ensures the runtime always matches the installed npm package. |
| OpenCode updates | OpenCode's internal updater is disabled so it cannot replace the Termux-compatible binary. |

```text
opencode
  │
  ├─ Check and install missing Termux dependencies
  ├─ Check the installed runtime and its version marker
  │   └─ If needed: download → verify SHA-256 → test → activate
  ├─ Check npm for a newer package (up to 10 seconds)
  │   └─ If newer: install package → restart wrapper → install matching runtime
  └─ Run ~/.opencode/opencode
```

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

## Chinese mode (中文模式)

Installation automatically registers the `opencode-zh-plugin` plugin in the
global config. It localizes the TUI home screen, sidebar title, slash
commands, and AI replies/reasoning. TUI hardcoded strings that OpenCode does
not expose to plugins remain English.

To disable it, remove `"opencode-zh-plugin"` from the `plugin` arrays in
`~/.config/opencode/opencode.json` (or `opencode.jsonc`) and
`~/.config/opencode/tui.json`.

## Automated releases

The [Build and publish Termux package](.github/workflows/auto-update.yml) workflow runs every six hours and can also be started manually.

1. It detects the latest official OpenCode release through GitHub's API.
2. It downloads `opencode-linux-arm64-musl.tar.gz` and verifies GitHub's SHA-256 digest.
3. It packages the binary with ARM64 musl, `libgcc`, and `libstdc++` runtime libraries. The musl runtime is built from pinned source with Termux's resolver path so it can use Android DNS without Proot.
4. It creates the release archive and records its SHA-256 in `release-checksums.json`.
5. It publishes the npm package, creates the GitHub Release, and commits the generated checksum metadata.

Publish jobs are serialized. If npm already has a version but its GitHub Release is missing, the workflow stops instead of generating an archive with a mismatched checksum.

## Update or repair

Running `opencode` normally checks for updates automatically.

```bash
# Check the latest published version
npm view opencode-termux version

# Update immediately
npm install -g opencode-termux@latest
opencode

# Reinstall the managed runtime without deleting the current files first
rm -f ~/.opencode/.opencode-termux-version
opencode
```

## Uninstall

```bash
npm uninstall -g opencode-termux
rm -rf ~/.opencode
```

The second command removes only the runtime managed by this package. OpenCode configuration, if any, is normally kept in `~/.config/opencode`.

## Project layout

```text
bin/opencode                       Update and launch wrapper
install.js                          Quiet verified installer and dependency setup
release-checksums.json              SHA-256 for the release matching the npm package
scripts/build-android-release.sh    Reproducible ARM64/Termux package builder
.github/workflows/auto-update.yml   Automated detection and publishing workflow
```

## License

[MIT](LICENSE)
