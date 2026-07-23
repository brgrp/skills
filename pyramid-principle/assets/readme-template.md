# README Template — Pyramid-shaped

Fill in top-to-bottom. The whole point is that the reader gets the answer in the first paragraph.

---

```markdown
# <Project name>

> <One-sentence governing thought: what this is + why it matters, in a claim, not a topic.>

## What this is (SCQA in prose)

<Situation — what the reader already knows about the space.>

<Complication — what's missing / broken / new that made this project necessary.>

<Question — the specific question this project answers.>

<Answer — restatement of the governing thought, expanded to 1–2 sentences.>

## Why you'd use it

<Full-sentence point stating the primary use case.>

- Concrete use case 1
- Concrete use case 2
- Concrete use case 3

## How to install

<One-sentence full point: e.g. "Install with a single command; no build step required.">

```bash
<install command>
```

## How to use it

<One-sentence full point stating the mental model.>

<Minimal working example — the shortest code / commands that produce real output.>

```bash
<usage>
```

## How it works

<One-sentence full point summarizing the architecture.>

- Component 1: <one-line role>
- Component 2: <one-line role>
- Component 3: <one-line role>

## When not to use it

<One-sentence full point — honest scoping.>

- Case 1
- Case 2

## Contribute

<Full-sentence point about the contribution model.>

## License

<License, one line.>
```

---

## Rules the template enforces

- **Under the H1**, one sentence states the governing thought. No preamble.
- **First heading is the SCQA**, written as prose the reader will actually read.
- **Every H2 is a full-sentence question the reader is asking** at that point in the doc (What is it? Why use it? How install? How use? How does it work? When not to? How contribute?). The MECE structure is: identity → value → onboarding → usage → mechanism → limits → community.
- **First sentence under every H2 states the section's point.** Detail follows.
- **No section exists that doesn't trace up to the governing thought.**

## MECE check for READMEs

- [ ] Sections don't overlap (e.g. "Install" ≠ "Getting Started"; pick one).
- [ ] Nothing critical missing (a reader with zero context can go from install to first success).
- [ ] Ordered by reader priority — identity first, contribution last.

## Final checklist

- [ ] Reader knows what this is and why they'd care within 3 sentences.
- [ ] SCQA is present, in order, in the opening.
- [ ] Every section header is a full-sentence question or point (not "Installation" but "How to install").
- [ ] Every section's first sentence states the section's point.
- [ ] Anything not traceable to the governing thought has been cut or moved.
