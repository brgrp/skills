<!--
  Dual-output skeleton for the powerpoint-to-md skill.

  The skill produces two markdown files with identical semantic content:

    <SLUG>.md              CONDENSED — no image references. Default for LLMs.
    <SLUG>.with-images.md  DETAILED  — same content + plain-link image refs.

  Template below shows the DETAILED variant (with the image lines). Produce
  the CONDENSED file by removing lines matching:
      [figure — …](./…-assets/images/…)
      [Slide N — source render](./…-assets/slides/slide-NN.png)

  Never use ![alt](path) inline-embed syntax anywhere — see
  references/slide-synthesis-prompt.md rule 10 for rationale.

  Paths are always relative to the markdown file so the wrapping folder
  can be moved or renamed.

  Full rules: references/slide-synthesis-prompt.md
-->

# <TITLE>

> Source: <INPUT_FILENAME> • <N> slides • Converted <YYYY-MM-DD>

## Executive summary

<3–5 sentences grounded in every slide section written below. Identify
audience, central claim, supporting arguments, and the ask (if any).
Do not introduce facts that aren't already in the deck.>

## Contents

1. [Slide 1: <SLIDE-1 TITLE>](#slide-1-<slug>)
2. [Slide 2: <SLIDE-2 TITLE>](#slide-2-<slug>)
<!-- …one per slide -->

---

<!-- =====================  PER-SLIDE BLOCK (repeat) ====================== -->

## Slide N: <SLIDE TITLE>

*Layout: <LAYOUT NAME>*

<SUBTITLE ON ITS OWN LINE IF ANY>

- <bullet 1 verbatim>
- <bullet 2 verbatim>

<!-- native tables from extract.json.tables[] -->

| <col> | <col> |
|---|---|
| … | … |

<!-- charts: one ### block per chart -->

### <CHART TITLE>

<2–4 sentence prose description of what the chart shows and any visual
emphasis (highlighted bar, colour cue, callout arrow) that changes
meaning.>

| <col> | <col> |
|---|---|
| … | … |

<!-- vision-derived prose for diagrams/arrows/SmartArt/screenshots
     the text track missed, in reading order. THOROUGH enough that a
     reader of the condensed file (no images) still understands the slide. -->

[figure — short vision-derived description](./<SLUG>-assets/images/<embedded-image-basename>)
<!-- ONLY IN *.with-images.md — strip this line for the condensed file -->

> **Speaker notes:** <notes verbatim; only include this line if notes are non-empty>

[Slide N — source render](./<SLUG>-assets/slides/slide-NN.png)
<!-- ONLY IN *.with-images.md — strip this line for the condensed file -->

---

<!-- =====================  END PER-SLIDE BLOCK  ========================== -->
