---
name: DmgInstall
version: 0.1.0
description: "Idempotent macOS .app install from a DMG: curl + hdiutil attach (random mountpoint) + cp -R + detach + codesign verify + CLI symlink. The reusable pattern for rapid-ship AppKit apps that intentionally bypass Homebrew. USE WHEN adding scripts/install/<app>.sh for a DMG-distributed app, deciding whether an app belongs in Brewfile or as a manual install, debugging hdiutil mount failures, or reasoning about idempotency for App-bundle installs."
sources:
    - https://ss64.com/mac/hdiutil.html
    - https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/Procedures/Procedures.html
    - https://docs.github.com/en/repositories/releasing-projects-on-github/linking-to-releases
---

# DmgInstall

The reusable install pattern for `.app` bundles delivered via DMG, outside Homebrew. Used when an app's release cadence makes unattended `brew upgrade` unsafe (rapid-ship AppKit apps, agents, channel releases). Pairs with a Brewfile tombstone comment explaining why the app is intentionally not a cask — see [HomebrewToolkit](../HomebrewToolkit/SKILL.md).

Reference implementation: [`scripts/install/cmux.sh`](../../scripts/install/cmux.sh). Every new DMG-installed app should mirror its shape unless there's a specific reason to deviate.

## When to use DMG-install over a Brewfile cask

| Constraint                                                     | DMG-install | Brewfile cask |
| -------------------------------------------------------------- | ----------- | ------------- |
| Upstream releases weekly with breaking changes                  | YES         | no            |
| Unattended `brew upgrade` would overwrite a known-good version  | YES         | no            |
| App ships via GitHub Releases (canonical-latest URL exists)    | well-suited | possible      |
| App has its own self-update mechanism                          | YES         | no            |
| App is stable, semver-disciplined, multi-year maintained        | overkill    | YES           |

When in doubt, start with a Brewfile cask. Migrate to DMG-install only if you've been bitten by an unattended upgrade.

## Canonical install pattern

A DMG installer script in `scripts/install/<app>.sh` should:

1. **Source `env.sh`** for `DEV_DIR`, etc.
2. **Skip if already installed** unless `--force` is passed.
3. **Download to a tempfile** via `curl -fL --progress-bar -o <tmp> <url>` with `trap` cleanup.
4. **Mount the DMG** via `hdiutil attach -nobrowse -quiet -mountrandom /tmp` and parse the mount point.
5. **Validate the .app exists** at the mount point before copying.
6. **Remove the old .app** if `--force` and an old version is present.
7. **Copy the .app** to `/Applications/` via `cp -R`.
8. **Detach the DMG** via `hdiutil detach -quiet`.
9. **Verify code signature** via `codesign --verify --quiet` (warning-not-fail).
10. **Create a CLI symlink** if the app ships a CLI (`<App>.app/Contents/Resources/bin/<tool>` → `~/.local/bin/<tool>`).
11. **Print next-steps hints** for things the script can't do (e.g., `cmux hooks setup`).

## Canonical-latest GitHub releases URL

Use the redirector path so the script doesn't pin to a version:

```
https://github.com/<owner>/<repo>/releases/latest/download/<asset-filename>
```

GitHub redirects to the actual asset of the latest release. Pinning to a version (`/releases/download/v1.2.3/<asset>`) defeats the purpose of opt-out-of-cask — you'd be hardcoding an upgrade decision into the script.

If upstream uses a non-GitHub release artifact (their own CDN, Cloudflare R2, etc.), use whatever "latest stable" URL they provide. Document the URL contract in a comment so a future session knows whether the URL guarantees freshness or just last-time-the-script-was-written.

## Idempotency

```sh
if [[ -d "${CMUX_APP}" && ${FORCE} -eq 0 ]]; then
    echo "skip:cmux (${CMUX_APP} already installed; pass --force to reinstall)"
    exit 0
fi
```

Skip on presence of the `.app`. `--force` removes the existing `.app` before reinstalling (avoids the `cp -R` merging old + new bundle contents). Always print the skip reason so re-running the orchestrator is informative, not silent.

## hdiutil attach safely

```sh
MOUNT_POINT=$(hdiutil attach "${DMG_TMP}" -nobrowse -quiet -mountrandom /tmp 2>/dev/null | \
    awk '/\/Volumes/ {print $NF; exit}' | tr -d '[:space:]')
if [[ -z "${MOUNT_POINT}" || ! -d "${MOUNT_POINT}/<App>.app" ]]; then
    echo "fail:<app> (DMG mount failed or no <App>.app inside)"
    exit 1
fi
```

Why each flag:

- `-nobrowse` — don't show the DMG in Finder sidebar
- `-quiet` — no chatty output (we parse `hdiutil`'s default output for the mount point; `-quiet` doesn't suppress that)
- `-mountrandom /tmp` — random mount point under `/tmp` instead of `/Volumes/<DMGName>`. Avoids collision when re-running before previous detach completed.

