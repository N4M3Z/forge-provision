---
title: In-sandbox PII redaction
description: claude-box gains an in-VM redaction proxy (forge-redact, mitmproxy plus Presidio). The de-anonymization vault is decrypted on the host and synced into the ephemeral VM as a seed, so surrogates stay consistent across runs and reverse cleanly; the in-VM seed is protected by Claude Code's native sandbox (egress allowlist plus denyRead).
type: adr
category: security
tags:
    - pii
    - redaction
    - presidio
    - sandbox
    - apple-container
    - vault
status: accepted
created: 2026-06-17
updated: 2026-06-17
author: "@N4M3Z"
project: forge-provision
related:
    - "VIRT-0002 Linux workload isolation Apple container.md"
    - "VIRT-0001 Coding harness Seatbelt sandbox.md"
responsible: ["@N4M3Z"]
accountable: ["@N4M3Z"]
consulted: []
informed: []
upstream:
    - https://github.com/N4M3Z/forge-redact
---

# In-sandbox PII redaction

## Context and Problem Statement

The harness ships typed prompts and tool-result file contents to the inference API,
and the operator handles customer PII. The leak is not hypothetical: a profile read
into context, a credential pasted into a prompt, an address in a file the agent
opened all leave the machine on the next request. The first attempt provisioned
Presidio system-wide with a `pii_scan.py` scanner the operator would run by hand; it
was abandoned because a scanner you must remember to run does nothing about a leak
that is already on the wire. The control has to sit on the request path.

forge-redact is that control: a reverse proxy (mitmproxy plus Microsoft Presidio)
that screens every outbound request, hard-blocking secrets with a 403 and replacing
free-form PII with consistent surrogates backed by a token-to-value map. The
questions are how to run it inside the [claude-box](<VIRT-0002 Linux workload isolation Apple container.md>)
VM, how to keep that map consistent and reversible across runs without putting the
operator's private key in an ephemeral VM, and how to protect the map while it is
there.

## Decision Drivers

- The proxy must not become a global single point of failure for the operator's
  ordinary host sessions.
- Surrogates must stay consistent across runs and reverse cleanly, so the operator
  can un-blind results.
- The YubiKey-backed private key cannot enter the VM.
- The de-anonymization map holds real PII; while it is in the VM the agent must not
  be able to read it or send it off-box.

## Considered Options

1. **Network-enforced egress allowlist (squid or gateway on an isolated network).**
   Apple container gives one network per container and no CAP_NET_ADMIN, so a gateway
   straddling internal and external is impossible and an in-box firewall cannot run.
   Rejected as infeasible on this runtime; egress is instead bounded one layer up, by
   Claude Code's own sandbox.
2. **Capture-only vault.** Write the map out encrypted per run, never read one back.
   Simple and keeps no decryptable map in the VM, but loses cross-run consistency and
   the continuous reverse map the operator wants. Not chosen.
3. **Host-synced vault with the native sandbox as the boundary.** Sync the map in and
   out of the VM, and rely on Claude Code's managed sandbox to bound the agent.
   Chosen.

## Decision Outcome

Chosen option: **the proxy runs in the box, the vault is synced host-to-VM, and
Claude Code's native sandbox is the agent's boundary.**

Redaction is part of the sandbox. The box's Claude routes through `forge-redact` on
`127.0.0.1:8788`; the host's own Claude stays direct and unaffected, so the proxy is
never a global single point of failure. The entrypoint `redact-entry` **fails
closed**: it waits for the proxy CA and listening port, then sends a request carrying
a planted secret and requires a 403 before it will start Claude.

The vault is synced without the private key leaving the YubiKey. `redact run`
decrypts the master vault on the host (one YubiKey touch) into a plaintext seed
mounted read-only at `/seed`. forge-redact loads that seed (its `vault_seed_path`
option), so known values keep their surrogates across runs, and writes the updated
map to `/capture`, encrypted to the operator's **public** key (touchless). The
captured map is a superset of the master and already encrypted to the operator's key,
so `redact run` promotes it to the master with a move. The box itself never decrypts.

While it is in the VM the plaintext seed is protected by Claude Code's managed
sandbox, baked to `/etc/claude-code/managed-settings.json`: `denyRead` lists `/seed`
and `/capture`, so the agent cannot open the map; `network.allowManagedDomainsOnly`
plus an `allowedDomains` allowlist bounds where the agent can connect at all;
`enableWeakerNestedSandbox` makes it enforce inside the VM and `failIfUnavailable`
makes it fail closed. forge-redact runs as the entrypoint's proxy, outside the agent's
sandbox, so it still reads `/seed` while the agent cannot.

### Consequences

- The sandboxed harness cannot leak PII or secrets to the API (the proxy blocks and
  redacts before egress), and the agent can neither read the in-VM map (`denyRead`)
  nor reach off-allowlist hosts (the managed sandbox).
- Surrogates are consistent across runs and the operator keeps one reversible master
  vault, with the private key never entering the VM; one YubiKey touch per run.
- The protection of the in-VM seed depends on Claude Code's sandbox scoping the
  agent's subprocesses but not the entrypoint proxy; confirm on first run.
- The image carries a large Presidio plus spaCy layer; build the builder VM at
  `-m 4g`. The box is disposable mode only: a named volume at `/home/node` would
  shadow the baked policy, sandbox settings, public key, and proxy CA.
