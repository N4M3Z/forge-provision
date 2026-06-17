---
title: tldr client
description: The tldr-pages client providing the `tldr` command is tlrc, the project's official Rust client, chosen over the community client tealdeer and the original Node.js client for being official, spec-tracking, and a fast native binary. All three share the `tldr` binary, so only one installs.
type: adr
category: tooling
tags:
    - tldr
    - tlrc
    - tealdeer
    - cli
    - documentation
status: accepted
created: 2026-06-13
updated: 2026-06-13
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

Man pages are exhaustive but slow to answer the common question "what are the three flags I actually use for this command." The tldr-pages project provides community-curated, example-first cheatsheets that answer it directly, and the value lives in a client that fetches and renders those pages at the terminal. A client has to be installed to get the `tldr` command.

The constraint is that the obvious candidates all install a binary named `tldr` and therefore conflict in Homebrew, so exactly one can be present. The tldr-pages project maintains three official clients (Rust, Python, Node.js), and a popular community client, tealdeer, also exists. The choice is which single one to provision.

## Considered Options

1. **tlrc** — the tldr-pages project's official Rust client. Tracks the page spec directly, actively maintained, fast native binary.
2. **tealdeer** — a community Rust client, older and more widely installed, the one general "modern Unix" roundups tend to recommend. Not official.
3. **Node.js tldr** — the original official client. Heavier, requires a Node runtime, and has fallen behind in updates per the tldr-pages project.

## Decision Outcome

Chosen option: **tlrc**, because it is the official tldr-pages client and tracks the page specification first, so spec changes land in it before community clients. It is a fast native Rust binary, which fits the rest of the Rust-native CLI stack (ripgrep, fd, bat, and the like). tealdeer is functionally equivalent for daily use and has a larger user base, but it is unofficial; the Node.js client is heavier and lagging. Since the three install the same `tldr` binary and cannot coexist, the official, actively maintained, native option is the clean pick.

### Consequences

- [+] Official client receives spec changes first
- [+] Native Rust binary consistent with the rest of the CLI tooling
- [-] Smaller user base than tealdeer, though the two are functionally equivalent for everyday lookups
- [-] The page cache is populated on first lookup (or via `tldr --update`); a first run with no cache needs network access

## Links

- [tlrc](https://github.com/tldr-pages/tlrc) — the official tldr-pages Rust client
- [tldr-pages](https://github.com/tldr-pages/tldr) — the community cheatsheet collection the client renders
