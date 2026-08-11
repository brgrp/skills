# Slide synthesis rubric

The agent's job, in full. Follow these rules literally when producing the two markdown files.

---

## Inputs the agent has

- `extract.json` — verbatim text, tables, chart series, speaker notes, image manifest.
- `slides/slide-NN.png` — one render per slide at 300 DPI.
- `images/*.png|jpg` — every embedded image from the pptx, dumped as separate files.

## The outputs (two markdown files, one asset tree)

- **`<slug>.md`** — CONDENSED. LLM-first. No image references at all. The default file downstream tools should consume.
- **`<slug>.with-images.md`** — DETAILED. Same narrative + plain-link references to every slide render and every embedded image. For human audit / spot-check against the source pixels.
- **`<slug>-assets/`** — folder tree the extractor already prepared (`slides/*.png`, `images/*`).
- **`README.md`** — usage guidance, pre-written by the orchestrator; the agent does not author this.

The two `.md` files carry identical semantic content. Only difference: image-reference lines are present in `*.with-images.md` and absent in `*.md`.

---

## Design contract (non-negotiable)

**A reader of `deck.md` who never sees a single image must still understand every slide.** This is what makes the condensed file viable as the default. If you find yourself writing "see image" in prose, that's a signal to write more vision-derived prose instead — describe what the diagram shows, what colours mean, what arrows connect, what a screenshot depicts.

---

## Ten hard rules

1. **`extract.json` is the source of truth for text and numbers.** Every string it contains — titles, subtitles, bullets, table cells, speaker notes — is verbatim in the markdown. Do not paraphrase.

2. **Chart data as markdown tables from native series.** If `slides[N].charts[K]` has non-empty `categories` and `series`, render it as a markdown table plus a `###` heading with the chart title and a 2–4 sentence prose description. Do NOT re-read numbers from the PNG when the JSON has them.

3. **Chart data via vision when native series is missing.** If `charts` is empty for a slide but you see a chart / diagram / SmartArt / org chart in the PNG, translate what you can read from pixels into prose + a markdown table. When individual values are unreadable, write `<!-- values unclear from render; see slide render -->` rather than guessing.

4. **Never invent numbers.** If a number is not in `extract.json` and not clearly legible in the PNG, do not write it. Say values are unclear. Vision hallucination of quantitative facts is the single biggest failure mode this pipeline exists to prevent.

5. **Every slide gets one `## Slide N: <title>` heading.** Always. Titles come from `slides[N].title`. Empty title → derive from the visible headline on the render (common with corporate templates where the title placeholder is empty but the visual title is present), else fall back to `## Slide N: (untitled)`.

6. **Speaker notes as a blockquote at the END of the slide section.** Only if `slides[N].notes` is non-empty:
   ```markdown
   > **Speaker notes:** <notes text, verbatim, with internal newlines preserved as line breaks>
   ```

7. **Vision-derived prose must be complete.** For every diagram, flowchart, org chart, screenshot, and colour-coded element on a slide, the prose must describe it in enough detail that a reader without the image can:
   - name the visible entities;
   - understand the relationships/arrows between them;
   - reproduce any values that are legible;
   - infer any meaning conveyed by colour, highlight, or emphasis.

8. **Linear reading order.** Left-to-right, top-to-bottom. Do not reproduce columns or absolute positioning. If a slide has two logical columns, render them as two consecutive paragraphs/lists.

9. **Separate slides with `---`** (horizontal rule) between every `## Slide N:` section.

10. **Image references — only in the detailed file `<slug>.with-images.md`, and only as plain markdown links.**
    - Full-slide render at the end of each slide section:
      ```markdown
      [Slide N — source render](./<slug>-assets/slides/slide-NN.png)
      ```
    - Pptx-embedded image inline, at the point in reading order where it belongs:
      ```markdown
      [figure — short vision-derived description](./<slug>-assets/images/<basename>)
      ```
    - Basename = `Path(slides[N].images[K].path).name` from `extract.json`.
    - **Never** use `![…](…)` inline-embed syntax. Some vision-enabled agents (Claude Code, opencode) auto-attach files referenced with embed syntax as vision inputs, which would defeat the compact-file design.

---

## Per-slide execution order (write into `<slug>.with-images.md` first)

For each slide, in this exact order:

1. Write `## Slide N: <title>`.
2. Write `*Layout: <layout>*` (skip if empty).
3. Write subtitle on its own line (skip if empty).
4. Write bullets as an unordered markdown list, verbatim.
5. Write every native table from `tables[]` as a markdown table.
6. For each `charts[]` entry: write `### <chart title>`, a prose description, and the data table.
7. Write vision-derived prose for every visual element the text track missed (diagrams, arrows, colour emphasis, screenshots not in `images[]`). Be thorough — a condensed-file reader depends on this prose.
8. Write a plain-link reference to each pptx-embedded image `[figure — description](./…-assets/images/…)` at the point it belongs in reading order. **This line appears only in `<slug>.with-images.md`.**
9. Write speaker notes as a blockquote (skip if empty).
10. Write a plain-link reference to the full-slide render `[Slide N — source render](./…-assets/slides/slide-NN.png)`. **This line appears only in `<slug>.with-images.md`.**
11. Write `---`.

