# 2026-06-17 — gap analysis: what forge-provision should cover next

A parallel web-research pass on where this Mac's provisioning still has holes,
measured against the current stack (Brewfile, scripted `defaults`, chezmoi,
YubiKey signing, the sandbox tiers, Little Snitch). The verdict: the stack is
mainstream-or-better for 2026, and four real gaps stand out. This entry records
the findings and the claims that still need first-hand verification before any
of it becomes a script.

## Findings

1. **No backup story exists (established).** Consensus is Time Machine for
   whole-machine restore plus [Restic][cmp] to B2/S3 for versioned offsite data.
   On macOS, Restic needs an APFS-snapshot wrapper plus launchd and Full Disk
   Access plumbing; Arq 7 does that natively for zero scripting. [asimov][asimov]
   auto-excludes dependency directories from Time Machine via `tmutil`.
   Verification is itself scriptable: weekly `restic check`, monthly
   `--read-data-subset=10%`, quarterly restore drill with a diff.

2. **CLI tools missing from the Brewfile (established).** `ripgrep` is the
   glaring one: fzf integrations and editor pickers assume it. Same tier: `just`,
   `direnv`, `hyperfine`, `watchexec`, `yazi`, `tealdeer`. Second tier: `jless`,
   `xh`, `dust`, `duf`, `bottom`, `lazydocker`. The existing backlog picks (bat,
   eza, git-delta, mise) are confirmed; `mise` can subsume `direnv` if both land.
   Caveat: the deferred-installs backlog claims `rg` already ships "pulled in by
   the rust toolchain" — that is doubtful (ripgrep is a separate crate, not a
   toolchain component), so a `brew "ripgrep"` line is likely still warranted.
   Verify on the actual machine. [modern-unix][munix]

3. **Hardening should move from ad-hoc to baseline (established).** NIST's
   [macos_security][mscp] (mSCP) generates CIS L1/L2 audit and remediation
   scripts, which fits the `scripts/audit/` direction. Scriptable today:
   `sfltool dumpbtm` (background login items), `systemextensionsctl list`,
   `bputil -d` (boot security), disabling sharing daemons. Deliberately
   GUI-gated by Apple, so script only staging and verification: DoH profiles,
   Gatekeeper (`spctl` lost write access in Sequoia), Lockdown Mode. Apple
   Silicon has no firmware password; FileVault gates recoveryOS.

4. **Agent hygiene, two concrete additions (established).** [mcp-scan][mcps]
   detects tool poisoning and rug-pull updates across configured MCP servers
   (caveat: it uploads tool descriptions to Invariant's API). Claude Code's
   native OTel export (`CLAUDE_CODE_ENABLE_TELEMETRY=1`) covers cost and session
   monitoring without adding a langfuse-style layer. Treat an untrusted repo's
   `CLAUDE.md` / `README` as an injection surface: default to plan or read-only
   mode in fresh clones. The community isolates agents via containers, not
   dedicated macOS user accounts, so the existing tier model already matches.

5. **CI for the provisioning scripts is standard and free (established).**
   Running `./provision.sh --dry-run --strict` on `macos-latest` GitHub runners
   per push is common in maintained setups like [mac-dev-playbook][mdp];
   TCC and privileged steps get skipped. Pairs with the existing `--strict`.

6. **Defaults capture tooling exists (established).** [prefsniff][psnf] watches
   a plist and emits the exact `defaults write` command, which answers the
   earlier "what am I comparing against" problem when capturing a new setting.

## Open decision: Restic vs Arq

Benchmarks favor Restic/Kopia; macOS-specific writeups favor Arq for native
APFS snapshot handling. The split is scripted-control versus it-just-works.
This one needs a call before `scripts/configure/backup.sh` can be written.

## Not adopting: nix-darwin

Real enthusiast adoption but still niche, and most setups wrap Homebrew for
casks anyway. Brewfile plus chezmoi stays the pragmatic default.

## Verify before acting

This is research from a single pass with partial information. The load-bearing
claims to confirm first-hand before scripting anything:

- `ripgrep` actually absent from `manifests/Brewfile` (and whether `rg` is on
  the machine by another path), against the contradicting backlog note.
- mSCP actually targets macOS 26 / Tahoe today (check its releases).
- `spctl` losing Gatekeeper write access in Sequoia (Apple primary source, not
  a blog).
- Arq 7's native-APFS-snapshot behavior and Restic's wrapper requirement.
- mcp-scan's current data-upload behavior.

## Next, in rough priority order

1. Backup: make the Restic-vs-Arq call, then `scripts/configure/backup.sh`
   plus `asimov` in the Brewfile.
2. Brewfile: add `ripgrep`, then batch `just` / `direnv` / `hyperfine` /
   `watchexec` / `yazi` / `tealdeer` with the existing bat/eza/delta/mise backlog.
3. `scripts/audit/`: integrate mSCP-generated baseline checks.
4. CI: a workflow running `./provision.sh --dry-run --strict` on `macos-latest`.
5. Agent hygiene: an mcp-scan pass over configured MCP servers; the OTel flag.
6. `prefsniff` for future defaults-capture sessions.

[asimov]: https://github.com/stevegrunwell/asimov "asimov — Time Machine dependency-dir exclusion"
[cmp]: https://onidel.com/blog/restic-vs-borgbackup-vs-kopia-2025 "Restic vs Borg vs Kopia, 2025"
[munix]: https://sumguy.com/modern-unix-toolkit-fzf-ripgrep-fd-bat-eza/ "Modern Unix toolkit"
[mscp]: https://github.com/usnistgov/macos_security "NIST macOS Security Compliance Project"
[mcps]: https://invariantlabs.ai/blog/introducing-mcp-scan "Invariant mcp-scan"
[mdp]: https://github.com/geerlingguy/mac-dev-playbook "geerlingguy/mac-dev-playbook"
[psnf]: https://github.com/zcutlip/prefsniff "prefsniff"
