---
name: pyramid-principle
description: Turn any communication into answer-first, MECE-structured output using Barbara Minto's Pyramid Principle. Applies to presentations, READMEs, and brainstorm output. USE FOR "structure this deck", "shape my pitch", "clean up my README", "help me tell this story", "make this clearer", "what's my main point", "top-down", "answer first", "SCQA", "MECE", "governing thought", "executive summary", "brain dump", "I have a bunch of ideas". DO NOT USE FOR grammar-only copyediting, slide visual design, code generation, or data analysis.
license: MIT
metadata:
  author: brgrp
  version: 1.1.1
---

# Pyramid Principle

**When activated, produce answer-first, MECE-structured output. Do not explain the method to the user — apply it.**

Barbara Minto's method for structuring writing and speaking so the reader gets the answer first and the logic underneath is self-evidently sound. Invented at McKinsey, 1960s.

> "The pyramid is a tool to help you find out what you think." — Barbara Minto

## On activation, run these six steps

Run them in order.

1. **Identify the output type.** Presentation/deck → Workflow A. README/doc/memo → Workflow B. Messy dump of ideas → Workflow C first, then A or B.
2. **Ask at most one clarifying question**, only if strictly needed: the *audience* (who reads this?) or the *decision* (what should they do after?). Skip if obvious from context.
3. **Build the pyramid** using the chosen workflow. Do this in your reasoning, not aloud.
4. **Render** into the target format (deck outline, README markdown, memo prose).
5. **Run the quality checklist** at the end of this file and self-correct silently before delivering.
6. **Deliver the finished output**, not the pyramid scaffolding — unless the user explicitly asked to see it.

## The method is four rules that force answer-first structure

### SCQA — the opening

Every piece opens with a story that ends in the answer:

- **S — Situation:** stable context the reader already accepts.
- **C — Complication:** the change or tension that raises a question.
- **Q — Question:** the specific question C raises.
- **A — Answer:** your **governing thought** — one sentence that answers Q. This is the apex of the pyramid.

### Three rules of the pyramid

Every idea below the apex must obey all three:

1. **Summarize-above:** the point above summarizes the points below it.
2. **Same-kind:** ideas grouped together are logically the same kind — all reasons, all steps, all findings, all recommendations. **Never mixed.**
3. **Logical order:** one of exactly four — deductive (premise → premise-about-premise → conclusion), chronological, structural (parts of a whole), or degree-of-importance.

### MECE

Each grouping is **M**utually **E**xclusive (no overlap) and **C**ollectively **E**xhaustive (nothing important missing). Pronounced "meece" (Minto: "I invented it, so I get to say how to pronounce it"). MECE is a test — run it, don't decorate with it.

### Vertical Q&A

Every point provokes exactly one reader question — **Why? How? So what?** — and the level below must answer it. If not, the pyramid is broken.

Full theory, worked examples, storyline variants, and Minto's problem-solving method: see `references/minto-deep-dive.md`.

## Each output type has its own workflow (step 3, expanded)

These expand step 3 of the procedure above — pick the one matching the output type you identified in step 1.

### Workflow A — Presentations

Use for decks, keynotes, exec reviews, spoken narratives.

1. Write SCQA in prose (4 short paragraphs). A = governing thought.
2. Derive **2–4 key-line messages** that jointly answer "Why should the audience believe A?" — MECE, same-kind, one ordering.
3. Under each key line, list **2–5 supporting points** (data, examples, sub-arguments). Same rules.
4. Map to slides: slide 1 = SCQA + governing thought. Slide 2 = agenda (the key lines). Slides 3+ = one per key line. Final slide = restated A + explicit next step.
5. **Every slide title is a full-sentence point, not a topic label.** If someone flips through with the sound off, titles alone tell the story.

Template: `assets/presentation-template.md`.

### Workflow B — READMEs

Use for READMEs, design docs, technical memos.

