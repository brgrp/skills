# Output schema and markdown template rules

This file specifies:
1. The shape of the intermediate `extract.json` file the agent reads.
2. The exact structure the agent must write into the two markdown files.

The agent (any vision-capable LLM) reads `extract.json` for verbatim text/numbers and the PNG renders for visual intent, then produces the markdown following the rules in `slide-synthesis-prompt.md`.

---

## `extract.json` schema

Written by `scripts/extract_text.py` into the tmp dir. Deleted after synthesis unless the agent skipped cleanup.

```jsonc
{
  "deck": {
    "source":       "path/to/deck.pptx",
    "title":        "core-properties dc:title, or empty",
    "author":       "core-properties dc:creator, or empty",
    "slide_count":  24,
    "generated_at": "2026-07-27T10:30:00+00:00"
  },
  "slides": [
    {
      "index":            1,                              // 1-based
      "layout":           "Title Slide",                  // layout name from pptx
      "title":            "Quarterly Review",             // primary title placeholder
      "subtitle":         "Q3 2025",                      // placeholder idx=1 if != title
      "content_markdown": "…markitdown output for this slide only…",
      "bullets":          ["…", "…"],                     // deduped, order preserved
      "tables": [
        {
          "headers": ["Region", "Q3"],
          "rows":    [["NA", "12"], ["EU", "8"]]
        }
      ],
      "charts": [
        {
          "type":       "BAR_CLUSTERED",                  // python-pptx enum name
          "title":      "Revenue by region",
          "categories": ["NA", "EU", "APAC"],
          "series":     [{"name": "Q3", "values": [12, 8, 5]}],
          "note":       ""                                // populated on partial extract
        }
      ],
      "images": [
        {
          "path":       "/abs/path/…/slide-01-pic1-abc12345.png",
          "alt":        "Picture 3",                       // pptx shape name
          "shape_name": "Picture 3"
        }
      ],
      "notes":        "Speaker note text.",               // "" if none
      "image_render": ""                                  // reserved; the full slide PNG lives
                                                          // in the manifest's slides_dir as
                                                          // slide-<index:02d>.png
    }
  ]
}
```

### Field semantics — hard rules

| Field | Truth level | Agent MUST use verbatim |
|---|---|---|
| `deck.title`, `deck.author` | authoritative | yes if non-empty |
| `slides[].title` | authoritative | yes if non-empty |
| `slides[].subtitle` | authoritative | yes if non-empty |
| `slides[].bullets` | authoritative | yes — do not paraphrase |
| `slides[].content_markdown` | high fidelity from MarkItDown | use as backup / structural hint |
| `slides[].tables[].headers/rows` | authoritative | yes — reproduce as markdown table |
| `slides[].charts[].categories/series` | authoritative | yes — reproduce as markdown table |
| `slides[].charts[].note` | diagnostic | show to user if non-empty |
| `slides[].images` | authoritative paths | link with vision-derived alt text |
| `slides[].notes` | authoritative | include as blockquote if non-empty |
| `slides[].layout` | authoritative | render as `*Layout: <name>*` |

Rule of thumb: **if it's in `extract.json`, it is the source of truth**. The PNG is for anything that isn't in `extract.json` (diagrams, arrows, color emphasis, hand-drawn shapes, SmartArt, org charts, screenshots) and for verifying that the text track is complete.

---

## Dual-file markdown structure

The agent writes **two** files with identical semantic content:

- **`<slug>.md`** — CONDENSED. No image references at all. Default choice for LLM consumers.
- **`<slug>.with-images.md`** — DETAILED. Same content + plain-link references to slide renders and embedded images. For human audit.

The template below shows `*.with-images.md`; produce `*.md` by removing the `[figure — …]` and `[Slide N — source render]` lines.

### Top matter (written LAST, into both files identically)

```markdown
# <Deck title>

> Source: <input filename> • <N> slides • Converted <YYYY-MM-DD>

## Executive summary

<3–5 sentences that synthesize the deck's argument. Grounded in the actual
per-slide content just produced, not on the title slide alone.>

## Contents

1. [Slide 1: <slide-1 title>](#slide-1-slug-of-title)
2. [Slide 2: <slide-2 title>](#slide-2-slug-of-title)
…

---
```

