# Agent Guidelines

## Required Reading

Before creating or modifying any skill, read [GUIDE.md](./GUIDE.md) - the complete reference for skill structure, patterns, and best practices.

## Git Policy

**CRITICAL: Never create commits without explicit user approval.**

Before any commit:
1. Show the user what will be committed (files, diff summary)
2. Propose a commit message
3. **Wait for explicit confirmation** (e.g., "yes", "commit it", "go ahead")
4. Only then execute the commit

Do not interpret task completion as permission to commit. The user must actively say yes.

## Code Style

### Shell Scripts

- Always include `set -e` to exit on error
- Use `shellcheck` for static analysis
- Output data (JSON) to stdout, messages to stderr
- Validate all inputs before use
- Use `jq` for JSON construction (prevents injection)
- Store credentials with restricted permissions (700/600)

### Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Constants | UPPER_SNAKE_CASE | `CONFIG_DIR` |
| Variables | lower_snake_case | `file_path` |
| Functions | lower_snake_case | `process_data` |
| Folders | kebab-case | `my-skill` |

## Commits

```
<action> <scope> <description>

Examples:
- add authentication flow
- fix token refresh handling
- improve input validation
```

## Branches

- Features: `feat/<name>`
- Fixes: `fix/<issue>`
