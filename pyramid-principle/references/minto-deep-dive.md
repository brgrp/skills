# Minto Deep Dive

Load this reference only when the SKILL.md essentials aren't enough — usually when you need to disambiguate a workflow step, when the user asks *why* the method works, or when a brainstorm surfaces no governing thought and you need to drop into problem-solving mode.

This file **extends** SKILL.md. It does not restate it. Read SKILL.md first.

---

## 1. Vertical and horizontal logic — the two rules working at once

### Vertical — question / answer dialogue

Every point raises a question in the reader's mind, and the level below must answer it. Only three questions ever appear:

- **Why?** — why is this true, why should I believe it
- **How?** — how do I do it, how does it work
- **So what?** — what does it mean, what should I do

If a point raises "Why?" and the layer below doesn't give reasons, the pyramid is broken. Fix the layer below or fix the parent.

### Horizontal — logic within a group

Points at the same level, under the same parent, relate by one of two structures:

- **Deductive** — points form a chain: premise 1, premise 2 (which comments on premise 1), therefore conclusion. Read in order.
- **Inductive** — points are members of the same logical class ("three reasons", "four risks", "five steps"). Any order, but the group needs a class noun.

**Inductive is almost always easier to read and easier to summarize. Use it as your default.** Reserve deductive for the moment you're actually forcing a conclusion from evidence.

---

## 2. Building the pyramid — two directions

### Top-down (preferred when the apex is clear)

1. Write the **Subject** of the document.
2. Write the **Question** the reader is asking.
3. Write your **Answer** — the governing thought, the apex.
4. Draft the **Situation** (uncontroversial context).
5. Draft the **Complication** (what changed).
6. Read S + C + Q + A aloud. If it flows, the intro is done.
7. Ask: "What question does the Answer provoke?" (Usually Why? or How?)
8. Answer with 2–4 key lines. That's your second level.
9. Repeat down.

### Bottom-up (used when the apex isn't yet clear — most brainstorms)

1. List every point.
2. Group by same-kind.
3. For each group, write a summary sentence that says something *new* — not "these are three reasons" but *what* the three reasons collectively mean.
4. Group the summary sentences. Repeat.
5. When you reach one sentence at the top, that's your governing thought.
6. Re-check the whole thing top-down.

Bottom-up is how Minto herself discovered the method — by editing McKinsey reports and repeatedly reorganizing scattered ideas into pyramid shape.

---

## 3. SCQA — storyline variants

The order S → C → Q → A is the **standard** form. Sometimes you'll want to reorder for effect. Three variants:

### Standard — S, C, Q, A
Neutral, informative. Best default. Use when the reader is unaware there's a problem.

> Since we launched pricing v2 in July, all new customers have signed under the tiered split. [S] Two months in, SMB is compounding but Enterprise pipeline has softened, and Q4 spend is locked next week. [C] Where should we concentrate Q4 growth spend? [Q] Double down on SMB and run a 4-week Enterprise diagnostic before adding Enterprise spend. [A]

### Direct — A, S, C, Q
Lead with the answer, then justify. Use when the reader is impatient, senior, or already worried.

> **Recommendation: double down on SMB in Q4, and diagnose Enterprise before spending there.** Pricing v2 has been in market for a full quarter. SMB is compounding; Enterprise pipeline has softened; Q4 spend is locked next week. The question is where to concentrate.

### Concern — C, S, Q, A
Lead with the tension. Use when the reader doesn't yet feel urgency.

> **Enterprise pipeline has softened just as Q4 spend is being locked.** Pricing v2 has been in market since July, and SMB is compounding under the new tiers. The question is where to concentrate. We recommend doubling down on SMB and running an Enterprise diagnostic before adding Enterprise spend.

### Choosing the variant

| Reader state | Variant |
|---|---|
| Neutral, informed | Standard (S-C-Q-A) |
| Senior, wants the ask fast | Direct (A-S-C-Q) |
| Not yet worried, needs to be | Concern (C-S-Q-A) |
| Skeptical or hostile | Standard, but expand C to make the tension undeniable |

### SCQA element pitfalls

