---
name: powerpoint-to-md
description: Convert a PowerPoint (.pptx) deck into a single, LLM-readable Markdown document that preserves text, speaker notes, tables, chart data, embedded images, and visual/layout intent. Runs a hybrid pipeline (Microsoft MarkItDown for text + LibreOffice for per-slide PNG renders), then the calling agent synthesizes the final Markdown using native vision reasoning. USE FOR "convert this pptx to markdown", "turn my slides into markdown", "extract deck content", "pptx to md", "summarize a PowerPoint", "make slides readable for an LLM", "deck to markdown", ".pptx to .md". DO NOT USE FOR .pdf files, Google Slides (export to pptx first), .key Keynote files, or writing new PowerPoints from scratch.
license: MIT
metadata:
  author: brgrp
  version: "1.0.0"
---

# PowerPoint → Markdown

**When activated, produce a single grounded `deck.md` from a `.pptx`. Do not explain the pipeline to the user — run it.**

Hybrid two-track extraction: Microsoft **MarkItDown** for verbatim text/structure, **python-pptx** for speaker notes / tables / embedded images, **LibreOffice** for per-slide PNG renders. The calling agent (you) reads both tracks and writes `deck.md`. Every slide gets its rendered PNG embedded so the reader can verify any interpretation against the source pixels.

## On activation, run these five steps

1. **Verify deps.** Run the doctor once per session:

   ```bash
   ./powerpoint-to-md/scripts/pptx2md.sh doctor
   ```

   LibreOffice (`soffice`) is a hard dependency and the skill will fail fast if missing. Install instructions are printed by `doctor` and detailed in `references/troubleshooting.md`.

2. **Run the extractor.** This runs both tracks, moves durable artifacts next to the input, prints a JSON manifest to stdout, and leaves an internal `extract.json` in a tmp dir for you to read.

   ```bash
   ./powerpoint-to-md/scripts/pptx2md.sh extract path/to/deck.pptx
   ```

   The manifest tells you exactly which files to read next.

3. **Read `extract.json` and every `slide-*.png`.** Use the file paths from the manifest. `extract.json` is the source of truth for text and numbers. The PNGs are the source of truth for visual intent.

4. **Write `deck.md`** next to the input, following the synthesis rubric in `references/slide-synthesis-prompt.md` and the skeleton in `assets/deck-template.md`. Execution rules are also summarized below — follow them literally.

5. **Clean up.** Run:

   ```bash
   ./powerpoint-to-md/scripts/pptx2md.sh cleanup <tmp_dir_from_manifest>
   ```

   Or use the one-shot `convert` command which does steps 2 + 5 automatically and blocks in between for you to do step 4:

   ```bash
   ./powerpoint-to-md/scripts/pptx2md.sh convert path/to/deck.pptx
   ```

## Output layout — dual-output design

Given input `path/to/deck.pptx`, the skill produces a single wrapping subfolder next to the input, containing **two markdown files** and the assets:

```
path/to/
└── deck/                                ← wrapping folder, named after the input (slugged)
    ├── README.md                        ← usage guidance: which .md to use when
    ├── deck.md                          ← CONDENSED — LLM-first, no image refs, DEFAULT choice
    ├── deck.with-images.md              ← DETAILED — same content + plain-link image refs for audit
    └── deck-assets/
        ├── slides/
        │   ├── slide-01.png             ← full slide render (referenced only from with-images.md)
        │   ├── slide-02.png
        │   └── …
        └── images/
            ├── slide-03-pic1.png        ← embedded images extracted from the pptx
            └── slide-12-pic1.jpg
```

The two markdown files carry **identical semantic content**. The synthesis merges text-track (MarkItDown + python-pptx, verbatim strings) with vision reasoning (per-slide PNG interpretation for diagrams, charts, layouts, colour emphasis) so every fact from both channels lands in prose, tables, or bullets. The only difference between the two files is whether image reference lines are present.

### Which file should downstream consumers read?

| Consumer | Use | Why |
|---|---|---|
| RAG pipelines, embeddings, LLM Q&A, agents | **`deck.md`** | Compact (~8–11 k text tokens on a 33-slide deck), zero image dependencies, self-contained. |
| Any automation that pipes markdown into an LLM | **`deck.md`** | No risk of a vision-enabled reader auto-attaching PNGs and blowing context. |
| Human doing a spot-check / audit | `deck.with-images.md` | Click-through links let you compare the synthesis against the source pixels without opening PowerPoint. |
| Human doing a full read | either | The narrative is identical. |

**Default rule:** if you don't know which to use, use `deck.md`. `README.md` in the same folder repeats this in plain language for anyone opening the folder.

## Rules for writing the two markdown files (do these literally)

The rules split into three groups: content rules (shared), condensed-only rule (deck.md), and detailed-only rule (deck.with-images.md).

### Content rules — apply to BOTH files

1. **Verbatim text policy.** Every string in `extract.json` — bullets, titles, table cells, speaker notes — appears verbatim. Never retype from an image if the text track has it.
2. **Translate every chart, diagram, SmartArt, and org chart into prose + markdown table** by reading the slide PNG. Charts get a `###` subheading with the chart title, a prose description of what the chart shows, and a markdown table if the values are legible.
3. **Never guess numbers.** If a chart value isn't clearly readable from the PNG and isn't in `extract.json`, write `<!-- values unclear from render; see slide render -->`. Do not invent numbers.
4. **Note visual emphasis inline** in prose when it changes meaning — e.g. "The APAC bar is highlighted in red, other bars grey." The prose is where meaning lives; images are only for verification.
5. **Every slide gets one `## Slide N: <title>` heading.** Always. Even blank / divider / section-header slides.
6. **Speaker notes always included** if present, as a blockquote at the end of the slide section:
   ```markdown
   > **Speaker notes:** …
   ```
