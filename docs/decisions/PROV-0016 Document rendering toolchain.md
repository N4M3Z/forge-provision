---
title: Document rendering toolchain
description: Markdown renders to PDF via pandoc as converter and typst as the PDF engine, with poppler for PDF inspection. typst is chosen over the LaTeX engines (xelatex, pdflatex, lualatex) for being a single small binary with fast compilation and strong Unicode and box-drawing support.
type: adr
category: tooling
tags:
    - pandoc
    - typst
    - poppler
    - pdf
    - markdown
    - document-rendering
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

# Document rendering toolchain

## Context and Problem Statement

Markdown is the canonical authoring format across this setup: ADRs, journals, skills, and notes are all markdown. Sharing that content outside the terminal needs a rendering path, chiefly to PDF for a polished read or print, and occasionally to Office formats for recipients who expect DOCX. The content frequently contains ASCII-art diagrams and code listings, so the renderer must handle box-drawing glyphs and monospace Unicode without mangling them.

Three pieces are needed: a converter that reads markdown and writes the target format, a PDF engine that the converter drives, and utilities to inspect the rendered PDF (page count, metadata, text extraction). The converter choice is effectively settled — pandoc is the de-facto standard with unmatched format breadth. The real decision is which PDF engine to pair it with, because that choice determines install footprint, render speed, and Unicode fidelity.

## Decision Drivers

- Strong Unicode and box-drawing support for ASCII-art diagrams and code listings
- Small install footprint, not a multi-gigabyte TeX distribution
- Fast renders for the edit-render-read loop
- Format breadth from the converter (PDF, DOCX, EPUB, HTML, reST) for free
- PDF inspection without a separate heavyweight dependency

## Considered Options

1. **pandoc + typst + poppler** — pandoc converts, typst is the `--pdf-engine`, poppler (pdfinfo, pdftotext, pdftoppm) inspects. typst is a single ~30 MB Rust binary.
2. **pandoc + a LaTeX engine (xelatex / lualatex)** — the traditional pandoc PDF path. Requires MacTeX or BasicTeX (multi-gigabyte), slower compilation; xelatex and lualatex handle Unicode well but are heavy.
3. **pandoc + pdflatex** — the lightest LaTeX option, but the weakest Unicode support, which breaks box-drawing and many code-listing glyphs.
4. **HTML-route renderers (wkhtmltopdf / weasyprint)** — render markdown to HTML then to PDF. Good CSS control, but adds a browser-engine or Python stack and is a poor fit for document-style typesetting.

## Decision Outcome

Chosen option: **pandoc + typst + poppler**. pandoc is the converter for its format breadth; nothing else reads and writes as many formats. typst is the PDF engine because it answers every driver at once: it is a single small binary instead of a multi-gigabyte TeX distribution, it compiles fast, and its Unicode and box-drawing support is strong enough that ASCII-art diagrams and code listings render cleanly. Its scripting model is an ordinary language rather than TeX macros, which makes custom templates approachable. poppler supplies the inspection utilities (page count, text extraction, rasterization) as the de-facto open-source PDF toolkit, with no heavier alternative warranted.

### Consequences

- [+] Single small typst binary instead of a multi-gigabyte TeX install
- [+] Fast renders and reliable Unicode for diagrams and code
- [+] pandoc's format breadth (DOCX, EPUB, HTML, reST) available at no extra cost
- [-] typst is younger than LaTeX; LaTeX-only templates and exotic academic layouts are unsupported. When a specific document needs one, pandoc can fall back to xelatex via `--pdf-engine` if a TeX engine is installed for that case
- [-] pandoc-to-typst interop is newer than pandoc-to-LaTeX; some pandoc features assume a LaTeX backend and may need adjustment

## Links

- [pandoc](https://pandoc.org/) — universal document converter
- [typst](https://typst.app/) — Rust-native typesetting system used as the PDF engine
- [poppler](https://poppler.freedesktop.org/) — PDF utility suite