| Failure | Fix |
|---|---|
| Situation is really a Complication | Ask: does the reader already agree? If not, it's a C. |
| Question is vague ("what should we do?") | Sharpen: "Where should we spend Q4?" |
| Answer is a topic ("Q4 strategy") | Rewrite as a claim: "We should double down on SMB." |
| No Complication at all | If nothing changed, there's no reason for the document. Cut it or find the real trigger. |
| Intro is longer than a page | S+C+Q+A fits in 3–5 sentences for a memo, one slide for a deck. |

---

## 4. MECE — how to actually test it

### Testing Mutual Exclusivity
For every pair of items, ask: **"Could a real example belong to both?"**
- Yes → the split is wrong. Merge, or find a sharper dimension.
- Different levels of detail → collapse to one.

**Bad split:** "Customers, Enterprise Customers, SMB Customers" — Enterprise and SMB are subsets of Customers.
**Good split:** "SMB Customers, Enterprise Customers" — parallel, non-overlapping.

### Testing Collective Exhaustiveness
Ask: **"What else could belong in this group?"** and **"If someone said 'you forgot X,' would X fit?"**
- Yes and X matters → add it.
- Yes but out of scope → say so explicitly.
- No possible X → exhaustive.

**Heuristic:** if you have a group of two, ask hard whether you're avoiding a messy third item.

---

## 5. The four orderings — worked

Once a group is MECE, items sit in one of exactly four orders. **You may only use one per group.**

### Deductive
Premise → premise-about-premise → conclusion. Read in sequence.

1. All Enterprise deals require CFO signoff. *(premise)*
2. Our current Enterprise pipeline has no CFO-signed deals. *(premise about premise)*
3. Therefore Enterprise pipeline is not real pipeline. *(conclusion)*

Use sparingly. Chains longer than 3 lose readers.

### Chronological
First, then, next, finally. Steps of a process, phases of a plan.

1. In July, we launched pricing v2.
2. In August, SMB conversion rose 18%.
3. In September, Enterprise pipeline dropped 30%.

Test: could you swap any two? If yes, it's not really chronological.

### Structural
Parts of a whole. Reader mentally reassembles the whole.

Bases: Geography (N/S/E/W), Function (Sales/Marketing/Product/Engineering), Organization (Team A/B/C), Product surface (Web/Mobile/API), Component (Frontend/Backend/Database).

Test: is there a single whole the parts add up to? Are they non-overlapping?

### Degree of importance
Most → least. Use when the reader needs to prioritize.

1. Enterprise pipeline is soft — biggest strategic risk.
2. Two AEs are still ramping — smaller near-term risk.
3. Slack integration is delayed — minor.

Test: could you defend the order in a room? If someone argues "no, #2 is bigger" and you can't answer, revisit.

**The wrong "ordering":** arrival order — the order the writer happened to think of the items. Not an ordering. Fix before delivering.

---

## 6. Worked example — MECE + ordering

### Before (fails MECE, no ordering)

"Q3 was strong overall. Revenue was up. Enterprise churn was flat. SMB churn dropped. We launched pricing v2. NPS went up in SMB. Slack integration delayed. We hired two AEs. SMB conversion is up."

Problems: revenue-up overlaps with SMB-conversion-up. Findings, actions, and program updates are mixed. No ordering.

### After (MECE + degree-ordering)

**Governing thought:** SMB is compounding under pricing v2 and should absorb Q4 investment; Enterprise needs a separate diagnostic.

**Key line 1 — SMB metrics are compounding** *(most important — drives the recommendation)*
- SMB churn down 4pts
- SMB conversion up 18%
- SMB NPS up 8pts

**Key line 2 — Enterprise signal is ambiguous** *(second — reason for the diagnostic)*
- Enterprise pipeline down 30%
- Enterprise churn flat (not deteriorating)
- Two Enterprise AEs still in ramp

**Key line 3 — Program updates** *(third — housekeeping)*
- Pricing v2 launched July
- Slack integration delayed to Q4

Each key line is MECE within itself; the three are MECE with each other; whole thing is in degree order.

---

## 7. Common pyramid failures and fixes