7. **Linear reading order** — left-to-right, top-to-bottom. Do not reproduce columns or absolute positioning.
8. **Separate slides with `---`** (horizontal rule).
9. **Vision-derived content must be complete enough that a reader who never sees the images can still understand the slide.** This is the design contract that makes `deck.md` (no images) viable as the default.

### Condensed rule — `deck.md` only

10. **No image references at all.** No `![…](…)` and no `[…](…-assets/…)`. If a slide's meaning requires visual detail (a diagram, a color-coded map, a screenshot), that detail lives in prose — you wrote it in rule 2/4.

### Detailed rule — `deck.with-images.md` only

11. **Add plain-link references to slide render + embedded images**, at the end of each slide section and inline for pptx-embedded images. Plain markdown links — **never** `![…](…)` inline-embed syntax:
    ```markdown
    [figure — short vision-derived description](./deck-assets/images/slide-N-picM.png)
    ...
    > **Speaker notes:** …

    [Slide N — source render](./deck-assets/slides/slide-N.png)
    ```
    Rationale: some vision-enabled agents auto-attach files referenced with `![…]` embed syntax as vision inputs; plain-link `[…]` syntax opts out. Worst case the tool ignores the syntax difference; best case we save ~1.6 k vision tokens per PNG. Never worse.

## Deck-level synthesis (write these LAST)

Only after every `## Slide N:` section is done in the detailed variant, go back to the top and write these into BOTH files (identical text):

1. **H1 title** — from core properties → first slide title → filename, in that order.
2. **One-line metadata** — `> Source: deck.pptx • N slides • Converted YYYY-MM-DD`
3. **Executive summary** — 3 to 5 sentences that synthesize the deck's argument. Grounded in the actual slide content you just processed, not the title alone.
4. **Table of contents** — one line per slide, linking to its anchor.

Writing these last guarantees the summary is grounded in every slide.

## Practical write order for the agent

The efficient way to produce both files (rather than write the same content twice):

1. Write `deck.with-images.md` in full (with all image references), following content rules 1–9 + detailed rule 11.
2. Produce `deck.md` by stripping every line matching `^\[Slide .* — source render\]\(` or `^\[figure — .*\]\(\./.*-assets/` from `deck.with-images.md`.
3. Write `README.md` from the fixed template — the orchestrator script writes this for you.

The condensed content in `deck.md` must be self-sufficient — a reader who never opens an image should still understand every slide. If you find yourself wanting to say "see image" in prose, that's a signal to write more vision-derived prose instead.

## CLI reference

| Command | Purpose |
|---|---|
| `pptx2md.sh doctor` | Verify deps. Prints install fixes per OS. Non-zero exit if a hard dep is missing. |
| `pptx2md.sh extract <in.pptx>` | Run both extraction tracks. Copies durable PNGs to `./{deck-name}-assets/`. Prints a JSON manifest to stdout (paths to `extract.json`, slides, images, tmp dir). |
| `pptx2md.sh convert <in.pptx>` | One-shot: extract, wait for the calling agent to write `deck.md`, then cleanup. Prints the manifest and pauses on the tmp dir — the agent reads it inline. |
| `pptx2md.sh cleanup <tmp_dir>` | Delete a tmp dir returned by `extract`. |

Always run from the repo root; the script paths are relative to the skill.

## Reading the manifest

`extract` prints a JSON object to stdout. Parse it directly:

```json
{
  "status": "success",
  "deck_name": "quarterly-review",
  "input": "path/to/deck.pptx",
  "output_root": "path/to/quarterly-review",
  "output_md": "path/to/quarterly-review/quarterly-review.md",
  "output_md_with_images": "path/to/quarterly-review/quarterly-review.with-images.md",
  "readme_md": "path/to/quarterly-review/README.md",
  "assets_dir": "path/to/quarterly-review/quarterly-review-assets",
  "slides_dir": "path/to/quarterly-review/quarterly-review-assets/slides",
  "images_dir": "path/to/quarterly-review/quarterly-review-assets/images",
  "tmp_dir": "/tmp/pptx2md-XXXXXX",
  "extract_json": "/tmp/pptx2md-XXXXXX/extract.json",
  "slide_count": 24
}
```

The `readme_md` file is pre-written by the orchestrator with the correct filenames — the agent does not need to author it. The agent authors `output_md_with_images` first, then derives `output_md` from it per the write-order rules above.

If `status` is `"error"`, read `error` and `solution` and follow the fix — do not proceed to write anything.

## Prerequisites

Install once per machine. `pptx2md.sh doctor` verifies everything.

**macOS (Homebrew):**
```bash
brew install --cask libreoffice
brew install poppler
pip install 'markitdown[pptx]' python-pptx
```

**Ubuntu / Debian:**
```bash
sudo apt install libreoffice poppler-utils
pip install 'markitdown[pptx]' python-pptx
```

**Windows:** see `references/troubleshooting.md`.

## Deep references

- `references/output-schema.md` — internal `extract.json` schema and `deck.md` template rules
- `references/slide-synthesis-prompt.md` — full synthesis rubric with worked examples
- `references/troubleshooting.md` — soffice / rasterizer install per OS, corrupt or password-protected pptx, big-deck memory notes
- `assets/deck-template.md` — the skeleton the agent fills in
