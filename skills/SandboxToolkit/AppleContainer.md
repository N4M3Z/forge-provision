# Apple container operations (macOS)

Apple container runs each Linux container in its own lightweight VM via the Virtualization framework: the strongest container boundary on macOS, with no Docker engine. Requires macOS 26 and Apple Silicon. Install with `brew install container` (in forge-provision: `scripts/install/container.sh`).

## Preflight

1. Probe the service: `container system status`. If not running and installed via Homebrew, start via the keg path: `/opt/homebrew/opt/container/bin/container system start --enable-kernel-install` (the flag suppresses the interactive first-run kernel prompt; the keg path matters, see Gotchas). A pkg install's `/usr/local/bin/container` starts directly.
2. Trust stderr, not exit codes. gRPC transport failures print `Error: unavailable (14): Transport became inactive` yet still exit 0. Health-check pattern: `container image ls 2>&1 | grep -qi "unavailable\|transport.*inactive"` means the transport is dead even if `container system status` says running.
3. Recovery from a dead transport (typical after Mac sleep): `container system stop`, wait ~3 seconds, `container system start`. If containers survived the daemon as zombies: `pgrep -f container-runtime-linux`, then kill the orphans.
4. Run `container` commands directly as top-level commands. If the Claude Code Bash sandbox is active with `container *` in `excludedCommands`, the exclusion matches the top-level command string only: `bash some-script.sh` that calls `container` inside runs fully sandboxed and fails on VM operations.

## Service lifecycle

The apiserver does not restart at login unless `brew services start container` is used; on-demand start is the lean default. `container system stop` shuts down the apiserver and VMs.

## Gotchas

| Symptom                                                | Cause and fix                                                                                          |
| ------------------------------------------------------ | ------------------------------------------------------------------------------------------------------ |
| OOM kills, mysterious tool crashes in the VM           | Containers default to 1 GiB memory. Pass `-m 4g`; size is fixed at container creation                   |
| `container build` fails or OOMs                        | Separate builder VM defaults to 2 GiB. `container builder start -m 4g` before building                  |
| Command "succeeded" but did nothing                    | Exit 0 on gRPC transport errors. Grep stderr for `unavailable\|transport.*inactive`                     |
| Everything broken after Mac sleep                      | Stale transport. `container system stop`, sleep 3, `container system start`                            |
| VM running but CLI cannot see it                       | Orphaned after daemon death. `pgrep -f container-runtime-linux`, kill manually                          |
| node_modules slow or flaky on a mounted project        | All mounts are virtio-fs, which dislikes deep symlink trees. `--tmpfs` over the path, or copy-in/git-push-out |
| Need a network-free run                                | No per-run network-off switch exists (1.0.0). Stop the service for offline isolation, or accept the default network |
| Every CLI command hangs forever, zero output           | The client blocks indefinitely on a launchd Mach-service lookup when the apiserver is unregistered or crash-looping. Check `launchctl list \| grep com.apple.container`; recover with the keg-path `container system stop`, then `start`. Last resort: `launchctl bootstrap gui/$UID "$HOME/Library/Application Support/com.apple.container/apiserver/apiserver.plist"` |
| apiserver exits 1: `cannot find any plugins with type network` | Service was started via the linked `/opt/homebrew/bin/container`, deriving an INSTALL_ROOT whose `libexec/` Homebrew never links. Start via `/opt/homebrew/opt/container/bin/container system start` |
| Service dead after `brew upgrade container`            | The launchd plist records the resolved Cellar path of the old keg. Re-run the keg-path `container system start` to rewrite it |
