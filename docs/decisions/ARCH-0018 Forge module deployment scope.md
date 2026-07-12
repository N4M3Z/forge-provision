---
title: Forge module deployment scope
description: General-purpose skills deploy to user scope (`forge install --target ~`); domain-specific content deploys to project scope inside the owning repo. The decision tree turns on whether a future arbitrary AI session benefits from the content.
type: adr
category: tooling
tags:
    - forge
    - deployment
    - claude-code
    - skills
status: accepted
created: 2026-05-30
updated: 2026-05-30
author: "@N4M3Z"
project: forge-provision
related:
    - "ARCH-0004 Use Forge AI.md"
responsible: ["@N4M3Z"]
accountable: ["@N4M3Z"]
consulted: []
informed: []
upstream:
    - https://github.com/N4M3Z/forge-cli
---

# Forge module deployment scope

## Context and Problem Statement

The `forge install` command can deploy a module's skills, agents, and rules to either:

- **User scope**: `~/.claude/`, `~/.codex/`, `~/.gemini/`, `~/.opencode/` (invoked with `forge install --target ~`). The deployed artifacts load into every AI session on the machine regardless of working directory.
- **Project scope**: the same directories under the source repo or a target project (invoked with `forge install` without `--target`, defaulting to the current directory). The artifacts load only when an AI session opens that specific project.

Choosing the wrong scope is costly in both directions. Deploying a domain-specific module (tax law, regulatory content, project-bound conventions) to user scope pollutes every session with irrelevant context and can leak private domain knowledge into unrelated work. Deploying a general-purpose dev module to project scope only makes the skills invisible from every other repo on the machine.

## Decision Drivers

- AI sessions have finite context windows; loading irrelevant skills wastes tokens and risks the wrong skill firing
- Domain content (financial rules, legal text, project-specific conventions) may include privacy-sensitive material that should not load in unrelated sessions
- General-purpose dev tooling (commit conventions, refactoring discipline, language-specific patterns) is useful in every session
- The deployment cost is the same either way — the difference is which sessions see the content
- The decision must be reversible — uninstalling a module from one scope and reinstalling at the other is cheap

## Considered Options

1. **All modules at user scope.** Maximum availability; maximum context pollution. Domain modules leak into unrelated sessions.
2. **All modules at project scope.** Maximum cleanliness; general-purpose modules are unreachable from arbitrary repos. Defeats the point of shared developer discipline.
3. **Manual case-by-case.** No rule; decide per install. Inconsistent over time; new module authors have to relitigate.
4. **Decision tree by content type.** General-purpose dev tooling → user scope. Domain-specific content → project scope inside the owning repo.

## Decision Outcome

Chosen option: **decision tree by content type — option 4**.

### Rule

Ask: *"Would an arbitrary AI session at any working directory benefit from this module's skills?"*

- **Yes** → user scope. Deploy with `forge install --source <module-path> --target ~`.
- **No** → project scope. Deploy with `forge install --source <module-path> --target <module-path>` so the artifacts land inside the module's own repo and only load when an AI session opens it.

### Applied examples

#### User scope

