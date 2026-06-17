---
title: Discord desktop app threat model
description: The official Discord desktop app is treated as untrusted on developer machines for two defensible reasons: native capabilities a browser sandbox eliminates (process enumeration, native modules, code-fetching auto-update) and Discord's own US-jurisdiction data handling (law-enforcement disclosure, retention, the 2025 vendor ID breach). Tencent's minority stake is a secondary, indirect caution, not a direct legal-compulsion threat, and the posture does not rest on it.
type: adr
category: security
tags:
    - discord
    - tencent
    - threat-model
    - telemetry
    - electron
    - data-handling
status: accepted
created: 2026-06-03
updated: 2026-06-03
author: "@N4M3Z"
project: forge-provision
related:
    - "PROV-0011 Discord official app with Little Snitch.md"
    - "ARCH-0027 TLP minimal confidentiality controls.md"
responsible: ["@N4M3Z"]
accountable: ["@N4M3Z"]
consulted: []
informed: []
upstream:
    - https://luna.gitlab.io/discord-unofficial-docs/docs/science/
    - https://medium.com/discord-engineering/all-your-game-are-detection-fd06b1683137
    - https://discord.com/safety/360044157931-working-with-law-enforcement
    - https://discord.com/press-releases/update-on-security-incident-involving-third-party-customer-service
    - https://citizenlab.ca/2020/05/we-chat-they-watch/
---

# Discord desktop app threat model

## Context and Problem Statement

Discord is needed on the developer machine, but the official desktop client should not be the way it runs. This ADR records *why* the official app is treated as untrusted, so that [PROV-0011][11] (the containment decision) rests on a threat model that survives hostile review rather than on folklore.

