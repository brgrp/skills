---
name: powerpoint-to-md
description: Convert a PowerPoint (.pptx) deck into LLM-readable Markdown that preserves text, speaker notes, tables, chart data, embedded images, and visual intent. Runs a hybrid pipeline (Microsoft MarkItDown + python-pptx for text, LibreOffice for per-slide PNG renders), then the calling agent synthesizes the final Markdown using native vision reasoning. USE FOR "convert this pptx to markdown", "turn my slides into markdown", "extract deck content", "pptx to md", "summarize a PowerPoint", "make slides readable for an LLM", "deck to markdown", ".pptx to .md". DO NOT USE FOR .pdf files, Google Slides (export to pptx first), .key Keynote files, or writing new PowerPoints from scratch.
license: MIT
metadata:
  author: brgrp
  version: "1.1.0"
---

# PowerPoint → Markdown

**When activated, produce a grounded `deck.md` from a `.pptx`. Do not explain the pipeline to the user — run it.**

Hybrid two-track extraction: **MarkItDown** + **python-pptx** for text, tables, chart series, speaker notes, and embedded images; **LibreOffice** for per-slide PNG renders. Python deps are pinned in `pyproject.toml` + `uv.lock` and installed on demand by `uv sync` — no system `pip install`. You (the agent) read both tracks and write two markdown files.

## On activation, run these four steps

1. **Verify deps.**

   ```bash
   ./powerpoint-to-md/scripts/pptx2md.sh doctor
   ```

   Hard deps: `uv`, `jq`, LibreOffice (`soffice`), a PDF rasterizer (`pdftoppm` preferred, ImageMagick fallback, `pdf2image` in the uv venv as last resort). Doctor auto-syncs the uv venv.

2. **Extract.**

   ```bash
   ./powerpoint-to-md/scripts/pptx2md.sh extract path/to/deck.pptx
   ```

   Prints a JSON manifest to stdout. Assets land in `path/to/<slug>/`. `extract.json` and the tmp workspace stay in `tmp_dir` until you clean up.

3. **Write the two markdown files** at `output_md_with_images` and `output_md`, following `references/slide-synthesis-prompt.md` and the skeleton in `assets/deck-template.md`. `extract.json` is the source of truth for text/numbers; slide PNGs are the source of truth for visual intent.

4. **Clean up.**

   ```bash
   ./powerpoint-to-md/scripts/pptx2md.sh cleanup <tmp_dir_from_manifest>
   ```

## Output layout

For input `path/to/deck.pptx` you produce:

```
path/to/
└── deck/                                ← wrapping folder, slugged from input name
    ├── deck.md                          ← CONDENSED — no image refs, default for LLMs
    ├── deck.with-images.md              ← DETAILED — same content + plain-link image refs
    └── deck-assets/
        ├── slides/
        │   ├── slide-01.png             ← full slide renders (300 DPI)
        │   └── …
        └── images/
            ├── slide-03-pic1.png        ← embedded images from the pptx
            └── slide-12-pic1.jpg
```

Both markdown files carry **identical semantic content**. Text-track fields land verbatim; every diagram, chart, and visual emphasis you spot in the PNG lands as prose so the condensed file is self-sufficient. Only difference: `.with-images.md` carries `[Slide N — source render](…)` and `[figure — …](…)` plain-link references at the end of each slide section; `.md` omits them.

| Consumer | Use | Why |
|---|---|---|
| RAG, embeddings, LLM Q&A, agents | **`deck.md`** | Compact, no image dependencies, safe to pipe as text anywhere. |
| Human audit / spot-check | `deck.with-images.md` | Click-through links to compare synthesis against source pixels. |

## Rules for writing the two files (do these literally)

Content rules apply to **both** files.

1. **Verbatim text policy.** Every string in `extract.json` — bullets, titles, table cells, speaker notes — appears verbatim. Never retype from an image if the text track has it.
2. **Translate every chart, diagram, SmartArt, and org chart into prose + a markdown table** by reading the slide PNG. Charts get a `###` subheading with the chart title, prose describing what the chart shows, and a table if the values are legible.
3. **Never guess numbers.** If a chart value isn't in `extract.json` and isn't clearly readable, write `<!-- values unclear from render; see slide render -->`. Do not invent numbers.
4. **Note visual emphasis inline** in prose when it changes meaning — e.g. "The APAC bar is highlighted in red, other bars grey."
5. **Every slide gets one `## Slide N: <title>` heading.** Always. Even blank / divider slides.
6. **Speaker notes** if present, as a blockquote at the end of the slide section:
   ```markdown
   > **Speaker notes:** …
   ```