| Module | Representative skills | Why user scope |
| ------ | --------------------- | -------------- |
| `forge-dev` | BashConventions, VersionControl, MarkdownConventions, BuildSkill, FixIssue, GitHubCLI, SystematicDebug, RustDevelopment, FixCI, FixTests, TestDrivenDevelopment, ReceiveReview, RequestReview | Developer discipline applies in every repo: committing changes, debugging failures, reviewing PRs, writing tests |
| `forge-core` | BuildModule, BuildAgent, BuildHook, BuildPlugin, ArchitectureDecision, Brainstorming, DesignSpec, WritePlan, ExecutePlan | Meta-tooling for building the forge ecosystem itself, used from any module repo or scratch directory |
| `forge-steering` | BehavioralSteering, GuardRails, LearnFrom | Behavioral norms apply universally to AI sessions on this machine |
| `forge-cli` | (forge CLI's own skills, if any) | The tool's documentation belongs wherever the tool is used |
| `forge-provision` | DotfilesStrategy, Chezmoi, HomebrewToolkit, SshToolkit, GhosttyToolkit, TmuxToolkit, DmgInstall | Provisioning knowledge applies whenever the user touches infra on this Mac, not only inside the provisioning repo |

#### Project scope

| Module | Representative skills | Why project scope |
| ------ | --------------------- | ----------------- |
| `forge-finance` | TaxFiling, PaymentQr, SecuritiesTax, HealthFiling, SocialFiling, TaxAnalysis, TaxReturn, Fakturoid, Revolut, en-CZ DPFO rules | Czech personal income tax content is irrelevant in every non-finance session; loading it in unrelated repos wastes context and risks misfiring |
| `forge-gm` | Scene-prep skills, multi-phase review, art/music scouting, lore integrity | Game-master content is only useful inside RPG content repos |
| `forge-proton` | Proton Mail / Calendar integration | Only applies when working inside Proton-related repos |
| `forge-microsoft` | Microsoft 365 integration | Same as above; only relevant in M365-touching projects |

### Worked scenarios

**Scenario A: "Refactor the Rust CLI inside `forge-cli`."**
forge-dev is at user scope so RustDevelopment, FixTests, and BuildModule fire automatically. forge-core is at user scope so BuildPlugin is reachable for any plugin work. forge-finance does NOT load because it is at project scope and the working directory is not forge-finance.

**Scenario B: "Calculate this year's tax return inside `forge-finance`."**
The session opens at `~/Developer/N4M3Z/forge-finance/`, so `.claude/skills/` inside that repo loads alongside the user-scope skills. TaxReturn, TaxFiling, SecuritiesTax, en-CZ rules are all available. forge-dev's general skills (BashConventions, VersionControl, FixIssue) are also available from user scope.

**Scenario C: "Edit a markdown spec inside a personal scratch directory."**
Only user-scope modules load. forge-dev's MarkdownConventions, ArchitectureDecision (if creating an ADR), BuildSkill (if writing a skill) all available. No domain modules load — the session is not in any domain repo.

### Edge cases

- **Cross-domain general skills inside a domain module.** When a domain module exposes a generally useful skill (a tax module's currency-formatting skill, a game-master module's scene-writing skill), the right move is to migrate that skill to a general-purpose module (`forge-core` or a new `forge-i18n`) rather than promote the whole domain module to user scope. The decision tree applies per-module, not per-skill.
- **Personal vs work split.** When the user wants the same module available in personal and work contexts but not at user scope (privacy), deploy at project scope to each target repo individually. The repetition is cheap.
- **Re-scope on second thought.** Moving a module from project to user scope (or back) is `forge install` with the new `--target` plus removing the old deployment directory. No data loss.
- **Borderline: a domain skill that the user reaches for daily.** If a skill from a project-scope module ends up needed everywhere (e.g., the user lives in tax work and wants currency formatting in every editor session), promote the skill to a general-purpose module rather than promoting the whole domain module to user scope. Keep the privacy/relevance boundary at the module level.

### Consequences

- [+] AI sessions only load the skills they need; context budget is preserved
- [+] Domain content stays contained to the repos where it is relevant
- [+] The decision tree is one yes/no question; future modules apply it without debate
- [+] Reversible — the decision can be revisited per module as use patterns shift
- [-] Domain modules require opening their repo to reach their skills, which adds a step when the user wants to invoke them from an unrelated CWD
- [-] The user must maintain `forge install --target ~` and per-project `forge install` invocations as separate steps in the provisioning flow
- [-] Edge cases (cross-domain general skills inside a domain module) require judgment per skill, not just per module

## More Information

- [ARCH-0004 Use Forge AI][4] — the decision to adopt forge as the assembly + deployment tool
- [`forge install` documentation][CLI] — flag reference

[4]: ARCH-0004%20Use%20Forge%20AI.md
[CLI]: https://github.com/N4M3Z/forge-cli
