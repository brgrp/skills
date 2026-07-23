# Interview Script

Ask these before drafting anything. **[MIN]** = the minimum set required before any draft. **[FULL]** = the complete set for a strategy-defining artifact. Each question notes what it unlocks. Use the probes when an answer is thin.

Ask in order. Do not draft until every **[MIN]** question has an answer. If the user resists, run only **[MIN]** and mark the artifact "diagnostic-thin."

> Applies Hohpe's *Platform Strategy* decision spine. See SKILL.md → Source.

---

## Block 1 — What kind of platform is this

**[MIN] Q1.** What kind of platform is this, concretely — who builds on it and to produce what?
- Probe: developer platform, internal IT platform, product platform? Describe it plainly. (Do not force it into an invented typology; the book's "Fab Four" is a business-model lens — apply it only if the user has the book. See references/mental-models.md.)
- Unlocks: business-model framing; downstream team shape.

**[FULL] Q1b.** What business outcome does this platform drive here?
- Unlocks: the harmonization → innovation claim.

## Block 2 — Users and surprise

**[MIN] Q2.** Who are the users, and what job are they trying to get done?
- Unlocks: user-surprise test; adoption plan; strategy-doc audience section.

**[MIN] Q3.** What would a user do on this platform that would genuinely surprise you? (If you can't name one, we're building a services layer, not a platform.)
- Probe: an unexpected combination, an unplanned use of an interface, a use case you didn't design for.
- Unlocks: success test; opinionated stance; the core of the pitch.

## Block 3 — Opinionated vs. restrictive

**[MIN] Q4.** Where does this platform have a mind of its own (strong defaults, paved road)?
- Unlocks: opinionated stance; raw material for the book's 7 Cs (contents not reproduced — see references/mental-models.md).

**[MIN] Q5.** For each strong opinion, what's the escape hatch when a user needs to go off-road?
- Probe: no escape hatch = restrictive = adoption risk (failure mode F3).
- Unlocks: opinionated-vs-restrictive line; adoption plan.

**[FULL] Q5b.** Which standard are you betting will buy downstream freedom (your "HTTP")? At which layer?
- Unlocks: the platform paradox claim; the harmonization argument.

## Block 4 — Fruit salad or fruit basket

**[MIN] Q6.** Is this a coherent whole or a collection of independently useful services?
- Probe: if a collection, what integrating opinion (the "dressing") makes the combination worth more than the parts?
- Unlocks: scope; non-goals; failure mode F4 check.

**[FULL] Q6b.** Are any current interactions still request-and-fulfill (tickets) rather than self-service? Which ones must convert?
- Unlocks: platform-vs-services check (F2); operating model.

## Block 5 — Sink or float

**[MIN] Q7.** Would any team adopt this *without* a mandate? Name them.
- Probe: if the honest answer is "no," the platform is sinking — fix value before rollout (F1).
- Unlocks: adoption plan; the buoyancy of the whole strategy.

**[FULL] Q7b.** What does the platform cost to run, and what pays for it (budget, chargeback, political capital)?
- Unlocks: Platform, Inc. framing; tenancy/pricing.

## Block 6 — Abstractions vs. illusions

**[FULL] Q8.** What does the platform hide from users, and what leaks through anyway?
- Unlocks: interface design; raw material for the 7 Cs.

**[FULL] Q9.** For each thing you hide, what does the user see when it fails, and does the platform help them then?
- Probe: if it strands the user, it's an illusion, not an abstraction (F6).
- Unlocks: reliability/support expectations; honesty check.

## Block 7 — Tenancy model

**[FULL] Q10.** Are you selling (they own and maintain), leasing (you maintain the shell), or serviced apartments (you run the building, they keep the keys)?
- Probe: what breaks at 3am, and who fixes it?
- Unlocks: operating model; SLAs; support boundaries (metaphor #14).

## Block 8 — Adoption shape

**[MIN] Q11.** Which users have adopted so far, which are next, and what mechanism (not mandate) feeds the next group?
- Probe: the book's point is that adoption is *not* linear — do not assume a smooth ramp. (Do not attribute a specific "S-curve/chasm" model to Hohpe unless the user has it from the book.)
- Unlocks: roadmap; tiering and slicing; growth story.

**[FULL] Q11b.** Which dimension of growth are you pushing this period, and what are you deliberately not growing yet?
- Probe: the book frames evolution as a multi-dimensional "cube"; ask the user for the dimensions rather than assuming breadth/depth/audience.
- Unlocks: roadmap (evolution-cube framing).

## Block 9 — Team shape

**[MIN] Q12.** How is the platform team shaped, and who owns the interfaces to users, sponsors, and providers?
- Probe: unowned interfaces fail silently (F9); a ticket-closing team is a cost center, not Platform, Inc. (F8).
- Unlocks: team/charter section; diamond-vs-pyramid framing.

---

## After the interview

1. If any **[MIN]** answer is missing, ask again — do not draft.
2. Route to models and anchor metaphor via `../references/decision-frames.md`.
3. Proceed to the matching outline: `strategy-doc-outline.md`, `presentation-outline.md`, or `brainstorm-worksheet.md`.
4. Sweep the draft against `../references/failure-modes.md` and the SKILL.md quality checklist before returning it.
