# brgrp skills

A collection of [Agent Skills](https://agentskills.io) — portable, on-demand capabilities for AI coding agents. Each skill is a folder with a `SKILL.md` that agents load when a task matches its description. Compatible with any tool that supports the open standard (Claude Code, Cursor, Codex, OpenCode, and others), and publishable to [skills.sh](https://skills.sh).

## Skills

| Skill | What it does |
|-------|--------------|
| [`platform-strategy`](./platform-strategy) | Shapes platform strategy docs, exec decks, and brainstorms using Gregor Hohpe's *Platform Strategy* — interview first, then deliver. |
| [`pyramid-principle`](./pyramid-principle) | Structures presentations, READMEs, and brainstorm output answer-first using Barbara Minto's Pyramid Principle. |
| [`azure-foundry-websearch`](./azure-foundry-websearch) | Real-time web search via Azure AI Foundry's Responses API with Grounding with Bing. |
| [`spotify`](./spotify) | Controls Spotify playback from the CLI (requires Spotify Premium). |

## Install

```bash
npx skills add brgrp/skills
```

## Contributing

Read [AGENTS.md](./AGENTS.md) before creating or modifying a skill — it covers the git policy and the Agent Skills authoring spec these skills validate against. [GUIDE.md](./GUIDE.md) is a deeper companion reference.
