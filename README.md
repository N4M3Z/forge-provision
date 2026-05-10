# forge-provision

Mac provisioning scripts and agentic scaffold. Companion to [forge-core][forge-core].

## Description

Idempotent shell that brings a fresh macOS install to a working baseline, plus the agentic layer (`CLAUDE.md`) that lets an agent (Claude Code, Codex, Gemini) compose and run the scripts.

Inspired by:

- [drduh/macOS-Security-and-Privacy-Guide][drduh] — policy reference
- [N4M3Z/check-mac][check-mac] — verification layer (script conventions inherited)
- [N4M3Z/forge-core][forge-core] — deployment system for skills, agents, rules

## Compatibility

- macOS 14+ (Apple Silicon recommended)
- bash 3.2+ (system shell), zsh
- git, curl

## Installation

```sh
git clone https://github.com/N4M3Z/forge-provision.git
cd forge-provision
./provision.sh --help
```

## Usage

```sh
./provision.sh                 # interactive — prompts before each topic
./provision.sh --dry-run       # show what would run, mutate nothing
./provision.sh --topic claude  # run only one topic
./provision.sh --strict        # exit non-zero on any non-OK (CI gate)
```

## Coverage

Filled in as scripts land. See `scripts/<topic>/` for the current set.

## Requirements

| Tool  | Version |
|-------|---------|
| macOS | 14+     |
| bash  | 3.2+    |
| git   | 2.40+   |

## License

[EUPL-1.2](LICENSE)

[forge-core]: https://github.com/N4M3Z/forge-core
[check-mac]: https://github.com/N4M3Z/check-mac
[drduh]: https://github.com/drduh/macOS-Security-and-Privacy-Guide
