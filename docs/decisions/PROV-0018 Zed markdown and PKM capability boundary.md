---
title: Zed markdown and PKM capability boundary
description: Zed with the markdown-oxide LSP owns markdown source editing and PKM intelligence (wikilink completion, backlinks, broken-link diagnostics, embed inlay hints) plus image files as tabs and a read-only side preview; Obsidian remains the rendered-edit, inline-image, PDF, and math surface on the same vault. Inline images, PDF viewing, and in-buffer WYSIWYG are GPUI core limits the Zed extension API cannot reach, so no custom extension or fork is built for them.
type: adr
category: tooling
tags:
    - zed
    - markdown-oxide
    - obsidian
    - pkm
    - markdown
    - editor
status: accepted
created: 2026-06-12
updated: 2026-06-12
author: "@N4M3Z"
project: forge-provision
related:
    - "PROV-0016 Document rendering toolchain.md"
    - "PROV-0007 Brewfile manifest.md"
responsible: ["@N4M3Z"]
accountable: ["@N4M3Z"]
consulted: []
informed: []
upstream: []
---

# Zed markdown and PKM capability boundary

## Context and Problem Statement

Markdown is the canonical authoring format across this setup: ADRs, journals, skills, and a large Obsidian vault are all markdown. Zed earns its place as the editor for code, and with the markdown-oxide language server it gains Obsidian-style knowledge features: wikilink completion, backlinks, broken-link diagnostics, and `![[embed]]` transclusion shown as inlay hints. The temptation is to push Zed all the way to an Obsidian replacement: inline images in the buffer, PDF viewing, and a rendered-edit (Live Preview / Typora) mode where syntax markers hide and you type into styled text.

Those three asks sit on the far side of a hard line. Inline-in-buffer image rendering, PDF rendering, and in-place rendered editing all require the editor to interleave rendered widgets with editable text in the GPUI layout pass, a core-engine capability. The decision is where to draw the boundary between what Zed owns and what stays in Obsidian, and whether the gap is worth closing with a custom extension or a fork.

## Decision Drivers

- Keep markdown editing in the same editor as code, with vim mode and LSP intelligence, rather than fragmenting the workflow.
- Obsidian is already provisioned and is a purpose-built rich-text surface; the vault is one shared directory.
- No bespoke editor engineering: do not build what the extension surface cannot support, and do not carry a fork.
- The same content must not be duplicated across tools.

## Considered Options

1. **Zed plus markdown-oxide for editing, Obsidian for rendered and visual work.** Each tool does what it is architecturally suited to, on the same vault.
2. **Build a custom Zed extension to add inline images, PDF, and WYSIWYG.** Zed extensions are WebAssembly in a sandbox with no GPUI access, no custom views, panels, decorations, or webviews; the supported types are languages, themes, snippets, debuggers, MCP and agent servers, and slash commands. The issues that would unlock custom views and decoration APIs are closed, and the visual-extension-API RFC is an open discussion the maintainers describe as not near-term and explicitly without webviews.
3. **Patch or fork Zed core in Rust** to add the three features directly. Technically possible, but an unbounded maintenance burden for a provisioning repo, with no upstream merge guarantee.
4. **Drop Zed for markdown and use only Obsidian.** Discards oxide's LSP intelligence, vim mode, and a single editor for code and prose.

## Decision Outcome

Chosen option: **option 1**, the capability split.

Zed plus markdown-oxide owns markdown source editing and PKM intelligence (wikilink and heading completion, backlinks via find-all-references, broken-link diagnostics, `![[embed]]` inlay hints), opening image files as their own rendered tabs, and a read-only side preview pane for a rendered glance while editing. Because oxide also runs in non-vault repositories, the same wikilink completion and backlinks extend to forge's own ADRs, journals, and skills, not only the vault.

Obsidian owns the rendered-edit lane: Live Preview, inline image and PDF embeds, math, canvas, and graph. Both tools operate on the same vault directory with no content duplication.

Options 2 and 3 are rejected for the same root reason: inline images, PDF viewing, and in-buffer rendered editing are GPUI core capabilities, and the extension API cannot reach them. A custom extension is not merely unbuilt but architecturally impossible on the current surface, and a fork trades a small papercut for permanent maintenance. Option 4 is rejected because it sacrifices the editing intelligence that motivated adopting oxide in the first place. The PDF render path (markdown to PDF for sharing) is a separate concern owned by [PROV-0016 Document rendering toolchain](PROV-0016%20Document%20rendering%20toolchain.md); this record covers in-editor viewing, not conversion.

### Consequences

- [+] Each tool does what it is architecturally good at; no effort sunk into a doomed extension or a fork.
- [+] oxide's wikilink, backlink, and diagnostic intelligence covers forge markdown repositories as well as the vault.
- [+] Image files still open inside Zed as tabs, so most image inspection needs no context switch.
- [-] Inline images, PDF viewing, and rendered-edit are unavailable in Zed; reaching for them means switching to Obsidian.
- [-] A local image referenced from a note opens in the external browser from Zed's preview rather than rendering in place, a known papercut of the preview pane.
- [-] The boundary is pinned to an upstream limitation. If Zed ships a visual extension API or native PDF and image-in-buffer support, this record should be revisited and the split renegotiated.

## Links

- [markdown-oxide](https://oxide.md) — the PKM language server providing the Zed-side intelligence
- [Zed extension capabilities](https://zed.dev/docs/extensions/capabilities) — the WebAssembly surface that excludes custom views and decorations
- [Visual Extension API RFC](https://github.com/zed-industries/zed/discussions/53403) — the upstream discussion that would change this boundary if it lands