### Per-slide section (in `<slug>.with-images.md`)

```markdown
## Slide N: <title>

*Layout: <layout name>*

<Subtitle on its own line, if any.>

<All bullets as a markdown list, verbatim from extract.json.>

<Tables as markdown tables, verbatim from extract.json.>

### <Chart title>          <!-- one ### block per chart -->

<Prose description of what the chart shows: what's being compared, what the
takeaway visually is, any highlighted series/category. 2–4 sentences.>

| <col> | <col> | <col> |
|---|---|---|
| … | … | … |

<Vision-derived description of any diagrams, arrows, callouts, colour
emphasis, embedded screenshots, or hand-drawn elements the text track
missed. Prose paragraphs, in reading order — thorough enough that a reader
who never sees the images still understands the slide.>

[figure — short vision-derived description](./<deck-name>-assets/images/<slide-N-picM>.png)
<!-- ONLY IN *.with-images.md — one per embedded image at its point in
     reading order. Plain link — NEVER ![...](...) inline embed. -->

> **Speaker notes:** <notes text>            <!-- only if notes non-empty -->

[Slide N — source render](./<deck-name>-assets/slides/slide-NN.png)
<!-- ONLY IN *.with-images.md — plain link, NEVER inline embed. -->

---
```

### Same section in `<slug>.md` (condensed)

Identical, minus the two lines flagged as "ONLY IN *.with-images.md" above:

```markdown
## Slide N: <title>

*Layout: <layout name>*

<Subtitle on its own line, if any.>

<All bullets as a markdown list, verbatim from extract.json.>

<Tables as markdown tables, verbatim from extract.json.>

### <Chart title>

<Prose description of what the chart shows.>

| <col> | <col> | <col> |
|---|---|---|
| … | … | … |

<Vision-derived description of visual elements — carries the meaning that
would otherwise be in the images.>

> **Speaker notes:** <notes text>

---
```

### Slide anchor slugs

Markdown auto-anchors headings by lowercasing, replacing spaces with `-`, and stripping punctuation. Write TOC links as `[Slide 3: Revenue by region](#slide-3-revenue-by-region)`. If two slides have the same title, disambiguate manually with a suffix.

### Special-case slides

| Case | Handling |
|---|---|
| Blank slide | Heading `## Slide N: (blank)` + `*Layout: <name>*` + PNG link (only in `*.with-images.md`). Nothing else. |
| Divider / section header | Heading `## Slide N: <title>` + `*Layout: <name>*` + PNG link (only in `*.with-images.md`). Any short body text as a paragraph. |
| Cover / title slide | Heading + `*Layout: <name>*` + subtitle + PNG link (only in `*.with-images.md`). |
| Appendix without title | `## Slide N: (untitled)`; still full body treatment. |
| Slide with no PNG (rasterizer failed to produce this index) | In `*.with-images.md`, replace the PNG link line with `<!-- slide render unavailable -->`. `*.md` (condensed) is unaffected — it never had image references. |

---

## File paths in `*.with-images.md`

All PNG paths in `*.with-images.md` MUST be relative to the markdown file itself:

- Full slide render: `./<deck-name>-assets/slides/slide-NN.png`
- Embedded image:    `./<deck-name>-assets/images/<basename-from-extract.json>`

Compute the basename by taking `Path(images[].path).name` from `extract.json`. Do not copy paths verbatim — the extractor writes absolute paths, but the markdown needs relative ones.

**All image references use markdown *link* syntax `[label](path)`, not embed syntax `![alt](path)`** — see `slide-synthesis-prompt.md` rule 10 for rationale.

---

## Executive summary — grounding rules

Written last, after every slide section is complete. Must:

1. Identify the deck's audience (from title-slide subtitle, cover image, speaker notes on slide 1).
2. State the deck's central claim in one sentence.
3. Name the 2–4 supporting arguments (typically = the main content slides' key lines).
4. Note the ask / recommendation if any (typically = last slide's title or first bullet).
5. Never introduce a fact that isn't already in the deck.

Draw only from `extract.json` and the vision-derived text you already wrote — do not re-read the PNGs a second time for the summary. If the deck lacks a clear claim, say so plainly: `The deck presents a status update without a specific recommendation.`
