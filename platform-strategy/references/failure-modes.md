# Failure Modes

The ways platform strategies fail, per Hohpe's *Platform Strategy*. Sweep every draft against this list before delivery. Each entry: the smell, the underlying failure, and the corrective move.

> Condenses ideas from Hohpe's book. See SKILL.md → Source.

---

## F1. Mandated adoption

- **Smell:** "Adoption will be driven by leadership mandate." Usage numbers exist only because teams have no choice.
- **Underlying failure:** The platform provides no real value pull; the mandate hides that it's sinking (metaphor #9).
- **Corrective move:** Name teams that would use it *without* the mandate. If none, fix value before rollout. Replace mandate with mechanisms (tiers, paved roads, migration help).

## F2. Common-services-layer in disguise

- **Smell:** A collection of shared services renamed "platform"; interactions are still request-and-fulfill.
- **Underlying failure:** Platform and services are antonyms (model: IT platform vs. services). Renaming changed nothing.
- **Corrective move:** Identify which interactions must become self-service and opinionated. If none can, be honest that it's a services function.

## F3. Restrictive, not opinionated

- **Smell:** Strong defaults with no escape hatch; teams route around the platform.
- **Underlying failure:** Users love opinionated, despise restrictive (metaphor #6). No escape hatch = a wall.
- **Corrective move:** For each opinion, define the escape hatch. If a boundary must be hard (compliance), label it a wall honestly, don't dress it as a preference.

## F4. Fruit basket, not salad

- **Smell:** The platform is a list of independently useful but unrelated tools in one container.
- **Underlying failure:** No coherent whole; the combination adds nothing over the parts (metaphor #7).
- **Corrective move:** Name the integrating opinion — the "dressing" — that makes the combination worth more than the sum. If there isn't one, cut scope until there is.

## F5. The grim wrapper

- **Smell:** A thin layer wrapping a vendor/cloud API "to simplify," growing to chase every underlying change.
- **Underlying failure:** The wrapper inherits all underlying complexity plus its own maintenance debt (metaphor #10).
- **Corrective move:** Ask what happens to the wrapper when the thing underneath changes. If the answer is "chase it forever," don't wrap — expose or adapt narrowly.

## F6. Illusion abstractions

- **Smell:** "The platform handles X" with no account of what happens when X fails.
- **Underlying failure:** Complexity that will surface has been hidden; trust breaks on first failure (metaphors #11, #12).
- **Corrective move:** For each hidden thing, state the failure behavior and whether the platform helps the user at that moment. If it strands them, it's an illusion — redesign or expose it honestly.

## F7. Tool inventory posing as strategy

- **Smell:** The strategy opens with a tool list (Backstage, ArgoCD, Vault, Prometheus) and stops there.
- **Underlying failure:** Tools are means, not the strategy. No decision, paradox, or value claim is made.
- **Corrective move:** Move tools to an implementation appendix. Lead with the harmonization → innovation claim and the user-surprise test. Tools reappear only in service of a decision already made.

## F8. Platform team as ticket queue

- **Smell:** The team measures success by tickets closed; users request, the team fulfills.
- **Underlying failure:** No product discipline; the team is a cost center, not Platform, Inc.
- **Corrective move:** Reframe around customers, a product, and outcomes. Convert recurring tickets into self-service capabilities. Adopt the multi-sided/customer-centric stance.

## F9. Pyramid team with unowned interfaces

- **Smell:** A hierarchical team with no named owners for user, sponsor, or provider interfaces.
- **Underlying failure:** Platform teams are multi-sided; unowned interfaces fail silently (metaphor #16).
- **Corrective move:** Adopt a diamond shape. Name an owner for each interface (users, sponsors, providers). Add product and provider-facing roles, not just engineers.

---

## Sweep procedure

Before returning any artifact:

1. Read each smell against the draft.
2. For every match, apply the corrective move and revise.
3. Cross-check with the SKILL.md quality checklist — the ten checklist items map onto these failure modes; a checklist "no" usually points to one of F1–F9.
4. If a failure mode can't be corrected because the underlying platform is genuinely flawed, say so plainly in the artifact rather than papering over it. Honesty is the book's stance.
