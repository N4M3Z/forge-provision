# markdown-oxide

An [LSP][LSP] server that treats a folder of markdown as a language: notes are files, `[[wikilinks]]` are references, headings are definitions. It gives Obsidian-style navigation (completion, backlinks, diagnostics) to any LSP editor. In this setup it drives the PKM features in Zed against the Atlas vault and forge's own markdown.

## How it runs

It is a standalone Rust binary, not a Zed feature. The "Markdown Oxide" extension bundles the binary and tells Zed to attach it to markdown buffers. On opening a workspace, oxide indexes every markdown file into an in-memory graph (files, headings, blocks, tags, footnotes), watches for edits, and answers LSP requests. Because it is editor-agnostic (Neovim, VS Code, Helix, Zed all drive the same binary), some features depend on what the editor's LSP client wired up. The intelligence lives in the server; the editor only renders the replies.

## Config

oxide reads its own file, not Zed's `settings.json`: `~/.config/moxide/settings.toml` (global) or `.moxide.toml` (per vault). It also imports the daily-note folder, date format, and new-file location from a vault's `.obsidian`, which is why the managed config stays lean. Source of truth is [`manifests/moxide/settings.toml`](../../manifests/moxide/settings.toml) (chezmoi-owned live, seeded by `scripts/configure/markdown-oxide.sh`). The full key reference and the boundary rationale are in [PROV-0018][ADR].

The one non-default we set is `excluded_folders` (Archives, Assets, Templater, Templates, .trash), so vault chrome stays out of completions and backlinks.

## Using it in Zed

| Feature | How to trigger | Notes |
| --- | --- | --- |
| Wikilink / heading completion | type `[[`, then `[[Note#` for headings | also `[](` markdown-link style |
| Tag completion | type `#` | callouts, footnotes, aliases complete too |
| Go to note | go-to-definition on a `[[link]]` (`gd` in vim) | the one feature to confirm works in Zed |
| Backlinks | find-all-references on a note or heading | sorted by modified date |
| Vault-wide jump | Zed project-symbol search | fuzzy over every file, heading, tag |
| Outline | Zed outline panel | file headings as document symbols |
| Embed preview | type `![[Note]]` | renders as an inlay hint in the buffer |
| Capture-first | type `[[Unwritten Note]]`, run code actions | creates the file (or appends a heading) |
| Daily note | type `[[today`, `[[tomorrow`, `[[next tuesday` | natural-language relative dates |
| Hover | hover a note or link | preview text plus backlinks together |

## Gated in Zed

- **Rename** (file / heading / tag with reference rewrite) is implemented in oxide but not wired in Zed's client; renaming a linked note orphans its `[[links]]`. A `forge` CLI command is the planned fix.
- **Block-level completion** (`[[Note#^block]]`) is not supported in Zed yet.
- The `:Today` / `:Daily next tuesday` workspace commands are documented for Neovim; in Zed the daily-note **completions** are the reliable path (whether Zed surfaces oxide's `executeCommand` entries is unconfirmed).

## Links

- [PROV-0018 Zed markdown and PKM capability boundary][ADR]
- [Zed markdown/PKM capability matrix](zed.md)
- [oxide features index](https://oxide.md) and [configuration](https://oxide.md)

[LSP]: https://microsoft.github.io/language-server-protocol/ "Language Server Protocol"
[ADR]: ../decisions/PROV-0018%20Zed%20markdown%20and%20PKM%20capability%20boundary.md "PROV-0018 Zed markdown and PKM capability boundary"
