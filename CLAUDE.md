# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a repository of ISO C++ Committee (WG21) papers authored or co-authored by Mateusz Pusz.
Papers are written in Markdown-like source formats and processed into HTML/PDF output documents.

Two processing frameworks are used depending on the file extension:

- **`.md` files** — processed by [mpark/wg21](https://github.com/mpark/wg21) (a Pandoc-based framework), stored in `wg21/` as a git submodule
- **`.bs` files** — processed by [Bikeshed](https://github.com/tabatkins/bikeshed)

Generated HTML output lives in `docs/papers/` (symlinked from `src/generated/`) and is published to GitHub Pages.

## Building Papers

All build commands are run from the `src/` directory:

```shell
cd src

# Build a specific paper as HTML (mpark/wg21 framework)
make 3045R8_quantities_and_units_library.html

# Build a specific paper as PDF
make 3045R8_quantities_and_units_library.pdf

# Build a Bikeshed paper
bikeshed spec 0919R3_heterogeneous_lookup_for_unordered_containers.bs generated/0919R3_heterogeneous_lookup_for_unordered_containers.html

# Watch a Bikeshed paper for live reloading during editing
bikeshed watch src/paper_to_generate.bs

# Update bibliography and annex-f cache (run periodically)
cd wg21 && make update
```

The first build will automatically download Pandoc and set up a Python virtualenv under `wg21/deps/`.

## Paper Format

### mpark/wg21 Markdown papers (`.md`)

Papers begin with a YAML metadata block:

```yaml
---
title: "Paper Title"
document: P3045R8
date: today
audience:
  - LEWG Library Evolution Working Group
author:
  - name: Author Name
    email: <email@example.com>
toc-depth: 4
---
```

Key formatting conventions within the Markdown:

- **Paragraph numbers**: `[2]{.pnum}`, `[2.1]{.pnum}`
- **Diff additions**: `[new text]{.add}` (inline) or `::: add` ... `:::` (block)
- **Diff removals**: `[old text]{.rm}` (inline) or `::: rm` ... `:::` (block)
- **Notes**: `[text]{.note}` (inline) or `::: note` ... `:::` (block)
- **Examples**: `[text]{.example}` (inline) or `::: example` ... `:::` (block)
- **Editorial notes**: `[text]{.ednote}` or `::: ednote` ... `:::`
- **Stable name references**: `[stable.name]{.sref}` (links to C++ standard sections)
- **Citations**: `[@P3045R7]` — auto-resolved from wg21.link index
- **Comparison tables**: `::: cmptable` ... `:::` with `### Before`/`### After` headers
- **C++ exposition names**: use `$name$` as shorthand for `@_name_@` (renders italic)
- **Code with embedded Markdown**: surround with `@` inside `` ```cpp `` blocks for formatting

### Bikeshed papers (`.bs`)

Begin with a `<pre class='metadata'>` block instead of YAML frontmatter.

## Markdownlint

The repository uses markdownlint for `.md` files. Configuration:

- Root: `.markdownlint.json` — max line length 90, max 2 blank lines
- `src/.markdownlint.json` — extends root; line length 100 (code blocks: 118), 4-space list indent

VS Code markdownlint extension is supported and recommended.

## Conventional Commits

Commit scopes defined in `.vscode/settings.json`:
- `h&d` — heterogeneous lookup / precalculated hash papers
- `safety` — safety paper (P2981)
- `qty-num` — quantity as numeric type (P2982)
- `qty-lib` — quantities and units library (P3045)
- `qty-model` — mathematical model for quantities and units library (P4185)
- `fixed-str` — basic_fixed_string (P3094)