| Failure | Symptom | Fix |
|---|---|---|
| Fake grouping | "Three things to consider" but they don't share a class | Find the real class or split into different groups |
| Overlap | Point 2 partly restates point 1 | Merge, or find the sharper distinction |
| Missing member | "Three risks" but an obvious fourth is unaddressed | Add it, or explicitly scope out |
| Wrong ordering | Points feel arbitrary | Pick one of the four orderings and enforce it |
| Buried lede | Reader has to search for the answer | Move governing thought to sentence 1, paragraph 1 |
| Topic headers | Slide titles are noun phrases ("Q3 Results") | Rewrite as full-sentence points ("Q3 results validate pricing in SMB") |
| Parent not a summary | Header says one thing, bullets say another | Rewrite the parent to actually summarize the children |
| Level skip | Sub-points don't answer the question raised by the parent | Insert an intermediate level, or restate the parent |
| Mixed kinds | Some items are findings, others are recommendations | Split into two groups — findings and recommendations belong at different levels |

---

## 8. Why the pyramid works — cognitive rationale

The reader is trying to figure out what you think. The pyramid respects three facts about how minds work:

1. **The mind imposes structure.** If you don't provide one, it invents one — wrong.
2. **The mind holds ~4 items at once.** Groupings of 2–4 with a summary above are optimal; longer flat lists lose the reader.
3. **The mind asks "so what?" after every new claim.** Answering the implicit question at each step keeps the reader hooked.

The pyramid isn't a stylistic preference. It's a match to how comprehension actually works.

---

## 9. When *not* to use the pyramid

- **Fiction / narrative writing** where suspense is the point.
- **Poetry / marketing headlines** where compression and emotion outrank logic.
- **Exploratory research notes** meant only for yourself — imposing structure too early cuts off discovery. Brainstorm freely, then run the bottom-up workflow before showing anyone.

---

## 10. Problem-solving mode — when the apex doesn't exist yet

The Pyramid Principle has two halves. The one above is about **communicating an answer you already have.** This section is about **deriving the answer.** Drop into this mode when a brainstorm (Workflow C) surfaces no clear governing thought, or the user brings a *problem*, not a claim.

### Define the problem (four elements)

1. **Starting point:** the situation right now, neutral.
2. **Disturbing event:** what happened / is happening that makes this a problem.
3. **R1 — Current result:** the undesirable outcome today.
4. **R2 — Desired result:** the outcome you want.

**Question** = "How do we get from R1 to R2?"

If you can't fill all four, you don't have a problem — you have a topic.

### Structure the analysis (before doing it)

Do not open a spreadsheet. First, build a **logic tree**: break the question into MECE sub-questions, then break each into MECE sub-questions, until you reach questions data can answer.

Example root: "How should we reallocate Q4 spend?"
- What is SMB worth if we double down?
- What is Enterprise worth if we hold?
- What is Enterprise worth if we diagnose-and-fix?

Now you know exactly what to analyze — no wasted work.

For decisions ("should we do X?"), structure as an **issue tree**: X is worth doing IF (a) AND (b) AND (c). Test each condition.

### Derive the governing thought
The governing thought answers the Question. It emerges from the analysis:
- Analysis supports one branch strongly → governing thought = that branch's conclusion.
- Mixed → "Recommend X, with fallback Y if condition Z holds."
- Inconclusive → "Cannot yet decide between X and Y; run a diagnostic to decide."

**The governing thought is a claim, not a summary of analysis.** "Analysis showed SMB is compounding" is not a governing thought. "Double down on SMB" is.

### Rebuild the pyramid top-down
Now run the standard top-down workflow. **The logic tree becomes the pyramid** — that's why structuring the analysis in advance pays off.

### Problem-solving failures

| Failure | Symptom | Fix |
|---|---|---|
| Skipping the problem definition | Analysis produces facts, not answers | Write R1 and R2 explicitly |
| Analysis without a tree | Weeks of work, no clear conclusion | Build the tree first; only analyze branches that could change the answer |
| Governing thought is a summary, not a claim | "Our analysis found several factors..." | Rewrite as imperative: "We should X because Y" |
| Tree branches aren't MECE | Two branches produce the same conclusion | Redraw with genuinely different sub-questions |
| Recommendation doesn't move R1 to R2 | Reader asks "does this actually solve the problem?" | Trace back to the R1/R2 gap — if it doesn't close, it's wrong |
