---
name: SandboxToolkit
version: 0.1.0
description: "Run workloads in per-VM container sandboxes: throwaway experiments, the full Claude Code harness behind a VM wall (interactive or persistent), and autonomous runs where --dangerously-skip-permissions is safe because the VM replaces the permission system. Covers the templated agent image, token handoff, and runtime operations. USE WHEN run experiment, sandbox this code, run untrusted code, disposable container, autonomous agent run, claude in container, agent sandbox, apple container, container run, container build, or debugging Apple container service failures."
sources:
    - https://github.com/apple/container
    - https://apple.github.io/container/documentation/
    - https://code.claude.com/docs/en/sandbox-environments
    - https://code.claude.com/docs/en/authentication
---

# SandboxToolkit

Run untrusted, autonomous, or simply contained workloads in VM-backed containers. Each run gets a fresh VM, mounts exactly one host directory, inherits no host environment, and is destroyed on exit: the blast radius is the mounted directory plus whatever the container can reach over the network.

## Runtime

| Platform | Runtime                                  | Operations reference                          |
| -------- | ---------------------------------------- | --------------------------------------------- |
| macOS    | Apple container (one lightweight VM per container, no Docker engine) | `AppleContainer.md` — preflight, service lifecycle, gotchas |

Before any run, follow the preflight in the operations reference. The invocations below use the macOS runtime's CLI.

## Experiments

Disposable shell or command in a fresh VM, one directory mounted, destroyed on exit:

```sh
container run --rm -it -m 4g -v "$PWD/experiment:/work" -w /work \
    docker.io/library/debian:stable-slim bash
```

Hardened variant for untrusted code (read-only rootfs, scratch tmpfs):

```sh
container run --rm -m 4g --read-only --tmpfs /tmp -v "$PWD/experiment:/work" -w /work \
    docker.io/library/debian:stable-slim sh -c '<command>'
```

Mount exactly one directory, created for the purpose. Never mount the home directory, a credentials directory, or a repo containing secrets.

The `-v` source is whatever the host path resolves to, so prefer an explicit absolute path. Bare `$PWD` mounts wherever you are standing: run it from the home directory and the box gets your entire home at `/work`, the whole-home leak this skill warns against (and a writable one under `--dangerously-skip-permissions`).

## Claude Code in the box

The entire harness runs behind the VM wall as a security layer: interactive sessions, persistent settings and history, and autonomous `--dangerously-skip-permissions` runs. Image template, build, auth, and run modes are in `ClaudeBox.md`.

## Constraints

- Never run `--dangerously-skip-permissions` on the host. The host tier is the OS-level harness sandbox; skip-permissions belongs only inside a container or VM.
- Mount exactly one host directory per run. The mount, the token, and any named volume are the entire blast radius; keep them minimal.
- The token never appears in argv, Containerfiles, or any tracked file. Bare-key `-e` inheritance only.
- The container has network access by default: a compromised run can exfiltrate the mounted directory and the token. Do not mount anything whose disclosure would hurt.
- Wrap nothing in shell scripts. Invocations stay documented here and run as top-level commands (see the preflight in the operations reference).
