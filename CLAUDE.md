# forge-provision — Claude Code context

## What this is

Best-practice provisioning for developer machines — macOS, Linux, and Windows — plus the agentic scaffold (skills, ADRs, rules, TLDRs, journals) that lets an agent (Claude Code, Codex, Gemini) read, compose, and run the scripts. See [ARCH-0001](docs/decisions/ARCH-0001%20Module%20scope%20cross-platform%20provisioning.md) for the module scope.

Scripts come first. Everything else exists to make scripts easier to read, compose, and reason about.

## Critical caveat

These scripts MUTATE the host. Always:
- Confirm with the user before running anything outside `--dry-run`
- Prefer idempotent operations — re-running a script must converge, never break
- Source `scripts/lib/env.sh` for `DEV_DIR`, `OLD_CLAUDE_DIR`, `GITHUB_USER`, etc.
- Source `scripts/lib/helpers.sh` for `run()`, status helpers, and dry-run gating

## Configuration

All path/identity values live in `.env` (gitignored) or fall back to `.env.example` (committed defaults). Scripts source `scripts/lib/env.sh` once at the top; that file resolves the repo root and auto-exports every variable from `.env`.

To override a default on this machine: `cp .env.example .env` and edit.

## Architecture

```
forge-provision/
├── provision.sh              # orchestrator — mirrors check-mac/check.sh
├── scripts/
│   ├── lib/                  # shared helpers (copied from check-mac/lib)
│   ├── install/              # install software — claude-code, brew, chezmoi, pass-cli, …
│   ├── clone/                # clone reference repos
│   ├── migrate/              # migrate state from old Mac (chat history, dotfiles)
│   ├── configure/            # macOS defaults, security hardening, shell init
│   └── verify/               # post-conditions (lean on check-mac later)
├── journal/                  # chronological narrative of what was done and why
├── docs/decisions/           # ADRs (madr format, prefix-numbered)
├── book/                     # long-form knowledge (later — mdBook)
├── skills/                   # forge-deployable provision-* skills (later)
└── manifests/                # Brewfile, defaults.yaml, agents.toml (later)
```

## Commands

- `./provision.sh --dry-run`            preview without mutating
- `./provision.sh --topic <name>`       run one topic (subdir of scripts/)
- `./provision.sh --strict`             exit non-zero on any non-OK (CI gate)
- `./provision.sh --help`               usage

## Adding a script

1. Pick a **verb dir** under `scripts/` (`install/`, `clone/`, `migrate/`, `configure/`, `verify/`, …). Create one if needed.
2. Name the file after the **target** (the noun): `install/brew.sh`, `clone/references.sh`, `migrate/claude-history.sh`. No numbered prefixes; flat-in-verb mirrors check-mac's flat-in-topic.
3. Source `scripts/lib/env.sh` at the top (pulls in `DEV_DIR`, `OLD_CLAUDE_DIR`, etc.).
4. Source `scripts/lib/helpers.sh` for status / dry-run / run helpers.
5. Make it idempotent. Re-running converges, never breaks.
6. Support `--dry-run`. Default exit is 0; `--strict` flips that.
7. `chmod +x` it.
8. Add a journal entry referencing the new script.

## Conventions inherited from check-mac

- No `set -euo pipefail` — severity codes preferred over exit-on-error.
- Default severity `$UNKNOWN`, flip to `$OK` only on positive evidence.
- `[[ ]]` for tests, pattern matching over subprocesses (`[[ "$s" == *enabled* ]]`).
- Multi-line command substitution for readability.
- Guard external CLI probes with `command -v` and `xcode-select -p` so probes do not trigger GUI installers.
- Probe new CLIs first, fall back to legacy `defaults`.

## Conventions inherited from forge-core

- Skills live under `skills/<PascalCase>/SKILL.md` with frontmatter (`name`, `version`, `description` containing `USE WHEN <triggers>`).
- Agents live under `agents/<PascalCase>.md` with frontmatter (`name`, `description`, `model`, `tools`).
- Rules live under `rules/<PascalCase>.md`. One file, one behavior.
- Manifest at repo root (`.manifest` YAML) lists tracked artifacts with SHA256 fingerprints + provenance pointers.
- `module.yaml` at root for module identity (`name`, `version`, `description`, `repository`, `events`).

## Repo norms

- License: **EUPL-1.2** (matches forge-core / check-mac).
- Default branch: `main`.
- Conventional Commits, lowercase, no scope, no trailing period. Types: `feat`, `fix`, `docs`, `chore`, `refactor`, `test`.
- ADRs in `docs/decisions/<PREFIX>-NNNN <Title>.md` (madr-structured). Prefixes: `ARCH`, `PROV`, `CORE`.

## Working principle

*Every command we run during setup gets written down* — as a script in `scripts/<verb>/<target>.sh` (if reusable) and/or as a journal entry in `journal/` (for narrative). Git history is the index of when each landed.
