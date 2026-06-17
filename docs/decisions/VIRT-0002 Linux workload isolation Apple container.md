---
title: Linux workload isolation Apple container
description: Apple container is the primary runtime for the VM-backed container tier of ARCH-0031 on macOS, running disposable experiments, the full Claude Code harness as a security layer, and autonomous agents in one lightweight VM per container with no Docker engine. OrbStack is installed alongside it as a bounded Docker-API convenience layer (Compose, Kubernetes on demand), explicitly not an isolation tier. Docker Desktop and Colima are rejected. Invocations are documented in the SandboxToolkit skill; image definitions live in scripts/sandbox/ as build-arg-templated Containerfiles.
type: adr
category: security
tags:
    - sandbox
    - isolation
    - apple-container
    - orbstack
    - docker
    - agents
    - experiments
status: accepted
created: 2026-06-04
updated: 2026-06-11
author: "@N4M3Z"
project: forge-provision
related:
    - "ARCH-0031 Workload isolation tier model.md"
    - "VIRT-0001 Coding harness Seatbelt sandbox.md"
    - "ARCH-0016 Virtualization stack.md"
    - "ARCH-0014 Brewfile vs manual DMG criteria.md"
responsible: ["@N4M3Z"]
accountable: ["@N4M3Z"]
consulted: []
informed: []
upstream:
    - https://github.com/apple/container
    - https://orbstack.dev/
---

# Linux workload isolation Apple container

## Context and Problem Statement

AI agents and throwaway experiments need a Linux environment behind a boundary that holds against hostile code, with clean teardown. This is the VM-backed container tier of [ARCH-0031][31]. On macOS every container runtime is VM-backed, but the runtimes differ in where the boundary sits: Docker Desktop, Colima, and OrbStack run all containers in one shared-kernel Linux VM, while Apple container runs each container in its own lightweight VM via the Virtualization framework. Confidence: **established** [CONTAINER][VMM]. A further constraint applies: the stack should avoid depending on the Docker engine.

## Decision Drivers

- The boundary must hold against untrusted code: per-container VM beats a shared kernel inside one VM.
- Avoid the Docker engine: no Docker Desktop licensing, no `docker` CLI dependency for the primary path.
- Open source and auditable, since the tool is trusted as a security boundary.
- Disposable runs must leave no host residue and leak no host state into the guest.
- Docker-ecosystem compatibility (Compose, the Docker socket, Kubernetes) must remain reachable when needed.

## Considered Options

### Docker Desktop

The ecosystem default. Rejected: commercial licensing, the heaviest footprint, a shared-kernel container model, and exactly the Docker dependency the stack avoids.

### Colima

Free and open source, but it drives containers through the `docker` CLI against a shared-kernel VM: it avoids Docker Desktop, not Docker, and adds no boundary the other options lack. Rejected: satisfies neither the Docker-free driver nor the stronger-boundary driver.

### OrbStack

The best developer experience and performance of the Docker-API runtimes, but closed source, paid for commercial use, and the same shared-kernel model; it bundles the Docker engine rather than avoiding it. Rejected as the isolation tier; retained in a bounded convenience role (below).

### Apple container (chosen)

One lightweight VM per container, own CLI, no Docker engine, Apache-2.0, native on macOS 26 + Apple Silicon, which this host meets.

## Decision Outcome

Chosen: **Apple container as the primary runtime, OrbStack as a bounded convenience layer.**

- **Apple container** is installed via Homebrew (in scope for the Brewfile per [ARCH-0014][14]); install and the non-interactive service bootstrap (`container system start --enable-kernel-install`) live in `scripts/install/container.sh`. Disposable experiments, the full Claude Code harness behind the VM wall, and autonomous runs are driven by the [SandboxToolkit skill][SKILL]: a per-run VM mounting a single host directory at `/work`, removed on exit. Apple container passes no host environment variables unless asked, so the blast radius of a run is the mounted directory. Verified on this host end-to-end. Image definitions live in `scripts/sandbox/` as build-arg-templated Containerfiles; invocations stay in the skill rather than wrapper scripts, by deliberate preference for definitions plus skills over shell automation.
- **OrbStack** exists only for the Docker-API surface Apple container's pre-1.0 CLI does not cover: Compose, tooling that speaks the Docker socket, and Kubernetes on demand. Docker is enabled; Kubernetes and Linux machines stay off until a concrete need. It is recorded explicitly as a convenience, not a containment choice, and the two engines coexist without integration.

### Consequences

- [+] The strongest container boundary available on macOS: hostile code must escape its own VM, not just a namespace.
- [+] Docker-free primary path: no engine, no Desktop license, an auditable Apache-2.0 boundary.
- [+] Clean teardown by construction: the per-run VM is removed on exit and inherits no host environment.
- [-] Apple container (1.0.0) ships no Compose equivalent. OrbStack is kept precisely to cover that gap, which means two container engines on the machine.
- [-] Apple container (1.0.0) has no per-run network-off switch; containers join the default network, so offline experiments rely on stopping the service rather than a run flag.
- [-] OrbStack's presence is a standing temptation to default to the convenient shared-kernel tier; this ADR bounds its role so reaching for it for untrusted code is a recorded deviation.

## More Information

- [ARCH-0031 Workload isolation tier model][31] — the tier this decision realizes
- [ARCH-0016 Virtualization stack][16] — the full-VM tier above this one
- [ARCH-0014 Brewfile vs manual DMG criteria][14] — why both land via Homebrew
- [Apple container][CONTAINER] and the [Containerization framework][CONTAINERIZATION]
- [Docker Desktop VM architecture on macOS][VMM]

[SKILL]: ../../skills/SandboxToolkit/SKILL.md
[14]: ARCH-0014%20Brewfile%20vs%20manual%20DMG%20criteria.md
[16]: ARCH-0016%20Virtualization%20stack.md
[31]: ARCH-0031%20Workload%20isolation%20tier%20model.md
[CONTAINER]: https://github.com/apple/container
[CONTAINERIZATION]: https://github.com/apple/containerization
[VMM]: https://docs.docker.com/desktop/features/vmm/
