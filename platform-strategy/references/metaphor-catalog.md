# Metaphor Catalog

The anchor metaphors from Gregor Hohpe's *Platform Strategy: Innovation Through Harmonization*, keyed to the book's chapter titles. Pick **one** as the anchor for any artifact (one metaphor domain per session). Each entry gives what the metaphor claims, the tension it carries (a good metaphor shows advantage *and* disadvantage), when to reach for it, when not to, and adjacent moves for when the audience runs past the finish line with it.

> **Provenance rule.** The metaphor *names* and their one-line subtitles come from the book's public table of contents. The "claims / tension / when / adjacent" notes are this skill's working interpretation to help an agent apply them — they are not verbatim book content and may not capture the chapter's full argument. Where a note is a reading rather than an established fact, it is marked *(interpretation — verify against the book)*. Never present these notes to a user as direct quotes from Hohpe. See SKILL.md → Source.

---

## 1. Standing on the shoulders of giants (but is the air just thinner?)

- **Chapter subtitle (from TOC):** "Do you really see further or is the air just thinner?" (Part I, Understanding Platforms)
- **Claims:** Building on top of what others built promises leverage — but height can mean thinner air rather than a better view. Reuse carries a cost.
- **Tension:** Leverage from standing higher vs. distance and dependency cost. *(interpretation — verify against the book)*
- **When to reach for it:** Questioning a "just build on top of X" assumption. *(interpretation)*
- **When not to:** As a closing emotional anchor.
- **Adjacent moves:** Ask what you can no longer see from up here, and whether the climb was worth the view.

## 2. The Fab Four of Technology Platforms

- **Chapter subtitle (from TOC):** "Technology drives business models." (Part I, Understanding Platforms)
- **Claims:** The book uses a "Fab Four" of technology platforms to show how technology drives business models. **This skill does not have the four members or the book's full argument.** Do not invent them.
- **How to use it:** If the user has the book, apply the actual Fab Four here. Otherwise, cite the chapter and treat platform-type/business-model framing as a gap to fill from the book — do **not** fabricate a typology.
- **When not to:** As an emotional anchor in a pitch; it is a conceptual chapter.
- **Provenance:** Members and definition unverified. Consult the book.

## 3. The platform paradox