---

## Deck-level top matter (write LAST, into both files identically)

Once every `## Slide N:` section is done, scroll back to the top and write:

1. **H1 title.** From `deck.title` if non-empty; else `slides[0].title` if non-empty; else humanized filename.
2. **Metadata line.** `> Source: <basename of input> • <N> slides • Converted <YYYY-MM-DD>`
3. **Executive summary.** 3–5 sentences that synthesize the deck's argument. Grounded in the slide sections you just wrote — do not re-read the PNGs for the summary. Must identify audience, central claim, supporting arguments, and the ask (if any).
4. **Contents.** Numbered list, one line per slide, linking to each `## Slide N:` anchor.

---

## How to produce the two files efficiently

Write `<slug>.with-images.md` in full first (with steps 8 and 10 present). Then produce `<slug>.md` by deleting every line that begins with either:

- `[Slide ` (the full-slide render link)
- `[figure — ` (the pptx-embedded image link)

Do not delete blank lines around them mechanically — a stray double blank line is fine and won't affect rendering.

This guarantees the two files stay in perfect sync: same H1, same executive summary, same slide sections, same tables, same prose, same speaker notes. Only the image-reference lines differ.

---

## Worked example

**`extract.json` fragment for slide 3:**

```json
{
  "index": 3,
  "layout": "Title and Content",
  "title": "Revenue by region",
  "subtitle": "",
  "bullets": ["Fastest growth in APAC", "NA remains largest by absolute revenue"],
  "tables": [],
  "charts": [{
    "type": "BAR_CLUSTERED",
    "title": "Revenue by region (Q3)",
    "categories": ["NA", "EU", "APAC"],
    "series": [{"name": "Q3 2025", "values": [12.4, 8.1, 5.7]}],
    "note": ""
  }],
  "images": [],
  "notes": "Emphasise APAC acceleration but caution on comp base."
}
```

**Correct output in `deck.with-images.md` for slide 3 (vision noted APAC bar is red):**

```markdown
## Slide 3: Revenue by region

*Layout: Title and Content*

- Fastest growth in APAC
- NA remains largest by absolute revenue

### Revenue by region (Q3)

A clustered bar chart comparing Q3 2025 revenue across three regions. APAC is highlighted in red to draw attention; NA and EU are neutral grey.

| Region | Q3 2025 |
|---|---|
| NA | 12.4 |
| EU | 8.1 |
| APAC | 5.7 |

> **Speaker notes:** Emphasise APAC acceleration but caution on comp base.

[Slide 3 — source render](./quarterly-review-assets/slides/slide-03.png)

---
```

**Same slide in `deck.md` — identical except the source-render line is stripped:**

```markdown
## Slide 3: Revenue by region

*Layout: Title and Content*

- Fastest growth in APAC
- NA remains largest by absolute revenue

### Revenue by region (Q3)

A clustered bar chart comparing Q3 2025 revenue across three regions. APAC is highlighted in red to draw attention; NA and EU are neutral grey.

| Region | Q3 2025 |
|---|---|
| NA | 12.4 |
| EU | 8.1 |
| APAC | 5.7 |

> **Speaker notes:** Emphasise APAC acceleration but caution on comp base.

---
```

Note what happened:

- Bullets: verbatim from JSON.
- Chart: `###` heading = chart title from JSON, prose adds the visual detail (APAC red) vision noticed, table = JSON series data — not re-read from pixels.
- Speaker notes: verbatim, blockquote at end.
- Difference between the two files: just the one `[Slide 3 — source render]` line.

---

## Exception: slide with no PNG

If the extractor did not produce a PNG for a slide index (unusual — soffice failure or partial render):
- In `deck.with-images.md`: omit the `[Slide N — source render]` line and write `<!-- slide render unavailable -->` in its place.
- In `deck.md`: no change from normal — no image references appear there anyway.

---

## Anti-patterns to avoid

- ❌ Rewording bullets to be "clearer".
- ❌ Re-reading numbers off the PNG when they exist in `extract.json`.
- ❌ Writing "see image" or "as shown in the diagram" in prose — that shows the vision-derived prose is incomplete. Describe the visual content explicitly instead.
- ❌ **Using `![…](…)` inline-embed syntax anywhere in either file** — inline embeds cause vision-enabled LLM readers to auto-fetch every slide PNG, ballooning downstream cost by ~100× and defeating the point of the compact md.
- ❌ Putting image references in `deck.md` (the condensed file). They belong only in `*.with-images.md`.
- ❌ Skipping speaker notes because they seem "internal".
- ❌ Merging multiple slides into one section.
- ❌ Inventing categories or series when the chart is illegible.
- ❌ Rendering positional layout ("in the top-right corner…") — you write in linear reading order.
- ❌ Writing the executive summary from the title slide alone. It must reflect the whole deck.
- ❌ Absolute paths in image links. Always relative to `<slug>.with-images.md`.
- ❌ Letting the two files drift out of sync. If you edit a slide section, edit both.
