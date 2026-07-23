---
name: platform-strategy
description: |
  Interview-driven skill for shaping platform strategy artifacts (strategy documents, executive presentations, and brainstorm outputs) using Gregor Hohpe's book "Platform Strategy: Innovation Through Harmonization." The agent runs a diagnostic interview based on the book's decision spine (what kind of platform, users and surprise, opinionated vs. restrictive, fruit salad or basket, sink or float, abstractions vs. illusions, tenancy, adoption, team shape) before drafting anything, then delivers an artifact anchored on one of Hohpe's metaphors and checked against his failure modes.
  USE FOR: platform strategy doc, platform vision, internal developer platform pitch, IDP strategy, platform team charter, platform roadmap narrative, platform exec deck, "why our platform matters", "make the case for the platform", "structure the platform story", innovation through harmonization, platform paradox, opinionated platform, fruit salad or fruit basket, sink or float, platform brainstorm.
  DO NOT USE FOR: implementing a platform, choosing tools (Backstage, Kubernetes, ArgoCD, etc.), day-2 operations, cloud migration strategy, generic architecture writing, or platform strategy work grounded in sources other than Hohpe's book.
license: MIT
metadata:
  author: brgrp
  version: 1.0.0
---

# Platform Strategy

Interview-first skill for shaping and telling the story of a platform strategy using Gregor Hohpe's book *Platform Strategy: Innovation Through Harmonization*. It shapes the narrative the way the book does — anchor metaphor, the harmonization paradox, honest trade-offs, and a punchline — rather than importing any external storytelling framework. The skill is scaffolding; the substance belongs to the book. See [Source](#source) for attribution and how to buy it.

> "If your users haven't built something that surprised you, you probably didn't build a platform." — Gregor Hohpe (book page)

## Provenance rule (read first)

This skill is keyed to the book's **public table of contents** — chapter titles and their one-line subtitles. The book's full arguments are not reproduced here.

