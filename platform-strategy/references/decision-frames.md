# Decision Frames

Routing index. When the user's request is fuzzy, map it to the models and metaphors that apply, and to the interview questions to run first. Use this after classifying the request (doc, deck, brainstorm) and before drafting.

> Condenses ideas from Hohpe's *Platform Strategy*. See SKILL.md → Source.

| User's real question (however phrased) | Anchor metaphor | Supporting models | Run these interview blocks first |
| --- | --- | --- | --- |
| Why is our platform not being adopted? | Sink or float (#9) | non-linear adoption, opinionated vs. restrictive | 2, 3, 8 |
| How do we scope V1 / what goes in first? | Fruit salad or basket (#7) | Fab Four, 7 Cs | 1, 2, 4 |
| How do I pitch this to the CFO / board? | Platform paradox (#3) | Mechanisms not magic, Platform Inc. | 2, 3, 5 |
| Our platform team is drowning in tickets | IT platform vs. services (#4) | Platform Inc., diamond team | 4, 9 |
| What should we stop doing / cut? | Beware the grim wrapper (#10) | Build abstractions not illusions | 6, 4 |
| How do we grow past the early adopters? | Sink or float (#9) | non-linear adoption, tiering and slicing | 8, 3 |
| Should we build or buy? | Opinionated vs. restrictive (#6) | book ch. "Procuring a Platform" | 1, 3 |
| How do we prove the platform works? | (user surprise as test) | Mechanisms not magic | 2, 5 |
| How much should the platform hide? | Build abstractions not illusions (#11) | Failure doesn't respect abstraction | 6 |
| What are we on the hook for (support/SLA)? | Serviced apartments (#14) | Failure doesn't respect abstraction, 7 Cs | 7, 6 |
| How should the platform team be organized? | Diamonds vs. pyramids (#16) | Platform Inc., multi-sided team | 9 |
| Why does growth feel chaotic / multi-directional? | Evolution is a cube (#15) | Tiering and slicing | 8 |
| Is this even a platform or just shared services? | IT platform vs. services (#4) | Fab Four, fruit salad or basket | 1, 2, 4 |
| Are we standardizing or straitjacketing? | Opinionated vs. restrictive (#6) | Platform paradox | 3 |

Note: "Fab Four" and "7 Cs" in the Supporting column are frameworks the book *names* but whose contents this skill does not reproduce — apply them only from the book (see mental-models.md). They never serve as a standalone anchor metaphor.

## How to use this table

1. Restate the user's request as one of the "real questions" above (or the nearest match).
2. Take the anchor metaphor as the default anchor for the artifact (override only with a reason).
3. Load the supporting models from `mental-models.md`.
4. Run the listed interview blocks first (`assets/interview-script.md`), then the rest of **[MIN]**.
5. Before drafting, check the matching entries in `failure-modes.md` — most questions above map to a specific failure the artifact must avoid.

## When two questions collide

If the request spans several rows (common), pick the anchor for the *primary* decision the user must make now, and reference the others as secondary. Do not stack multiple anchor metaphors — one metaphor domain per artifact.