1. Write a one-sentence governing thought under the H1.
2. Write SCQA as the first paragraph section.
3. Derive **2–5 top-level sections** = the reader's next questions in order (What is it? Why use it? How install? How use? How does it work? When not to? How contribute?). MECE.
4. **First sentence under every H2 states the section's point.** Detail follows.
5. Order sections by reader priority: identity → value → onboarding → usage → mechanism → limits → community.
6. **Prune** anything that doesn't trace up to the governing thought.

Template: `assets/readme-template.md`.

### Workflow C — Brainstorming (bottom-up)

Use when the input is a messy pile of ideas.

1. **Dump** every idea, one per line.
2. **Cluster** by same-kind.
3. **MECE each cluster** — merge overlaps, add gaps, split fake groups.
4. **Abstract a summary sentence** per cluster — says something new, not a category name.
5. **Group the summaries** and repeat until you reach one sentence = governing thought.
6. **Invert to top-down** — deliver apex first, then key lines, then support.

Template: `assets/brainstorm-worksheet.md`. If the brainstorm output still has no clear governing thought, drop into problem-solving mode (`references/minto-deep-dive.md` § "Problem-solving").

## Before delivering, every output must pass this checklist

Any "no" → back to the pyramid.

- [ ] **Answer first?** Governing thought lands in the first paragraph / first slide / one-liner under H1.
- [ ] **SCQA?** Situation, Complication, Question, Answer are present and in order.
- [ ] **Summarize-above?** Every parent genuinely summarizes its children.
- [ ] **Same-kind?** Every grouping is one kind — all reasons, or all steps, or all findings, or all recommendations. Not mixed.
- [ ] **Logical order?** Deductive / chronological / structural / degree — defensible.
- [ ] **MECE?** No overlaps in a group; nothing important missing.
- [ ] **Vertical Q&A works?** Every point raises a question the layer below answers.
- [ ] **Full-sentence points, not topic labels?** Slide titles and section headers state points.
- [ ] **Nothing orphaned?** Every leaf traces up to the apex.

## Example: a raw dump becomes a pyramid

**Before** — dump the user brings in:

> "Our Q3 numbers. Revenue is up 12%. New pricing rolled out in July. Churn is down but only in SMB. Enterprise pipeline is soft. We hired two AEs. NPS is up 8. We should double down on SMB."

**After** — reshaped as an exec memo intro (three key lines are **all recommendations** — same-kind):

> **S:** We ran the first full quarter under pricing v2, rolled out in July.
> **C:** SMB metrics are compounding but Enterprise pipeline has softened, and Q4 spend is locked next week.
> **Q:** How should we allocate Q4 growth spend?
> **A (governing thought):** Shift Q4 investment toward SMB, hold Enterprise spend flat, and diagnose Enterprise before adding more — because that's where the pricing signal is clear and where it isn't.
>
> **Recommendation 1 — Shift Q4 marketing spend to SMB acquisition.**
> Supporting: revenue +12%, SMB churn down, SMB NPS +8, all concentrated in SMB under pricing v2.
>
> **Recommendation 2 — Hold Enterprise spend flat pending diagnosis.**
> Supporting: Enterprise pipeline soft despite two new AEs — signal points to targeting/positioning, not capacity.
>
> **Recommendation 3 — Run a 4-week Enterprise diagnostic before Q1 planning.**
> Supporting: without diagnosis, any spend increase risks compounding the pipeline issue.

Notice the raw facts are unchanged. The pyramid makes the ask land in one sentence and the reader knows exactly what to challenge. All three key lines are recommendations (same-kind); each is supported by findings below (also same-kind within their group).

## For depth, consult the deep dive

- `references/minto-deep-dive.md` — vertical/horizontal logic, top-down vs bottom-up construction, SCQA storyline variants, MECE tests, four orderings with worked examples, Minto's problem-solving method.

## Source

Barbara Minto, *The Minto Pyramid Principle: Logic in Writing, Thinking and Problem Solving* (1996). Primary interview: McKinsey Alumni News, "Barbara Minto: MECE — I invented it, so I get to say how to pronounce it".