Some frameworks are **named** by the book but their contents are **not public**: the **Fab Four** (its four members), the **7 "C"s** of platform quality (the seven words), and **ACED** (the acronym's expansion). This skill deliberately does **not** state what these contain.

**The agent must never invent the contents of a Hohpe framework.** Where the skill names one without its contents, cite the chapter and either apply it from the user's copy of the book or flag it as a gap. Confident fabrication of a named framework is the one failure this skill must not commit — it would fail the book's own standard of decision discipline. Reference notes marked *(interpretation — verify against the book)* are this skill's working reading, not established fact; do not present them to users as quotes.

## When to activate this skill

Activate when the user is shaping communication about a developer or in-house IT platform: a strategy document, a vision or charter, an executive pitch, a platform team README, a roadmap narrative, or the messy pile of ideas that comes before any of those. Signals in the user's request include "platform strategy", "platform vision", "make the case for our platform", "pitch our IDP", "why our platform matters", "structure the platform story", "platform roadmap narrative", "platform team charter", "platform brainstorm".

**Do not activate** for implementation work (how to run Kubernetes, how to configure Backstage), tool selection, day-2 operations, cloud migration strategy, generic architecture writing, or platform strategy work grounded in sources other than Hohpe's book.

## One-line premise

**Innovation through harmonization.** Every artifact this skill produces must earn that claim. If the artifact does not explain how standardization *enables* rather than restricts innovation in this specific context, it is not a Hohpe-style platform strategy. Reshape or reject.

## Iron rule: interview before delivery

The agent must **not** draft a strategy document, deck, or brainstorm output until the **[MIN]** questions in `assets/interview-script.md` are answered. There is no preview mode, no skeleton-first mode, no "just show me something to react to." Strategy without diagnosis is a wish.

If the user pushes back, the agent explains: the book's discipline is that strategy is the difference between making a wish and making it come true. Drafting before diagnosis produces the tool-inventory-posing-as-strategy failure mode (see `references/failure-modes.md`).

If the user is in a real hurry, run only the **[MIN]** subset — typically nine questions, answerable in five minutes — and mark the resulting artifact "diagnostic-thin: [FULL] pass recommended before external use."

## The diagnostic spine

Nine interview blocks, matching the book's decision structure. Each block answers a question that unlocks a specific decision the artifact must make. Full script with question wording, probes, and unlocks is in `assets/interview-script.md`.

1. **What kind of platform** — what kind of platform is this, in plain terms? (The book's "Fab Four" is a business-model lens; apply it only from the book, don't invent a typology.)
2. **Users and surprise** — who are the users, and what would count as a user surprising you? If no surprise is imaginable, this is a services layer, not a platform. **This is the skill's primary litmus test.**
3. **Opinionated vs. restrictive** — where does the platform have a mind of its own, and where does it get out of the way? Users love opinionated, despise restrictive.
4. **Fruit salad or fruit basket** — is there a coherent whole, or a collection of independently useful services glued together?
5. **Sink or float** — does the economics work without mandate? Platforms that need to be mandated are already sinking.
6. **Abstractions vs. illusions** — what does the platform hide, and what leaks through? An illusion breaks the first time reality doesn't cooperate.
7. **Tenancy model** — are you selling, leasing, or providing serviced apartments? Different models, different obligations.
8. **Adoption shape** — which users have adopted, which are next, and what mechanism (not mandate) feeds them? (The book stresses adoption is *not* linear; don't assume a smooth ramp or attribute a specific S-curve model to Hohpe.)
9. **Team shape** — pyramid or diamond, and who owns the interfaces to users, sponsors, and providers?

## Choosing the mental model

Once the interview is complete (or **[MIN]** is complete), use the **single routing index** in `references/decision-frames.md` to select which of Hohpe's models and metaphors the artifact will lean on. That file is the one place to map a user's question to an anchor. The metaphor content lives in `references/metaphor-catalog.md`; the non-metaphor frameworks in `references/mental-models.md`.

## Anchor metaphor selection

Pick **exactly one** anchor metaphor per artifact. Hohpe's rule from the book: one metaphor domain per session. Mixing metaphors dilutes the thinking tool into decoration. The catalog holds 16 metaphors; each has an entry describing what it claims, the tension it carries, when to use it, when not to, and adjacent moves for when the audience runs past the finish line with it.

An artifact may reference secondary metaphors briefly (e.g., "and here we're in serviced-apartment territory"), but the anchor is what the reader/audience should remember.

## Workflows

Pick one based on the requested output. Each workflow depends on a completed interview.

### Workflow A — Strategy document / README

Use for a platform strategy document, vision doc, charter, platform team README, or written narrative for the roadmap.

1. Run the interview (`assets/interview-script.md`).
2. Select the anchor metaphor (`references/metaphor-catalog.md`).
3. Fill `assets/strategy-doc-outline.md` section by section. Each section is annotated with the interview question numbers it draws from and the failure modes it must check against.
4. Run the quality checklist (below) and the failure-mode sweep (`references/failure-modes.md`) before returning the draft.

### Workflow B — Presentation / executive pitch

Use for an executive deck, sponsor pitch, town hall, or conference talk about a platform.

1. Run the interview. For a 20-minute pitch, **[MIN]** is often enough; for a strategy-defining deck, run **[FULL]**.
2. Select the anchor metaphor. The slide count is small — the metaphor is what the audience will remember.
3. Fill `assets/presentation-outline.md`: anchor metaphor → the paradox (harmonization enables innovation) → tension slide → mechanism slides → punchline → ask.
4. Reject any deck that opens with a tool inventory (Backstage, ArgoCD, Vault, etc.). Tools go in an appendix, not the opening.
5. Run the quality checklist and failure-mode sweep.

### Workflow C — Brainstorming

Use when the user arrives with a pile of platform ideas, features, or complaints and needs to converge on a story.

1. Dump: list every idea, one per line, no editing.
2. Apply the interview questions as evaluative filters (in the order given in `assets/brainstorm-worksheet.md`).
3. Group ideas by what kind of platform capability they imply (plain terms, not an invented typology).
4. Run each candidate through fruit-salad, sink/float, and abstraction/illusion filters.
5. Identify the user surprise the platform is supposed to enable.
6. Produce an apex claim (one sentence) and a candidate anchor metaphor.
7. Hand the result to Workflow A or B if a full artifact is wanted.

## Quality checklist (run before every delivery)

Every artifact — doc, deck, or brainstorm output — must pass all ten. Any "no" means back to the interview or the metaphor catalog.

- [ ] **Anchor metaphor named.** One metaphor from the catalog (or a defensible new one that passes the mirror test).
- [ ] **Harmonization → innovation claim.** The artifact states, in one sentence, how standardization *enables* innovation in this specific context.
- [ ] **Opinion declared.** The platform's opinions are explicit. Users can see where the platform has a mind of its own and where it gets out of the way.
- [ ] **User surprise as success test.** The artifact names at least one concrete surprise a user could produce that would count as success.
- [ ] **Non-goals listed.** What this platform is *not*. Kills the fruit-basket trap.
- [ ] **Adoption without mandate.** The adoption plan does not rely on "leadership will require it." Mechanisms, not decrees.
- [ ] **Abstractions are honest.** Nothing described as magic. Every "the platform handles X" is traceable to a mechanism.
- [ ] **Tenancy stated.** Selling, leasing, or serviced apartments — the model is explicit, not assumed.
- [ ] **Team shape stated.** Who owns interfaces to users, sponsors, providers. Diamond or pyramid, not left to imagination.
- [ ] **No tool inventory posing as strategy.** Tools appear only in service of a decision the strategy has already made.

## Inline before / after

**Before** — a typical bland pitch the user brings in:

> "We're building an internal developer platform on top of Backstage, ArgoCD, Vault, and Prometheus. It will provide golden paths for CI/CD, secrets management, and observability. Adoption will be driven by leadership mandate starting Q2."

Problems, using the book's lens: no anchor metaphor; no harmonization → innovation claim; no user surprise test; no non-goals; adoption is mandate-driven (sinking); tools are the strategy (inventory); no opinion is declared; team shape and tenancy are silent.

**After** — reshaped after a full interview, anchored on *fruit salad*:

> **Vision.** Our platform's job is to turn the friction of shipping software at [Company] into a shared, opinionated flow — a fruit salad, not a fruit basket. The value is in how the pieces combine, not in the pieces.
>
> **The paradox we bet on.** By harmonizing how services are built, released, and observed, we free teams from re-solving the same five problems every quarter and let them spend that time on the parts of their product that only they can build. Standards here are what buy us innovation elsewhere.
>
> **What success looks like.** In twelve months, a team we don't know about ships a new service on our platform and does something we didn't plan for — a use of our secrets rotation, our deploy graph, or our observability schema that surprises us. If no team surprises us, we didn't build a platform.
>
> **What we have opinions about.** Deploy topology, secrets handling, service identity, and observability schema. **What we get out of the way on.** Language choice, framework choice, database choice inside a service's own bounded context.
>
> **Non-goals.** We are not a shared code library. We are not a ticket-queue ops team. We are not a mandated compliance gate. If any of those emerge, we've become the wrong thing.
>
> **How we grow.** Two paying (in political capital) teams by end of Q1. A third by Q2 that came to us, not the other way around. If we're still selling to the same first two teams in Q3, the platform is sinking.
>
> **Team shape.** A diamond: product/design at the top, platform engineers in the middle, provider-facing engineers at the bottom. Interfaces to users, sponsors, and providers are named owners, not committees.
>
> **Tenancy.** Serviced apartments. Teams keep the keys and their belongings; we keep the building running.

Notice: the tool list disappeared (it lives in an implementation appendix). Every claim traces to a mechanism. The metaphor carries tension (a salad can be over-mixed and lose the ingredients; a basket loses coherence). The success test is a user surprise, not a KPI dashboard.

## Files

- `references/metaphor-catalog.md` — the 16 anchor metaphors. Claim, tension, when to use, when not to, adjacent moves.
- `references/mental-models.md` — non-metaphor frameworks named by the book: Fab Four, 7 Cs, ACED (named only, contents not reproduced), plus Platform Inc., tiering/slicing, non-linear adoption, team shapes.
- `references/decision-frames.md` — routing index: user's fuzzy question → which models and metaphors → which interview questions to prioritize.
- `references/failure-modes.md` — nine ways platform strategies fail per the book, with smell, underlying failure, and corrective move.
- `assets/interview-script.md` — the interview: **[MIN]** and **[FULL]** questions, ordered, with probes and unlocks.
- `assets/strategy-doc-outline.md` — section blueprint for a strategy doc / README, keyed to interview Q# and failure modes.
- `assets/presentation-outline.md` — slide blueprint with anchor metaphor / paradox / tension / mechanism / punchline slots.
- `assets/brainstorm-worksheet.md` — reduction procedure from messy input to apex claim.

## Source

All substantive content — models, metaphors, failure modes, decision structure — is drawn from and belongs to:

Gregor Hohpe, *Platform Strategy: Innovation Through Harmonization* (Leanpub, 2024). Book page: https://architectelevator.com/book/platformstrategy. Purchase: https://leanpub.com/platformstrategy.

This skill is a scaffolding and interview layer that helps an agent apply the book's thinking to a specific artifact. It does not reproduce the book's content. For substance, examples, interviews with platform builders, and the full argument, buy and read the book.
