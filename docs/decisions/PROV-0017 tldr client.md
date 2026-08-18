---
title: tldr client
description: Tealdeer provides the tldr command because forge-provision requires native custom pages and patch pages for local tool connections.
type: adr
category: tooling
tags:
    - tldr
    - tealdeer
    - cli
    - documentation
status: accepted
created: 2026-06-13
updated: 2026-08-14
author: "@N4M3Z"
project: forge-provision
related:
    - "PROV-0007 Brewfile manifest.md"
responsible: ["@N4M3Z"]
accountable: ["@N4M3Z"]
consulted: []
informed: []
upstream: []
---

# tldr client

## Context and Problem Statement

The `tldr` command shows short, example-first command help. Forge-provision also
needs pages for personal commands and local tool connections.

The initial decision selected tlrc. Tlrc is the official Rust client, but it
has no supported custom-page directory. Its cache workaround omits custom pages
from normal listing and completion.

Tealdeer supports a configured custom-page directory. It can replace an
upstream page or append local examples to it.

All clients install a binary named `tldr`, so only one client can be installed.

## Decision Drivers

- Custom pages must use normal `tldr <command>` lookup.
- Local examples must extend useful upstream pages without copying them.
- The client must show its active page and configuration paths.
- Forge-provision must validate pages without network access.
- The client must remain a fast native binary.

## Considered Options

1. **Tealdeer** provides custom pages, patch pages, and `--show-paths`.
2. **Tlrc** is official, but custom pages depend on an undocumented cache workaround.
3. **Node.js tldr** is official, but it requires a heavier runtime.

## Decision Outcome

Chosen option: **tealdeer**.

Forge-provision stores strict pages in `docs/tldr-pages/`. Tealdeer reads that
directory through `custom_pages_dir`.

A `<command>.page.md` file replaces an upstream page. A
`<command>.patch.md` file appends local examples to an upstream page.

Long-form guides remain separate because their structure does not satisfy the
tldr page specification.

### Consequences

- [+] Personal commands use the normal `tldr` interface.
- [+] Patch pages add local examples without copying upstream content.
- [+] `tldr --show-paths` explains which directories tealdeer uses.
- [+] Custom pages participate in normal listing and completion.
- [-] Tealdeer is a community client, not the official tldr-pages client.
- [-] Existing tlrc installations must be replaced because both clients install `tldr`.

## Links

- [Tealdeer](https://github.com/tealdeer-rs/tealdeer)
- [Custom pages and patches](https://tealdeer-rs.github.io/tealdeer/usage_custom_pages.html)
- [Custom page directory](https://tealdeer-rs.github.io/tealdeer/config_directories.html)
- [tldr-pages](https://github.com/tldr-pages/tldr)
