# Strategy Document Outline

Delivery blueprint for a platform strategy doc / vision / README / charter. Fill each section from the cited interview answers. Check each against the cited failure modes. This is filled by the agent *after* the interview — it is not a form handed to the user.

> Applies Hohpe's *Platform Strategy*. See SKILL.md → Source.

---

## 1. Vision (metaphor-anchored)

One sentence naming the platform's job, anchored on the chosen metaphor from `../references/metaphor-catalog.md`.
- Fill from: Q1, Q3.
- Check: F7 (no tool list here).

## 2. The bet — harmonization → innovation

State, in one sentence, how standardizing at your chosen layer *enables* innovation elsewhere. This is the platform paradox made concrete.
- Fill from: Q1b, Q5b.
- Check: F3 (a bet on freedom, not a straitjacket).

## 3. What kind of platform and its business-model role

Name what kind of platform this is and the business outcome it drives. If the user has the book, position it with the Fab Four; otherwise state it plainly (do not invent a typology).
- Fill from: Q1, Q1b.
- Check: F2 (a platform, not renamed services).

## 4. What we have opinions about / what we get out of the way on

Two explicit lists: strong opinions (paved road) and deliberate non-opinions, each opinion with its escape hatch.
- Fill from: Q4, Q5.
- Check: F3 (every opinion has an escape hatch or is honestly labeled a wall).

## 5. Quality commitments

The quality dimensions committed to, each stated as a promise plus its mechanism. If the user has the book, organize these with its 7 Cs; otherwise state the commitments plainly and cite the chapter (do not invent the seven C words — see references/mental-models.md).
- Fill from: Q4, Q8, Q10.
- Check: F6 (no promise without a mechanism).

## 6. What success looks like — user surprise

At least one concrete surprise a user could produce that would count as success.
- Fill from: Q3.
- Check: F1 (success is a user outcome, not a mandated usage number).

## 7. Non-goals

What this platform is explicitly *not* (not a shared library, not a ticket queue, not a compliance gate — as applicable).
- Fill from: Q6, Q6b.
- Check: F4 (kills the fruit-basket trap), F5 (no grim wrappers sneaking in).

## 8. Tenancy and how it's paid for

The tenancy model (selling / leasing / serviced apartments) and the funding mechanism.
- Fill from: Q10, Q7b.
- Check: F8 (Platform, Inc., not a cost center).

## 9. Adoption plan (not mandate)

Which users have adopted, which are next, the mechanism feeding them, and any tiering/slicing. (Adoption is not linear — don't promise a smooth ramp.)
- Fill from: Q7, Q11.
- Check: F1 (no reliance on mandate).

## 10. Roadmap (evolution cube)

Which dimension of growth is pushed this period and what's deliberately held. (Ask the user for the cube's dimensions rather than assuming them.)
- Fill from: Q11, Q11b.
- Check: F4 (growth stays coherent, not scattered).

## 11. Team shape

Diamond shape; named owners for user, sponsor, and provider interfaces.
- Fill from: Q12.
- Check: F9 (no unowned interfaces), F8 (product discipline).

## 12. Implementation appendix (optional)

Tools and tech go *here only*, in service of decisions the strategy already made.
- Check: F7 (tools never lead the document).

---

## Before returning

- Run the SKILL.md quality checklist (all ten).
- Sweep `../references/failure-modes.md` F1–F9.
- Confirm exactly one anchor metaphor carries the document.
- Add the one-line attribution: based on Gregor Hohpe, *Platform Strategy* — https://leanpub.com/platformstrategy.