The `awk` line picks the line containing `/Volumes/` (the actual mount path; `hdiutil` prints a header line too) and extracts the last whitespace-separated field — which is the mount point.

`tr -d '[:space:]'` strips trailing whitespace from the mount-point string. Without it, downstream path joins can break.

## Copy and detach

```sh
cp -R "${MOUNT_POINT}/<App>.app" /Applications/ || {
    hdiutil detach "${MOUNT_POINT}" -quiet
    echo "fail:<app> (copy to /Applications failed)"
    exit 1
}

hdiutil detach "${MOUNT_POINT}" -quiet
```

`cp -R` over `ditto`: both work for `.app` bundles. `cp -R` is faster and POSIX-portable; `ditto` preserves extended attributes more aggressively (useful for code-signed apps where xattrs carry signature metadata) but is macOS-only. Use `cp -R` unless you observe signature breakage afterward.

Always detach in the failure path too — leaving a DMG mounted leaks a device entry.

## Code signature verification

```sh
codesign --verify --quiet "${CMUX_APP}" 2>&1 || {
    echo "warn:cmux (code signature verification failed — proceed with caution)"
}
```

`codesign --verify` exits non-zero if the bundle isn't signed or the signature is invalid. **Warn, don't fail** — some apps ship unsigned (ad-hoc signed, notarized but signature stripped during DMG conversion). The script's job is to surface the situation, not to enforce a security policy.

For stricter checks, layer `spctl --assess --type execute` (Gatekeeper assessment) on top. Most install scripts don't need this; the warn-on-codesign-fail is sufficient for the use case.

## CLI symlink

When the app ships a CLI binary inside the bundle (cmux, Visual Studio Code, etc.):

```sh
mkdir -p "$(dirname "${CLI_SYMLINK}")"
ln -sf "${CMUX_APP}/Contents/Resources/bin/cmux" "${CLI_SYMLINK}"
```

`ln -sf` overwrites any existing symlink. Symlink target: `~/.local/bin/<tool>` (assumes `~/.local/bin` is in PATH, which `dotzsh` / `prezto` add by default).

Verify post-symlink:

```sh
if command -v <tool> >/dev/null 2>&1; then
    echo "ok:<tool> ($(command <tool> --version 2>&1 | head -1))"
else
    echo "warn:<tool> installed but CLI not on PATH (expected ~/.local/bin in PATH)"
fi
```

## Post-install hints

Some apps need a one-time setup that the script can't do (Accessibility opt-in, hooks wiring, App Store auth):

```sh
echo "      next: launch <app> from /Applications, then run \`<app> hooks setup\`"
echo "            to wire Claude Code lifecycle hooks into ~/.claude/settings.json"
```

Print these *after* successful install so the user knows the manual steps that follow.

## Common pitfalls

| Symptom                                                                | Cause / Fix                                                                                                              |
| ---------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| `hdiutil attach` succeeds but mount point parsing returns empty        | `-quiet` suppressed mount output. Drop `-quiet` and parse stderr / use `plutil -extract`.                                |
| `cp -R` copies into existing `.app` instead of replacing                | Bundle merging. Remove the old `.app` first when `--force` is passed.                                                    |
| `codesign --verify` fails on a notarized app                            | Notarization stripped the embedded signature. Verify with `spctl --assess --type execute` instead.                       |
| CLI symlink works in script but not in next session                     | `~/.local/bin` not in PATH. Add to shell init: `export PATH="$HOME/.local/bin:$PATH"`.                                   |
| DMG download succeeds but file is HTML (login wall)                    | Upstream changed asset URL. Print HTTP status from `curl -w "%{http_code}"` to diagnose.                                  |
| Re-running the script downloads the DMG every time                     | Idempotency check (`-d "${APP}"`) missing or wrong path. Verify with `ls /Applications/<Name>.app`.                       |
| Trap cleanup deleted DMG before failure-path detach succeeded           | Put `trap 'rm -f "${DMG_TMP}"' EXIT` at the top; ensure failure-path `hdiutil detach` runs before the trap fires.        |

## Pairing with Brewfile tombstone

Every DMG-install script needs a matching tombstone in `manifests/Brewfile` explaining why the app is *intentionally* not a cask:

```ruby
# <app> — intentionally NOT installed via Homebrew. Reproduced on fresh
# Mac by `scripts/install/<app>.sh`, which curls the canonical-latest DMG
# from <github releases url> and drops <app>.app into /Applications.
# Rationale: <app> ships rapidly; we'd rather opt into upgrades manually
# than have `brew upgrade` overwrite a known-good version.
```

The tombstone is load-bearing. Without it, a future session sees no cask declaration and "fixes" it by adding `cask "<app>"`, which silently competes with the manual install. The comment makes the absence intentional and traceable.