The common justification, "Tencent owns Discord, so the Chinese government reads your messages", is largely myth and must not anchor the decision. The public record shows Tencent is a **minority, passive investor** (Discord's 2015 Series B and 2018 Series D), with no confirmed board seat and no disclosed mechanism by which an equity stake grants access to user data or infrastructure [DISCO-WIKI]. Discord Inc. is a **Delaware corporation headquartered in San Francisco** [DISCO-CO], so operational and legal control sit with Discord's own board under US law. China's data-compulsion statutes (National Intelligence Law Art. 7, Cybersecurity Law, Data Security Law, PIPL) bind PRC-jurisdiction entities; they reach Tencent, not a US company in which Tencent holds a minority position [NIL][DAUM]. An ADR that claimed otherwise would collapse under scrutiny.

The defensible threat model has nothing to do with the cap table. It rests on what the binary *does* and on what Discord *retains and discloses*.

## Decision Drivers

- The reasoning must be empirically grounded and survive adversarial review; no claim that a minority investor confers data access or legal compulsion over a US company.
- The distinction that matters is capability, not telemetry: telemetry must not be the headline, because it is identical across clients.
- The durable risk is data custody (what Discord keeps and to whom it discloses), which persists regardless of client.
- The posture should generalize to other proprietary clients with the same shape (closed binary, native modules, self-updater).

## Considered Options

### Framing A: Tencent ownership as the primary threat

Lead with the equity stake and Chinese law. Rejected: factually weak. Tencent's stake is minority and passive, Discord is US-domiciled, and PRC statutes do not flow through a minority shareholder to a US company [DISCO-WIKI][DISCO-CO][DAUM]. This framing is rumor-grade and would not withstand review.

### Framing B: Telemetry reduction as the primary threat

Lead with "the desktop app spies more than the web client". Rejected: false. Both clients POST to the `/api/science` endpoint (aliased `/api/track` to evade blockers) and send `X-Super-Properties` and `X-Fingerprint` on every request [LUNA]. Sandboxing or swapping clients does not reduce Discord's telemetry. Only stripping the calls (an open/patched client) or network-blocking does.

### Framing C: Capability containment + data custody as the threat (chosen)

Lead with the native capabilities a browser sandbox structurally prevents, plus Discord's own retention and disclosure behavior. Both are verifiable and client-relevant.

## Decision Outcome

Chosen: **Framing C**. The official Discord desktop app is untrusted on developer machines on two grounds, with Tencent recorded only as a secondary, indirect caution.

### Ground 1: Native capability (what a browser sandbox eliminates)

- **Process enumeration.** The desktop client scans the running-process list and matches executables against a games database for Rich Presence; users report detection continuing with the toggle off. Discord's privacy policy corroborates collecting "the game you are playing" [GAME][PRIVACY]. A browser tab cannot read the process list.
- **Native modules.** The client ships native modules (`discord_voice`, overlay hook) under its per-version modules directory [MODULES].
- **Code-fetching auto-update.** The updater downloads module archives keyed to the host version, unpacks, and launches them. A self-updating binary that fetches and executes opaque modules is the highest-leverage supply-chain surface, and it does not exist in a browser [MODULES].
- **Native crash reporting.** As an Electron app it can capture native minidumps from main and renderer processes (Sentry attribution likely but not confirmed by teardown).

Confidence: process enumeration, native modules, and code-fetching auto-update are **established**; the specific Sentry/crash-reporting attribution is **uncertain**.

### Ground 2: Discord's own data custody (client-independent, but the durable risk)

- **Law-enforcement disclosure.** Under the Stored Communications Act, Discord discloses subscriber info on subpoena, stored content (≤180 days) on warrant, and makes emergency disclosures on good-faith belief of imminent harm [LE].
- **Retention.** Identifiers (email, phone) are retained roughly 180 days after deletion; backups persist weeks; preserved content can outlive deletion [LE].
- **Breach exposure.** The September to October 2025 third-party support breach exposed names, emails, IP addresses, billing metadata, support-ticket content, and roughly 70,000 users' government-ID photos through a compromised customer-service vendor (5CA / Zendesk) [BREACH]. Collecting government IDs for age verification turned a chat service into a custodian of identity documents, and the weakest vendor governed the blast radius.

Confidence: **established**.

### Secondary, indirect caution: Tencent

Tencent's *own* conduct is a legitimate reason for caution about data that reaches Tencent: Citizen Lab documented WeChat surveilling even non-China-registered accounts to train censorship, and WeChat lacks end-to-end encryption [CITIZENLAB]. This justifies wariness of Tencent products and of data flows to Tencent. It is recorded here as context, not as a mechanism of control over Discord. Confidence: Tencent's WeChat conduct **established**; any operative effect on Discord **uncertain**.

### Consequences

- [+] The posture is defensible: every load-bearing claim is sourced and survives the adversarial-review standard the repo requires.
- [+] It correctly redirects the decision from "less telemetry" (false) to "less native capability and less data handed over" (true), which changes what a good mitigation looks like.
- [+] It generalizes: any closed client with native modules and a self-updater inherits the same Ground 1 reasoning.
- [-] It concedes that switching clients does not reduce Discord-side telemetry or data custody; only minimizing what is shared (never submitting government ID, assuming content is subpoenable) addresses Ground 2.
- [-] It deliberately downgrades the Tencent argument the user started from, which is less viscerally satisfying than "Tencent reads your DMs" but is the honest position.

## More Information

- [PROV-0011 Discord official app with Little Snitch][11] — the containment decision this threat model justifies
- [ARCH-0027 TLP minimal confidentiality controls][27] — the confidentiality posture that frames data-custody risk
- [Discord game detection (Discord Engineering)][GAME]
- [Discord module/auto-update mechanism][MODULES]
- [Discord law-enforcement guidelines][LE]
- [Discord 2025 third-party support breach][BREACH]
- [Citizen Lab: We Chat, They Watch][CITIZENLAB]

[11]: PROV-0011%20Discord%20official%20app%20with%20Little%20Snitch.md
[27]: ARCH-0027%20TLP%20minimal%20confidentiality%20controls.md
[DISCO-WIKI]: https://en.wikipedia.org/wiki/Discord
[DISCO-CO]: https://discord.com/company-information
[NIL]: https://www.chinalawtranslate.com/en/national-intelligence-law-of-the-p-r-c-2017/
[DAUM]: https://www.chinalawtranslate.com/en/what-the-national-intelligence-law-says-and-why-it-doesnt-matter/
[LUNA]: https://luna.gitlab.io/discord-unofficial-docs/docs/science/
[GAME]: https://medium.com/discord-engineering/all-your-game-are-detection-fd06b1683137
[PRIVACY]: https://discord.com/privacy
[MODULES]: https://github.com/itsvic-dev/discord-module-downloader
[LE]: https://discord.com/safety/360044157931-working-with-law-enforcement
[BREACH]: https://discord.com/press-releases/update-on-security-incident-involving-third-party-customer-service
[CITIZENLAB]: https://citizenlab.ca/2020/05/we-chat-they-watch/