7. **Linear reading order** — left-to-right, top-to-bottom. No columns, no absolute positioning.
8. **Separate slides with `---`** (horizontal rule).
9. **Vision-derived content must be complete enough that a reader who never sees the images still understands each slide.** This is what makes `deck.md` viable as the default.

Condensed rule — `deck.md` only:

10. **No image references at all.** No `![…](…)` and no `[…](…-assets/…)`. Visual detail lives in prose (rule 2/4).

Detailed rule — `deck.with-images.md` only:

11. **Add plain-link references** to slide renders and pptx-embedded images. Plain markdown links — **never** `![…](…)` inline-embed syntax:
    ```markdown
    [figure — short vision-derived description](./deck-assets/images/slide-N-picM.png)
    ...
    > **Speaker notes:** …

    [Slide N — source render](./deck-assets/slides/slide-N.png)
    ```
    Rationale: some vision-enabled agents auto-attach files referenced with `![…]` embed syntax; plain-link `[…]` syntax opts out and saves ~1.6 k vision tokens per PNG.

## Deck-level top matter (write LAST, into both files identically)

After every `## Slide N:` section is complete, go back to the top and add:

1. **H1 title** — from `deck.title` if non-empty, else first slide title, else humanized filename.
2. **Metadata line** — `> Source: deck.pptx • N slides • Converted YYYY-MM-DD`
3. **Executive summary** — 3–5 sentences synthesizing the deck's argument. Grounded in the per-slide content, not the title alone.
4. **Contents** — numbered list, one line per slide, linking to each `## Slide N:` anchor.

## Practical write order

Write `deck.with-images.md` first in full. Derive `deck.md` by stripping every line matching `^\[Slide .* — source render\]\(` or `^\[figure — .*\]\(\./.*-assets/`.

## CLI reference

| Command | Purpose |
|---|---|
| `pptx2md.sh doctor` | Verify deps + sync uv venv. Non-zero exit on missing deps. |
| `pptx2md.sh extract <in.pptx>` | Extract text + render slides. Prints JSON manifest to stdout. |
| `pptx2md.sh cleanup <tmp_dir>` | Delete a tmp dir from the manifest. |

## Reading the manifest

`extract` prints a JSON object to stdout:

```json
{
  "status": "success",
  "deck_name": "quarterly-review",
  "input": "path/to/deck.pptx",
  "output_root": "path/to/quarterly-review",
  "output_md": "path/to/quarterly-review/quarterly-review.md",
  "output_md_with_images": "path/to/quarterly-review/quarterly-review.with-images.md",
  "assets_dir": "path/to/quarterly-review/quarterly-review-assets",
  "slides_dir": "path/to/quarterly-review/quarterly-review-assets/slides",
  "images_dir": "path/to/quarterly-review/quarterly-review-assets/images",
  "tmp_dir": "/tmp/pptx2md-XXXXXX",
  "extract_json": "/tmp/pptx2md-XXXXXX/extract.json",
  "slide_count": 24
}
```

If `status` is `"error"`, read `error` and `solution` and follow the fix — do not proceed to write anything.

## Prerequisites

`pptx2md.sh doctor` verifies everything and auto-syncs the Python venv on first run.

**macOS (Homebrew):**
```bash
brew install uv jq
brew install --cask libreoffice
brew install poppler
```

**Ubuntu / Debian:**
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
sudo apt install jq libreoffice poppler-utils
```

**Windows:** see `references/troubleshooting.md`.

`uv` reads `powerpoint-to-md/pyproject.toml` + `uv.lock` and creates an isolated `.venv/` on first `doctor` or `extract` run — no `pip install`, no interference with system Python.

## Deep references

- `references/output-schema.md` — `extract.json` schema and markdown template rules
- `references/slide-synthesis-prompt.md` — full synthesis rubric with a worked example
- `references/troubleshooting.md` — install fixes per OS, corrupt/password-protected pptx, big-deck notes
- `assets/deck-template.md` — the skeleton you fill in