- **Claims:** Standardization is assumed to stifle innovation, yet HTTP — a rigid standard — became one of the biggest innovation drivers in IT history. Done right, harmonization *enables* innovation.
- **Tension:** Constraint vs. freedom; the paradox only resolves if the standard is at the right layer.
- **When to reach for it:** The core of almost every executive pitch — this is the "innovation through harmonization" claim itself.
- **When not to:** When the standard proposed is actually restrictive (see #6). Don't invoke the paradox to excuse a straitjacket.
- **Adjacent moves:** Audiences love naming their own HTTP-like standard. Let them find the layer where harmonizing buys the most downstream freedom.

## 4. IT platform and IT services are antonyms

- **Claims:** Renaming a shared-services team "platform team" changes nothing. Platforms and services are opposites in how they're designed and consumed: self-service and opinionated vs. request-and-fulfill.
- **Tension:** Familiar operating model (services) vs. the harder-to-build but higher-leverage platform model.
- **When to reach for it:** When a "platform" is really a ticket queue; when a team drowns in requests.
- **When not to:** When the org genuinely needs a services function and calling it a platform would over-promise.
- **Adjacent moves:** Ask what would have to change for a request to become a self-service interaction — that gap is the platform work.

## 5. Mechanisms, not magic

- **Claims:** Making things work is not an implementation detail. Every platform promise must be backed by a concrete mechanism, not hand-waving.
- **Tension:** The appeal of "it just works" vs. the honesty of showing how.
- **When to reach for it:** CFO/CTO pitches; any claim that sounds too good; killing the illusion trap.
- **When not to:** Rarely misfires — but don't drown a non-technical audience in mechanism detail; name the mechanism, don't dump it.
- **Adjacent moves:** For each promised outcome, name the mechanism and its failure behavior. This pairs naturally with #11 and #12.

## 6. Opinionated vs. restrictive (a mind of your own)

- **Claims:** Users love opinionated platforms (clear defaults, a paved road) and despise restrictive ones (no escape hatch). The line between them is whether the user can still get their job done off the road.
- **Tension:** Guidance vs. imprisonment; the same feature reads as either depending on the escape hatch.
- **When to reach for it:** Adoption problems; designing golden paths; declaring the platform's stance.
- **When not to:** When there genuinely is a hard compliance boundary — be honest that it's a wall, not a preference.
- **Adjacent moves:** For each opinion, ask "what's the escape hatch?" No escape hatch = restrictive. Audiences quickly self-diagnose here.

## 7. Fruit salad or fruit basket?

- **Claims:** A good platform is more than a collection of services. A fruit basket is independently useful items in one container; a fruit salad is a coherent whole where the combination is the value.
- **Tension:** Coherence (salad) risks over-mixing and losing the ingredients; collection (basket) risks having no platform at all, just a shared shelf.
- **When to reach for it:** Scoping; when the "platform" is suspiciously a list of unrelated tools.
- **When not to:** When the honest answer *is* a curated basket and pretending otherwise would over-engineer.
- **Adjacent moves:** Ask what dressing turns these fruits into a salad — i.e., what integrating opinion makes the combination worth more than the parts.

## 8. Cantilevered platforms

- **Chapter subtitle (from TOC):** "Horizontal platforms sit on vertical pillars." (Part IV, Designing Platforms)
- **Claims:** A horizontal platform rests on vertical pillars; it extends only as far as its support allows.
- **Tension:** Reach of the horizontal layer vs. strength of the vertical supports. *(interpretation — verify against the book)*
- **When to reach for it:** When a horizontal platform over-extends past what supports it. *(interpretation)*
- **When not to:** Early vision pitches — a structural metaphor, better for architects than a CFO.
- **Adjacent moves:** Ask which pillar each horizontal promise rests on.

## 9. Will your platform float or sink?

- **Claims:** Most people want to swim — until they realize their cost is sunk. A platform whose economics only work under mandate is already sinking; a floating platform earns its adoption.
- **Tension:** The comfort of mandate (guaranteed users) vs. the truth it hides (no real value pull).
- **When to reach for it:** Adoption strategy; any plan that leans on "leadership will require it."
- **When not to:** When there's a legitimate regulatory reason for mandate — don't imply mandate is always failure.
- **Adjacent moves:** Ask what teams would use it *without* the mandate. If none, the buoyancy problem is real, not a marketing problem.

## 10. Beware the grim wrapper!

- **Claims:** What starts well doesn't always end well. Wrapping an underlying system to "simplify" it often becomes a thin, brittle, ever-growing layer that inherits all the complexity plus its own.
- **Tension:** The appeal of a clean facade vs. the maintenance debt of tracking everything underneath.
- **When to reach for it:** When a team proposes wrapping a vendor API or cloud service "to make it easier"; deciding what to stop doing.
- **When not to:** When a thin adapter genuinely is the right, bounded choice — not every wrapper is grim.
- **Adjacent moves:** Ask what happens to the wrapper when the thing underneath changes. If the answer is "we chase it forever," it's grim.

## 11. Build abstractions, not illusions

- **Claims:** A good abstraction hides complexity you never need to see. An illusion hides complexity that *will* surface — and breaks trust when it does. Sometimes less is actually less.
- **Tension:** Simplicity for the user vs. honesty about what can't truly be hidden.
- **When to reach for it:** Designing the platform interface; deciding how much to hide.
- **When not to:** When over-caution would prevent a genuinely clean abstraction — don't use it to justify leaking everything.
- **Adjacent moves:** Pairs with #12. For each thing hidden, ask "what happens when reality doesn't cooperate?" If the user is stranded, it's an illusion.

## 12. Failure doesn't respect abstraction

- **Claims:** Abstractions hold until something fails; then the user gets a stack trace from three layers down. Time to enjoy a good stack trace.
- **Tension:** Clean happy-path abstraction vs. the leaky reality of failure modes.
- **When to reach for it:** Reliability and support planning; setting user expectations; designing observability.
- **When not to:** In an aspirational vision slide — this is a sobering, operational metaphor.
- **Adjacent moves:** Ask, for each abstraction, what the user sees when it fails, and whether the platform helps them or abandons them at that moment.

## 13. Platforms are the instruction sheets for Lego blocks

- **Claims:** A platform's anatomy is less about the blocks and more about the instructions that tell you how they combine. The value is in the composability guidance.
- **Tension:** Freedom to build anything vs. the guidance that makes building actually feasible.
- **When to reach for it:** Explaining platform anatomy; distinguishing raw components from a platform.
- **When not to:** When the audience needs the buoyancy or adoption argument, not the anatomy.
- **Adjacent moves:** Ask what the instruction sheet forbids and what it leaves open — that's the opinionated/restrictive line (#6) drawn in Lego.

## 14. Selling, leasing, or serviced apartments? (ownership and tenancy)

- **Chapter subtitle (from TOC):** "Are you selling, leasing, or providing serviced apartments?" (Part V, Implementing Platforms — Ownership and Tenancy)
- **Claims:** How you provide the platform to tenants defines your obligations, along a spectrum from selling (they own and maintain) to serviced apartments (you run the building, they keep the keys).
- **Tension:** Tenant autonomy vs. provider responsibility — more service means more obligation. *(interpretation — verify against the book)*
- **When to reach for it:** Defining the operating model and support boundaries. *(interpretation)*
- **When not to:** In a first vision pitch — it is an operating-model decision.
- **Adjacent moves:** Ask who is responsible when something breaks; that reveals which tenancy model you have actually chosen.

## 15. Platform evolution is a cube

- **Chapter subtitle (from TOC):** "Platforms may be flat, but their path isn't." (Part VI, Growing Platforms)
- **Claims:** A platform's growth path is multi-dimensional, not linear. **The specific axes of the cube are the book's; this skill does not assert them.**
- **Tension:** The pull to grow in every direction vs. the need to choose. *(interpretation — verify against the book)*
- **When to reach for it:** Roadmap narrative; explaining why growth feels multi-directional.
- **When not to:** Simple early-stage pitches.
- **Adjacent moves:** Ask what you are deliberately *not* growing yet — pairs with tiering and slicing (see mental-models.md). Consult the book for the cube's actual dimensions.

## 16. Diamonds vs. pyramids (team shape)

- **Chapter subtitle (from TOC):** "Pyramids last 5000 years, but diamonds are forever." (Part VII, Organizing for Platforms — Platform Teams Without Platform)
- **Claims:** Platform teams should be shaped like diamonds, not pyramids, and need real interfaces (facades) to the parties around them. **The precise geometry the book intends is not asserted here.**
- **Tension:** The simplicity of a hierarchy vs. the multi-sided interface work a platform team requires. *(interpretation — verify against the book)*
- **When to reach for it:** Organizing the platform team. *(interpretation)*
- **When not to:** When the audience cares about the product, not the org.
- **Adjacent moves:** Ask who owns each interface to the surrounding parties. Unowned interfaces are where a platform team silently fails. Consult the book for what "diamond" specifically means.

---

## Choosing among them

To match a user's question to an anchor metaphor and supporting models, use the single routing index in `decision-frames.md`. This catalog is the *content*; decision-frames is the *router*. (Kept separate on purpose: one place to look up "which metaphor when.")

If none fits cleanly, you may author a new metaphor — but it must pass the mirror test the book applies: it carries genuine tension (both sides), it translates the problem into the audience's domain, and you fully stand behind it. A one-sided or decorative metaphor is worse than none.
