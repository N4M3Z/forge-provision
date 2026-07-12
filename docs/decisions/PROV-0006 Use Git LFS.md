---
title: Use Git LFS
description: Install git-lfs via Homebrew for large-binary tracking in git repos; revisit when Git's native large object promisers feature is broadly deployed by hosting providers
type: adr
category: tooling
tags:
    - git
    - git-lfs
    - large-files
    - homebrew
status: accepted
created: 2026-05-30
updated: 2026-05-30
author: "@N4M3Z"
project: forge-provision
related: []
responsible: ["@N4M3Z"]
accountable: ["@N4M3Z"]
consulted: []
informed: []
upstream: []
---

# Use Git LFS

## Context and Problem Statement

Any repo that tracks media, ML model weights, or other multi-MB binaries balloons git history and slows clones, fetches, and rebases. The standard fix is to keep binaries out of git history and store them out-of-band, with a pointer file checked into the repo. On macOS this is a one-formula install that needs to be declared in `manifests/Brewfile` so a fresh machine matches.

The complication in 2026: Git itself merged a "large object promisers" feature [upstream in 2025][TYLER] that aims to provide the same server-side benefits as LFS without LFS's user-side hooks and quirks. The eventual end-state is no third-party LFS tool at all. But hosting providers (GitHub, GitLab) have not yet broadly deployed the server-side machinery needed for promisers to be useful, so the feature is years away from being the de-facto default.

## Decision Drivers

- Universal hosting support today (GitHub, GitLab, Bitbucket all natively serve LFS)
- One-formula install, single user-global setup step (`git lfs install`)
- Low cognitive cost on collaborators
- Migration path off LFS exists when promisers are broadly deployed

## Considered Options

1. **Git LFS** (`brew "git-lfs"`) — standard, broad server support, mature tooling
2. **Git native large object promisers** — the eventual successor [upstream in Git 2.50][TYLER], but not yet usable on GitHub/GitLab at this scale
3. **git-annex** — more capable but [steeper learning curve and lower adoption][GRIZZLY]
4. **DVC** — purpose-built for ML datasets and pipelines; overkill for general binary tracking
5. **Perforce Helix Core / Unity Version Control** — enterprise pricing, [game-dev focused][ANCHOR]; not relevant for a personal dev Mac
6. **Cloud-storage proxy** (Cloudflare R2, Backblaze B2) — [cheaper than GitHub LFS storage quotas][NICKB] but DIY plumbing per repo

## Decision Outcome

Chosen option: **Git LFS via `brew "git-lfs"` in Brewfile**, with `git lfs install` run once user-globally to wire the smudge/clean hooks for every future repo. Per-repo opt-in stays explicit via `git lfs track "*.psd"` style filters.

Revisit this decision when hosting providers ship server-side support for Git's native large object promisers feature. At that point the upgrade path is `git lfs uninstall` plus removing tracked attributes — disruptive only to active large-file workflows.

### Consequences

- [+] Standard tooling, ubiquitous server support across GitHub, GitLab, Bitbucket
- [+] One Brewfile line, one global setup command, no per-repo configuration on a fresh Mac
- [+] Forward-compatible exit: when promisers land at scale, LFS removal is mechanical
- [-] Subject to GitHub LFS bandwidth and storage quotas on large or popular repos
- [-] Pointer files in working trees confuse some non-LFS-aware tooling (older CI runners, some IDE Git integrations)
- [-] Carries the cost of a hooks-based smudge filter on clone/checkout, noticeable on slow networks

## More Information

- [The future of large files in Git is Git][TYLER] (Cipriani, Aug 2025) — context on why Git's native large object promisers will eventually supersede third-party LFS
- [Git LFS overview][PERFORCE] (Perforce) — protocol mechanics
- [Managing Large Files in Git: LFS and Alternatives][GRIZZLY] (Grizzly Peak Software) — alternatives comparison

[TYLER]: https://tylercipriani.com/blog/2025/08/15/git-lfs/
[PERFORCE]: https://www.perforce.com/blog/vcs/how-git-lfs-works
[GRIZZLY]: https://www.grizzlypeaksoftware.com/library/managing-large-files-in-git-lfs-and-alternatives-59w8igxh
[ANCHOR]: https://www.anchorpoint.app/blog/5-alternatives-to-git-lfs-for-game-development
[NICKB]: https://nickb.dev/blog/backblaze-b2-as-a-cheaper-alternative-to-githubs-git-lfs/
