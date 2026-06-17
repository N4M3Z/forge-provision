---
title: Workload isolation tier model
description: Isolation on provisioned developer machines is layered by workload rather than delegated to one tool, on every platform. The ordering principle is that isolation strength runs process sandbox < container < VM, and each workload class (GUI apps, AI agents, coding harnesses, throwaway experiments) is placed at the weakest tier that still contains its threat. The model is platform-neutral; each platform realizes the tiers with its own primitives (Seatbelt / bubblewrap / WSL2, Apple container / Kata / Hyper-V, Parallels / KVM / Windows Sandbox), and per-platform tool choices live in their own ADRs.
type: adr
category: security
tags:
    - sandbox
    - isolation
    - threat-model
    - tiers
    - cross-platform
status: accepted
created: 2026-06-04
updated: 2026-06-04
author: "@N4M3Z"
project: forge-provision
related:
    - "VIRT-0001 Coding harness Seatbelt sandbox.md"
    - "VIRT-0002 Linux workload isolation Apple container.md"
    - "ARCH-0016 Virtualization stack.md"
    - "ARCH-0001 Module scope cross-platform provisioning.md"
responsible: ["@N4M3Z"]
accountable: ["@N4M3Z"]
consulted: []
informed: []
upstream: []
---

# Workload isolation tier model

## Context and Problem Statement

Several classes of code run on every machine this repo provisions: GUI apps, AI agents, coding harnesses, and throwaway experiments. They differ in how hostile the code may be and how far it can be trusted, so the question "is Docker the right sandbox?" is malformed; any single tool answers one tier and cannot answer the others. This ADR records the platform-neutral workload-to-tier mapping so that per-platform tool choices ([VIRT-0001][V1], [VIRT-0002][V2], [ARCH-0016][16] for macOS; Linux and Windows equivalents when those machines are provisioned) rest on a deliberate threat model rather than on whichever tool was reached for first.

Two facts shape the model on every OS. First, isolation strength is a strict ladder: a process sandbox shares the host kernel, a container shares a kernel through namespaces, and only a VM interposes a hypervisor; the hypervisor is the only boundary trusted against genuinely hostile code. Confidence: **established** [KATA]. Second, what a "container" buys differs by platform: on macOS and Windows, Linux containers always run inside a VM (the Virtualization framework or WSL2/Hyper-V), so the container tier inherits a hardware boundary for free; on Linux, plain containers share the host kernel directly and provide no such boundary unless a sandboxed runtime (Kata, Firecracker, gVisor) adds one. Confidence: **established** [VMM][KATA].

## Decision Drivers

- Place each workload at the weakest tier that still contains its realistic threat; no VM tax where a process fence suffices, no process-fence trust where the code is hostile.
- The model must hold across macOS, Linux, and Windows ([ARCH-0001][1]); only the realization may vary.
- Untrusted native GUI apps require a VM of their own OS; no container can hold them.
- Throwaway experiments need clean teardown with no host residue.
- Tools must be scriptable and reproducible, since provisioning is written down.

## Considered Options

### One tool for everything

Pick a single sandbox (a process sandbox alone, Docker alone, or VMs for everything) and force all workloads through it. Rejected: process sandboxes are too weak for hostile code and cannot fence native GUI apps; containers cannot hold native GUI apps either, and on Linux they do not even add a kernel boundary; VMs everywhere taxes the harness with daily friction it does not need.

### Tiered mapping (chosen)

Assign each workload class to a purpose-matched tier; each platform realizes the tier with its native primitive, recorded in its own ADR.

## Decision Outcome

Chosen: **the tiered mapping**, with per-platform realizations.

| Workload                     | Tier                  | macOS                          | Linux                              | Windows                       |
| ---------------------------- | --------------------- | ------------------------------ | ---------------------------------- | ----------------------------- |
| Coding harness               | Process sandbox       | Seatbelt ([VIRT-0001][V1])     | bubblewrap + Landlock/seccomp      | WSL2 + bubblewrap             |
| AI agents, Linux experiments | VM-backed container   | Apple container ([VIRT-0002][V2]) | Kata / Firecracker / gVisor runtime | Docker via WSL2 (VM-backed)   |
| Untrusted native GUI apps    | Full VM               | Parallels ([ARCH-0016][16])    | KVM/QEMU (libvirt)                 | Hyper-V / Windows Sandbox     |

Platform notes that the realization must respect:

- **macOS**: every container runtime is VM-backed, but only Apple container gives one VM per container; Docker-API runtimes share a kernel inside one VM.
- **Linux**: the container tier is only adequate for hostile code when a sandboxed runtime (Kata, Firecracker, gVisor) interposes a VM or kernel proxy; plain runc containers share the host kernel and sit at the process-sandbox trust level.
- **Windows**: WSL2 is itself a Hyper-V VM, so Linux workloads inherit a hardware boundary; Windows Sandbox is the native disposable-VM primitive for throwaway native-app runs. The coding-harness sandbox does not run on native Windows and requires WSL2.

OrbStack and similar Docker-API runtimes exist alongside these as convenience layers, not isolation tiers; their bounded role is recorded per platform (for macOS in [VIRT-0002][V2]).

### Consequences

- [+] Each workload sits at a defensible tier on every platform: no boundary weaker than its threat, none heavier than its friction budget.
- [+] The mapping generalizes: a new workload is placed by asking "how hostile is the code, and which kernel does it need", not by tool preference.
- [+] Platform differences become explicit realization notes instead of silent assumptions (the Linux plain-container trap in particular).
- [-] The stack is several tools per platform rather than one, which is more surface to install and maintain. This is the accepted cost of matching tier to threat.
- [-] Linux and Windows realizations are recorded here as defaults but have no implementing ADRs yet; they harden when those machines are provisioned.

## More Information

- [VIRT-0001 Coding harness Seatbelt sandbox][V1] — macOS harness tier
- [VIRT-0002 Linux workload isolation Apple container][V2] — macOS container tier
- [ARCH-0016 Virtualization stack][16] — macOS VM tier
- [ARCH-0001 Module scope cross-platform provisioning][1] — why the model must span platforms
- [Claude Code sandboxing][SANDBOX] — harness-tier primitives per platform
- [Kata vs Firecracker vs gVisor][KATA] — Linux VM-backed container runtimes

[1]: ARCH-0001%20Module%20scope%20cross-platform%20provisioning.md
[16]: ARCH-0016%20Virtualization%20stack.md
[V1]: VIRT-0001%20Coding%20harness%20Seatbelt%20sandbox.md
[V2]: VIRT-0002%20Linux%20workload%20isolation%20Apple%20container.md
[SANDBOX]: https://code.claude.com/docs/en/sandboxing
[VMM]: https://docs.docker.com/desktop/features/vmm/
[KATA]: https://northflank.com/blog/kata-containers-vs-firecracker-vs-gvisor
