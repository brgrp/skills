# The Complete Guide to Building Skills for Claude

> **Source:** [Anthropic Official Guide (PDF)](https://resources.anthropic.com/hubfs/The-Complete-Guide-to-Building-Skill-for-Claude.pdf)

---

## Table of Contents

1. [Introduction](#introduction)
2. [Fundamentals](#chapter-1-fundamentals)
3. [Planning and Design](#chapter-2-planning-and-design)
4. [Testing and Iteration](#chapter-3-testing-and-iteration)
5. [Distribution and Sharing](#chapter-4-distribution-and-sharing)
6. [Patterns and Troubleshooting](#chapter-5-patterns-and-troubleshooting)
7. [Resources and References](#chapter-6-resources-and-references)
8. [Appendices](#appendices)
   - [Quick Checklist](#reference-a-quick-checklist)
   - [YAML Frontmatter](#reference-b-yaml-frontmatter)
   - [Complete Skill Examples](#reference-c-complete-skill-examples)

---

## Introduction

A **skill** is a set of instructions—packaged as a simple folder—that teaches Claude how to handle specific tasks or workflows. Skills are one of the most powerful ways to customize Claude for your specific needs. Instead of re-explaining your preferences, processes, and domain expertise in every conversation, skills let you teach Claude once and benefit every time.

Skills are powerful when you have repeatable workflows:
- Generating frontend designs from specs
- Conducting research with consistent methodology
- Creating documents that follow your team's style guide
- Orchestrating multi-step processes

They work well with Claude's built-in capabilities like code execution and document creation. For those building MCP integrations, skills add another powerful layer—helping turn raw tool access into reliable, optimized workflows.

### What You'll Learn

- Technical requirements and best practices for skill structure
- Patterns for standalone skills and MCP-enhanced workflows
- Patterns we've seen work well across different use cases
- How to test, iterate, and distribute your skills

### Who This Is For

- **Developers** who want Claude to follow specific workflows consistently
- **Power users** who want Claude to follow specific workflows
- **Teams** looking to standardize how Claude works across their organization

### Two Paths Through This Guide

| Path | Focus Areas |
|------|-------------|
| **Building standalone skills** | Fundamentals, Planning and Design, Categories 1-2 |
| **Enhancing an MCP integration** | "Skills + MCP" section, Category 3 |

Both paths share the same technical requirements—choose what's relevant to your use case.

> **Time Investment:** Expect about 15-30 minutes to build and test your first working skill using the skill-creator.

---

## Chapter 1: Fundamentals

### What Is a Skill?

A skill is a folder containing:

| File/Folder | Required | Purpose |
|-------------|----------|---------|
| `SKILL.md` | ✅ Yes | Instructions in Markdown with YAML frontmatter |
| `scripts/` | Optional | Executable code (Python, Bash, etc.) |
| `references/` | Optional | Documentation loaded as needed |
| `assets/` | Optional | Templates, fonts, icons used in output |

### Core Design Principles

#### Progressive Disclosure

Skills use a three-level system:

| Level | Location | When Loaded | Purpose |
|-------|----------|-------------|---------|
| **First** | YAML frontmatter | Always (in system prompt) | Helps Claude know when to use each skill |
| **Second** | SKILL.md body | When skill is relevant | Contains full instructions and guidance |
| **Third** | Linked files | On demand | Additional files Claude discovers as needed |

This progressive disclosure minimizes token usage while maintaining specialized expertise.

#### Composability

Claude can load multiple skills simultaneously. Your skill should work well alongside others—don't assume it's the only capability available.

#### Portability

Skills work identically across Claude.ai, Claude Code, and API. Create a skill once and it works across all surfaces without modification, provided the environment supports any dependencies the skill requires.

### Skills + MCP Connectors

> 💡 **Building standalone skills without MCP?** Skip to [Planning and Design](#chapter-2-planning-and-design)—you can always return here later.

If you already have a working MCP server, you've done the hard part. Skills are the knowledge layer on top—capturing the workflows and best practices you already know, so Claude can apply them consistently.

#### The Kitchen Analogy

| Component | Analogy |
|-----------|---------|
| **MCP** | The professional kitchen: access to tools, ingredients, and equipment |
| **Skills** | The recipes: step-by-step instructions on how to create something valuable |

Together, they enable users to accomplish complex tasks without needing to figure out every step themselves.

#### How They Work Together

| MCP (Connectivity) | Skills (Knowledge) |
|-------------------|-------------------|
| Connects Claude to your service (Notion, Asana, Linear, etc.) | Teaches Claude how to use your service effectively |
| Provides real-time data access and tool invocation | Captures workflows and best practices |
| **What** Claude can do | **How** Claude should do it |

#### Why This Matters for Your MCP Users

**Without skills:**
- Users connect your MCP but don't know what to do next
- Support tickets asking "how do I do X with your integration"
- Each conversation starts from scratch
- Inconsistent results because users prompt differently each time
- Users blame your connector when the real issue is workflow guidance

**With skills:**
- Pre-built workflows activate automatically when needed
- Consistent, reliable tool usage
- Best practices embedded in every interaction
- Lower learning curve for your integration

---

## Chapter 2: Planning and Design

### Start with Use Cases

Before writing any code, identify 2-3 concrete use cases your skill should enable.

#### Good Use Case Definition

```
Use Case: Project Sprint Planning

Trigger: User says "help me plan this sprint" or "create sprint tasks"

Steps:
1. Fetch current project status from Linear (via MCP)
2. Analyze team velocity and capacity
3. Suggest task prioritization
4. Create tasks in Linear with proper labels and estimates

Result: Fully planned sprint with tasks created
```

#### Questions to Ask Yourself

- What does a user want to accomplish?
- What multi-step workflows does this require?
- Which tools are needed (built-in or MCP)?
- What domain knowledge or best practices should be embedded?

### Common Skill Use Case Categories

#### Category 1: Document & Asset Creation

**Used for:** Creating consistent, high-quality output including documents, presentations, apps, designs, code, etc.

**Real example:** `frontend-design` skill (also see skills for docx, pptx, xlsx, and ppt)

> "Create distinctive, production-grade frontend interfaces with high design quality. Use when building web components, pages, artifacts, posters, or applications."

**Key techniques:**
- Embedded style guides and brand standards
- Template structures for consistent output
- Quality checklists before finalizing
- No external tools required—uses Claude's built-in capabilities

#### Category 2: Workflow Automation

**Used for:** Multi-step processes that benefit from consistent methodology, including coordination across multiple MCP servers.

**Real example:** `skill-creator` skill

> "Interactive guide for creating new skills. Walks the user through use case definition, frontmatter generation, instruction writing, and validation."

**Key techniques:**
- Step-by-step workflow with validation gates
- Templates for common structures
- Built-in review and improvement suggestions
- Iterative refinement loops

#### Category 3: MCP Enhancement

**Used for:** Workflow guidance to enhance the tool access an MCP server provides.

**Real example:** `sentry-code-review` skill (from Sentry)

> "Automatically analyzes and fixes detected bugs in GitHub Pull Requests using Sentry's error monitoring data via their MCP server."

**Key techniques:**
- Coordinates multiple MCP calls in sequence
- Embeds domain expertise
- Provides context users would otherwise need to specify
- Error handling for common MCP issues

### Define Success Criteria

How will you know your skill is working? These are aspirational targets—rough benchmarks rather than precise thresholds.

#### Quantitative Metrics

| Metric | Target | How to Measure |
|--------|--------|----------------|
| Skill triggers on relevant queries | ~90% | Run 10-20 test queries that should trigger your skill. Track automatic loads vs. explicit invocations. |
| Completes workflow in X tool calls | Varies | Compare the same task with and without the skill. Count tool calls and total tokens. |
| Failed API calls per workflow | 0 | Monitor MCP server logs during test runs. Track retry rates and error codes. |

#### Qualitative Metrics

| Metric | How to Assess |
|--------|---------------|
| Users don't need to prompt about next steps | During testing, note how often you need to redirect or clarify. Ask beta users for feedback. |
| Workflows complete without user correction | Run the same request 3-5 times. Compare outputs for structural consistency and quality. |
| Consistent results across sessions | Can a new user accomplish the task on first try with minimal guidance? |

### Technical Requirements

#### File Structure

```
your-skill-name/
├── SKILL.md                    # Required - main skill file
├── scripts/                    # Optional - executable code
│   ├── process_data.py
│   └── validate.sh
├── references/                 # Optional - documentation
│   ├── api-guide.md
│   └── examples/
└── assets/                     # Optional - templates, etc.
    └── report-template.md
```

#### Critical Rules

| Rule | Details |
|------|---------|
| **SKILL.md naming** | Must be exactly `SKILL.md` (case-sensitive). No variations like `SKILL.MD` or `skill.md`. |
| **Folder naming** | Use kebab-case: `notion-project-setup` ✅ <br> No spaces: `Notion Project Setup` ❌ <br> No underscores: `notion_project_setup` ❌ <br> No capitals: `NotionProjectSetup` ❌ |
| **No README.md** | Don't include README.md inside your skill folder. All documentation goes in SKILL.md or `references/`. (Repo-level README is fine for distribution.) |

### YAML Frontmatter

The YAML frontmatter is how Claude decides whether to load your skill. **Get this right.**

#### Minimal Required Format

```yaml
---
name: your-skill-name
description: What it does. Use when user asks to [specific phrases].
---
```

That's all you need to start.

#### Field Requirements

| Field | Required | Rules |
|-------|----------|-------|
| `name` | ✅ Yes | kebab-case only, no spaces or capitals, should match folder name |
| `description` | ✅ Yes | Must include BOTH what it does AND when to use it (trigger conditions). Under 1024 characters. No XML tags (`<` or `>`). Include specific tasks users might say. Mention file types if relevant. |
| `license` | Optional | Use if making skill open source. Common: MIT, Apache-2.0 |
| `compatibility` | Optional | 1-500 characters. Environment requirements: intended product, required system packages, network access needs, etc. |
| `metadata` | Optional | Any custom key-value pairs. Suggested: author, version, mcp-server |

**Metadata example:**
```yaml
metadata:
  author: ProjectHub
  version: 1.0.0
  mcp-server: projecthub
```

#### Security Restrictions

**Forbidden in frontmatter:**
- XML angle brackets (`<` `>`)
- Skills with "claude" or "anthropic" in name (reserved)

**Why:** Frontmatter appears in Claude's system prompt. Malicious content could inject instructions.

### Writing Effective Skills

#### The Description Field

> "This metadata...provides just enough information for Claude to know when each skill should be used without loading all of it into context."
> — Anthropic Engineering Blog

**Structure:**
```
[What it does] + [When to use it] + [Key capabilities]
```

**Good descriptions:**

```yaml
# Specific and actionable
description: Analyzes Figma design files and generates developer handoff 
  documentation. Use when user uploads .fig files, asks for "design specs", 
  "component documentation", or "design-to-code handoff".

# Includes trigger phrases
description: Manages Linear project workflows including sprint planning, 
  task creation, and status tracking. Use when user mentions "sprint", 
  "Linear tasks", "project planning", or asks to "create tickets".

# Clear value proposition
description: End-to-end customer onboarding workflow for PayFlow. Handles 
  account creation, payment setup, and subscription management. Use when 
  user says "onboard new customer", "set up subscription", or "create 
  PayFlow account".
```

**Bad descriptions:**

```yaml
# Too vague
description: Helps with projects.

# Missing triggers
description: Creates sophisticated multi-page documentation systems.

# Too technical, no user triggers
description: Implements the Project entity model with hierarchical relationships.
```

#### Writing the Main Instructions

After the frontmatter, write the actual instructions in Markdown.

**Recommended template:**

```markdown
---
name: your-skill
description: [...]
---

# Your Skill Name

## Instructions

### Step 1: [First Major Step]

Clear explanation of what happens.

**Example:**
```bash
python scripts/fetch_data.py --project-id PROJECT_ID
```

**Expected output:** [describe what success looks like]

### Step 2: [Next Step]

(Add more steps as needed)

## Examples

### Example 1: [Common Scenario]

**User says:** "Set up a new marketing campaign"

**Actions:**
1. Fetch existing campaigns via MCP
2. Create new campaign with provided parameters

**Result:** Campaign created with confirmation link

(Add more examples as needed)

## Troubleshooting

### Error: [Common error message]

**Cause:** [Why it happens]

**Solution:** [How to fix]

(Add more error cases as needed)
```

#### Best Practices for Instructions

**Be Specific and Actionable**

✅ Good:
```markdown
Run `python scripts/validate.py --input {filename}` to check data format.

If validation fails, common issues include:
- Missing required fields (add them to the CSV)
- Invalid date formats (use YYYY-MM-DD)
```

❌ Bad:
```markdown
Validate the data before proceeding.
```

**Include Error Handling**

```markdown
## Common Issues

### MCP Connection Failed

If you see "Connection refused":

1. Verify MCP server is running: Check Settings > Extensions
2. Confirm API key is valid
3. Try reconnecting: Settings > Extensions > [Your Service] > Reconnect
```

**Reference Bundled Resources Clearly**

```markdown
Before writing queries, consult `references/api-patterns.md` for:
- Rate limiting guidance
- Pagination patterns
- Error codes and handling
```

**Use Progressive Disclosure**

Keep SKILL.md focused on core instructions. Move detailed documentation to `references/` and link to it.

---

## Chapter 3: Testing and Iteration

Skills can be tested at varying levels of rigor depending on your needs:

| Approach | Description | Best For |
|----------|-------------|----------|
| **Manual testing in Claude.ai** | Run queries directly and observe behavior | Fast iteration, no setup required |
| **Scripted testing in Claude Code** | Automate test cases for repeatable validation | Validation across changes |
| **Programmatic testing via Skills API** | Build evaluation suites that run systematically | Quality requirements at scale |

Choose the approach that matches your quality requirements and the visibility of your skill.

> 💡 **Pro Tip:** Iterate on a single task before expanding
>
> The most effective skill creators iterate on a single challenging task until Claude succeeds, then extract the winning approach into a skill. This leverages Claude's in-context learning and provides faster signal than broad testing.

### Recommended Testing Approach

#### 1. Triggering Tests

**Goal:** Ensure your skill loads at the right times.

**Test cases:**
- ✅ Triggers on obvious tasks
- ✅ Triggers on paraphrased requests
- ❌ Doesn't trigger on unrelated topics

**Example test suite:**

```
Should trigger:
- "Help me set up a new ProjectHub workspace"
- "I need to create a project in ProjectHub"
- "Initialize a ProjectHub project for Q4 planning"

Should NOT trigger:
- "What's the weather in San Francisco?"
- "Help me write Python code"
- "Create a spreadsheet" (unless skill handles sheets)
```

#### 2. Functional Tests

**Goal:** Verify the skill produces correct outputs.

**Test cases:**
- Valid outputs generated
- API calls succeed
- Error handling works
- Edge cases covered

**Example:**

```
Test: Create project with 5 tasks

Given: Project name "Q4 Planning", 5 task descriptions

When: Skill executes workflow

Then:
- Project created in ProjectHub
- 5 tasks created with correct properties
- All tasks linked to project
- No API errors
```

#### 3. Performance Comparison

**Goal:** Prove the skill improves results vs. baseline.

**Baseline comparison:**

| Metric | Without Skill | With Skill |
|--------|---------------|------------|
| User provides instructions | Each time | Automatic |
| Back-and-forth messages | 15 | 2 (clarifying only) |
| Failed API calls | 3 | 0 |
| Tokens consumed | 12,000 | 6,000 |

### Using the skill-creator Skill

The `skill-creator` skill—available in Claude.ai via plugin directory or download for Claude Code—can help you build and iterate on skills.

**Capabilities:**

| Feature | Description |
|---------|-------------|
| **Creating skills** | Generate skills from natural language descriptions, produce properly formatted SKILL.md with frontmatter, suggest trigger phrases and structure |
| **Reviewing skills** | Flag common issues, identify potential over/under-triggering risks, suggest test cases |
| **Iterative improvement** | Bring edge cases back to skill-creator for refinement |

**To use:**
```
"Use the skill-creator skill to help me build a skill for [your use case]"
```

> **Note:** skill-creator helps you design and refine skills but does not execute automated test suites or produce quantitative evaluation results.

### Iteration Based on Feedback

Skills are living documents. Plan to iterate based on:

| Signal Type | Symptoms | Solution |
|-------------|----------|----------|
| **Undertriggering** | Skill doesn't load when it should, users manually enabling it, support questions about when to use it | Add more detail and nuance to the description—include keywords, especially for technical terms |
| **Overtriggering** | Skill loads for irrelevant queries, users disabling it, confusion about purpose | Add negative triggers, be more specific |
| **Execution issues** | Inconsistent results, API call failures, user corrections needed | Improve instructions, add error handling |

---

## Chapter 4: Distribution and Sharing

Skills make your MCP integration more complete. As users compare connectors, those with skills offer a faster path to value—giving you an edge over MCP-only alternatives.

### Current Distribution Model (January 2026)

**How individual users get skills:**
1. Download the skill folder
2. Zip the folder (if needed)
3. Upload to Claude.ai via Settings > Capabilities > Skills
4. Or place in Claude Code skills directory

**Organization-level skills:**
- Admins can deploy skills workspace-wide (shipped December 18, 2025)
- Automatic updates
- Centralized management

### An Open Standard

We've published Agent Skills as an open standard. Like MCP, we believe skills should be portable across tools and platforms—the same skill should work whether you're using Claude or other AI platforms. Authors can note platform-specific requirements in the skill's `compatibility` field.

### Using Skills via API

For programmatic use cases—building applications, agents, or automated workflows—the API provides direct control over skill management and execution.

**Key capabilities:**
- `/v1/skills` endpoint for listing and managing skills
- Add skills to Messages API requests via the `container.skills` parameter
- Version control and management through the Claude Console
- Works with the Claude Agent SDK for building custom agents

**When to use which surface:**

| Use Case | Best Surface |
|----------|--------------|
| End users interacting with skills directly | Claude.ai / Claude Code |
| Manual testing and iteration during development | Claude.ai / Claude Code |
| Individual, ad-hoc workflows | Claude.ai / Claude Code |
| Applications using skills programmatically | API |
| Production deployments at scale | API |
| Automated pipelines and agent systems | API |

> **Note:** Skills in the API require the Code Execution Tool beta, which provides the secure environment skills need to run.

**For implementation details, see:**
- Skills API Quickstart
- Create Custom Skills
- Skills in the Agent SDK

### Recommended Approach Today

1. **Host on GitHub**
   - Public repo for open-source skills
   - Clear README with installation instructions
   - Example usage and screenshots

2. **Document in Your MCP Repo**
   - Link to skills from MCP documentation
   - Explain the value of using both together
   - Provide quick-start guide

3. **Create an Installation Guide**

```markdown
## Installing the [Your Service] Skill

1. **Download the skill:**
   - Clone repo: `git clone https://github.com/yourcompany/skills`
   - Or download ZIP from Releases

2. **Install in Claude:**
   - Open Claude.ai > Settings > Skills
   - Click "Upload skill"
   - Select the skill folder (zipped)

3. **Enable the skill:**
   - Toggle on the [Your Service] skill
   - Ensure your MCP server is connected

4. **Test:**
   - Ask Claude: "Set up a new project in [Your Service]"
```

### Positioning Your Skill

How you describe your skill determines whether users understand its value and actually try it.

**Focus on outcomes, not features:**

✅ Good:
> "The ProjectHub skill enables teams to set up complete project workspaces in seconds—including pages, databases, and templates—instead of spending 30 minutes on manual setup."

❌ Bad:
> "The ProjectHub skill is a folder containing YAML frontmatter and Markdown instructions that calls our MCP server tools."

**Highlight the MCP + skills story:**
> "Our MCP server gives Claude access to your Linear projects. Our skills teach Claude your team's sprint planning workflow. Together, they enable AI-powered project management."

---

## Chapter 5: Patterns and Troubleshooting

These patterns emerged from skills created by early adopters and internal teams. They represent common approaches we've seen work well—not prescriptive templates.

### Choosing Your Approach: Problem-first vs. Tool-first

Think of it like Home Depot. You might walk in with a problem—"I need to fix a kitchen cabinet"—and an employee points you to the right tools. Or you might pick out a new drill and ask how to use it for your specific job.

**Skills work the same way:**

| Approach | Description |
|----------|-------------|
| **Problem-first** | "I need to set up a project workspace" → Your skill orchestrates the right MCP calls in the right sequence. Users describe outcomes; the skill handles the tools. |
| **Tool-first** | "I have Notion MCP connected" → Your skill teaches Claude the optimal workflows and best practices. Users have access; the skill provides expertise. |

Most skills lean one direction. Knowing which framing fits your use case helps you choose the right pattern below.

### Pattern 1: Sequential Workflow Orchestration

**Use when:** Your users need multi-step processes in a specific order.

```markdown
## Workflow: Onboard New Customer

### Step 1: Create Account
Call MCP tool: `create_customer`
Parameters: name, email, company

### Step 2: Setup Payment
Call MCP tool: `setup_payment_method`
Wait for: payment method verification

### Step 3: Create Subscription
Call MCP tool: `create_subscription`
Parameters: plan_id, customer_id (from Step 1)

### Step 4: Send Welcome Email
Call MCP tool: `send_email`
Template: welcome_email_template
```

**Key techniques:**
- Explicit step ordering
- Dependencies between steps
- Validation at each stage
- Rollback instructions for failures

### Pattern 2: Multi-MCP Coordination

**Use when:** Workflows span multiple services.

**Example: Design-to-development handoff**

```markdown
### Phase 1: Design Export (Figma MCP)
1. Export design assets from Figma
2. Generate design specifications
3. Create asset manifest

### Phase 2: Asset Storage (Drive MCP)
1. Create project folder in Drive
2. Upload all assets
3. Generate shareable links

### Phase 3: Task Creation (Linear MCP)
1. Create development tasks
2. Attach asset links to tasks
3. Assign to engineering team

### Phase 4: Notification (Slack MCP)
1. Post handoff summary to #engineering
2. Include asset links and task references
```

**Key techniques:**
- Clear phase separation
- Data passing between MCPs
- Validation before moving to next phase
- Centralized error handling

### Pattern 3: Iterative Refinement

**Use when:** Output quality improves with iteration.

**Example: Report generation**

```markdown
## Iterative Report Creation

### Initial Draft
1. Fetch data via MCP
2. Generate first draft report
3. Save to temporary file

### Quality Check
1. Run validation script: `scripts/check_report.py`
2. Identify issues:
   - Missing sections
   - Inconsistent formatting
   - Data validation errors

### Refinement Loop
1. Address each identified issue
2. Regenerate affected sections
3. Re-validate
4. Repeat until quality threshold met

### Finalization
1. Apply final formatting
2. Generate summary
3. Save final version
```

**Key techniques:**
- Explicit quality criteria
- Iterative improvement
- Validation scripts
- Know when to stop iterating

### Pattern 4: Context-aware Tool Selection

**Use when:** Same outcome, different tools depending on context.

**Example: File storage**

```markdown
## Smart File Storage

### Decision Tree
1. Check file type and size
2. Determine best storage location:
   - Large files (>10MB): Use cloud storage MCP
   - Collaborative docs: Use Notion/Docs MCP
   - Code files: Use GitHub MCP
   - Temporary files: Use local storage

### Execute Storage
Based on decision:
- Call appropriate MCP tool
- Apply service-specific metadata
- Generate access link

### Provide Context to User
Explain why that storage was chosen
```

**Key techniques:**
- Clear decision criteria
- Fallback options
- Transparency about choices

### Pattern 5: Domain-specific Intelligence

**Use when:** Your skill adds specialized knowledge beyond tool access.

**Example: Financial compliance**

```markdown
## Payment Processing with Compliance

### Before Processing (Compliance Check)
1. Fetch transaction details via MCP
2. Apply compliance rules:
   - Check sanctions lists
   - Verify jurisdiction allowances
   - Assess risk level
3. Document compliance decision

### Processing
IF compliance passed:
- Call payment processing MCP tool
- Apply appropriate fraud checks
- Process transaction
ELSE:
- Flag for review
- Create compliance case

### Audit Trail
- Log all compliance checks
- Record processing decisions
- Generate audit report
```

**Key techniques:**
- Domain expertise embedded in logic
- Compliance before action
- Comprehensive documentation
- Clear governance

---

### Troubleshooting

#### Skill Won't Upload

**Error: "Could not find SKILL.md in uploaded folder"**

| Cause | Solution |
|-------|----------|
| File not named exactly `SKILL.md` | Rename to `SKILL.md` (case-sensitive). Verify with: `ls -la` should show `SKILL.md` |

**Error: "Invalid frontmatter"**

| Problem | Example |
|---------|---------|
| Missing delimiters | `name: my-skill` (missing `---`) |
| Unclosed quotes | `description: "Does things` |
| **Correct format** | `---`<br>`name: my-skill`<br>`description: Does things`<br>`---` |

**Error: "Invalid skill name"**

| Problem | Example |
|---------|---------|
| Has spaces or capitals | `name: My Cool Skill` ❌ |
| **Correct format** | `name: my-cool-skill` ✅ |

#### Skill Doesn't Trigger

**Symptom:** Skill never loads automatically

**Quick checklist:**
- Is it too generic? ("Helps with projects" won't work)
- Does it include trigger phrases users would actually say?
- Does it mention relevant file types if applicable?

**Debugging approach:**
Ask Claude: "When would you use the [skill name] skill?" Claude will quote the description back. Adjust based on what's missing.

#### Skill Triggers Too Often

**Symptom:** Skill loads for unrelated queries

**Solutions:**

1. **Add negative triggers**
   ```yaml
   description: Advanced data analysis for CSV files. Use for statistical 
     modeling, regression, clustering. Do NOT use for simple data exploration 
     (use data-viz skill instead).
   ```

2. **Be more specific**
   ```yaml
   # Too broad
   description: Processes documents
   
   # More specific
   description: Processes PDF legal documents for contract review
   ```

3. **Clarify scope**
   ```yaml
   description: PayFlow payment processing for e-commerce. Use specifically 
     for online payment workflows, not for general financial queries.
   ```

#### MCP Connection Issues

**Symptom:** Skill loads but MCP calls fail

**Checklist:**

| Step | Action |
|------|--------|
| 1. Verify MCP server is connected | Claude.ai: Settings > Extensions > [Your Service]. Should show "Connected" status |
| 2. Check authentication | API keys valid and not expired, proper permissions/scopes granted, OAuth tokens refreshed |
| 3. Test MCP independently | Ask Claude to call MCP directly: "Use [Service] MCP to fetch my projects". If this fails, issue is MCP not skill |
| 4. Verify tool names | Skill references correct MCP tool names. Check MCP server documentation. Tool names are case-sensitive |

#### Instructions Not Followed

**Symptom:** Skill loads but Claude doesn't follow instructions

**Common causes and solutions:**

| Cause | Solution |
|-------|----------|
| **Instructions too verbose** | Keep instructions concise. Use bullet points and numbered lists. Move detailed reference to separate files. |
| **Instructions buried** | Put critical instructions at the top. Use `## Important` or `## Critical` headers. Repeat key points if needed. |
| **Ambiguous language** | Be explicit (see example below) |
| **Model "laziness"** | Add explicit encouragement in user prompts |

**Ambiguous vs. explicit:**

❌ Bad:
```markdown
Make sure to validate things properly
```

✅ Good:
```markdown
CRITICAL: Before calling create_project, verify:
- Project name is non-empty
- At least one team member assigned
- Start date is not in the past
```

> **Advanced technique:** For critical validations, consider bundling a script that performs the checks programmatically rather than relying on language instructions. Code is deterministic; language interpretation isn't.

#### Large Context Issues

**Symptom:** Skill seems slow or responses degraded

**Causes:**
- Skill content too large
- Too many skills enabled simultaneously
- All content loaded instead of progressive disclosure

**Solutions:**

| Solution | Details |
|----------|---------|
| Optimize SKILL.md size | Move detailed docs to `references/`. Link to references instead of inline. Keep SKILL.md under 5,000 words. |
| Reduce enabled skills | Evaluate if you have more than 20-50 skills enabled simultaneously. Consider skill "packs" for related capabilities. |

---

## Chapter 6: Resources and References

### Official Documentation

**Anthropic Resources:**
- [Best Practices Guide](https://docs.anthropic.com/en/docs/agents-and-tools/agent-skills/best-practices)
- [Skills Documentation](https://docs.anthropic.com/en/docs/agents-and-tools/agent-skills)
- [API Reference](https://docs.anthropic.com/en/api)
- [MCP Documentation](https://modelcontextprotocol.io)

**Blog Posts:**
- Introducing Agent Skills
- Engineering Blog: Equipping Agents for the Real World
- Skills Explained
- How to Create Skills for Claude
- Building Skills for Claude Code
- Improving Frontend Design through Skills

### Example Skills

**Public skills repository:**
- [GitHub: anthropics/skills](https://github.com/anthropics/skills)
- Contains Anthropic-created skills you can customize

### Tools and Utilities

**skill-creator skill:**
- Built into Claude.ai and available for Claude Code
- Can generate skills from descriptions
- Reviews and provides recommendations
- Use: "Help me build a skill using skill-creator"

**Validation:**
- skill-creator can assess your skills
- Ask: "Review this skill and suggest improvements"

### Getting Support

**For Technical Questions:**
- General questions: Community forums at the Claude Developers Discord

**For Bug Reports:**
- GitHub Issues: anthropics/skills/issues
- Include: Skill name, error message, steps to reproduce

---

## Appendices

### Reference A: Quick Checklist

Use this checklist to validate your skill before and after upload.

#### Before You Start

- [ ] Identified 2-3 concrete use cases
- [ ] Tools identified (built-in or MCP)
- [ ] Reviewed this guide and example skills
- [ ] Planned folder structure

#### During Development

- [ ] Folder named in kebab-case
- [ ] `SKILL.md` file exists (exact spelling)
- [ ] YAML frontmatter has `---` delimiters
- [ ] `name` field: kebab-case, no spaces, no capitals
- [ ] `description` includes WHAT and WHEN
- [ ] No XML tags (`<` `>`) anywhere
- [ ] Instructions are clear and actionable
- [ ] Error handling included
- [ ] Examples provided
- [ ] References clearly linked

#### Before Upload

- [ ] Tested triggering on obvious tasks
- [ ] Tested triggering on paraphrased requests
- [ ] Verified doesn't trigger on unrelated topics
- [ ] Functional tests pass
- [ ] Tool integration works (if applicable)
- [ ] Compressed as .zip file

#### After Upload

- [ ] Test in real conversations
- [ ] Monitor for under/over-triggering
- [ ] Collect user feedback
- [ ] Iterate on description and instructions
- [ ] Update version in metadata

---

### Reference B: YAML Frontmatter

#### Required Fields

```yaml
---
name: skill-name-in-kebab-case
description: What it does and when to use it. Include specific trigger phrases.
---
```

#### All Optional Fields

```yaml
---
name: skill-name
description: [required description]
license: MIT                              # Optional: License for open-source
allowed-tools: "Bash(python:*) Bash(npm:*) WebFetch"  # Optional: Restrict tool access
compatibility: "Requires network access"  # Optional: Environment requirements
metadata:                                 # Optional: Custom fields
  author: Company Name
  version: 1.0.0
  mcp-server: server-name
  category: productivity
  tags: [project-management, automation]
  documentation: https://example.com/docs
  support: support@example.com
---
```

#### Security Notes

**Allowed:**
- Any standard YAML types (strings, numbers, booleans, lists, objects)
- Custom metadata fields
- Long descriptions (up to 1024 characters)

**Forbidden:**
- XML angle brackets (`<` `>`) — security restriction
- Code execution in YAML (uses safe YAML parsing)
- Skills named with "claude" or "anthropic" prefix (reserved)

---

### Reference C: Complete Skill Examples

For full, production-ready skills demonstrating the patterns in this guide:

- **[Document Skills](https://github.com/anthropics/skills)** — PDF, DOCX, PPTX, XLSX creation
- **[Example Skills](https://github.com/anthropics/skills)** — Various workflow patterns
- **Partner Skills Directory** — View skills from partners such as Asana, Atlassian, Canva, Figma, Sentry, Zapier, and more

These repositories stay up-to-date and include additional examples beyond what's covered here. Clone them, modify them for your use case, and use them as templates.

---

*Source: [claude.ai](https://claude.ai)*
