# Agent Guidelines

## Git Policy

**CRITICAL: Never commit or push without explicit user approval.**

Before any commit:
1. Show the user what will be committed (files, diff summary)
2. Propose a commit message
3. **Wait for explicit confirmation** (e.g., "yes", "commit it", "go ahead")
4. Only then execute the commit

Before any push:
1. Show what will be pushed (commits, branch, remote)
2. **Wait for explicit confirmation**
3. Only then execute the push

Do not interpret task completion as permission to commit or push. The user must actively say yes.

## Required Reading

Before creating or modifying any skill, read [GUIDE.md](./GUIDE.md) for structure, patterns, and best practices. GUIDE.md is a companion reference; where it disagrees with the hard rules below, **the rules below win** (GUIDE.md predates the current spec and states an outdated description behavior).

## Skill Authoring Spec (Agent Skills open standard)

Skills published here target the [Agent Skills open standard](https://agentskills.io/specification) (what skills.sh validates against). These are hard rules — a skill that breaks them fails `skills-ref validate`:

| Field | Rule |
|-------|------|
| `name` | Required. 1-64 chars. Lowercase `a-z`, `0-9`, and `-` only. No leading/trailing hyphen, no `--`. **Must match the parent directory name.** |
| `description` | Required. **Max 1024 characters** (count the folded value, not per-line). Must say what it does AND when to use it. Include trigger keywords. No `<` or `>`. |
| `license` | Optional. Short name (e.g. `MIT`) or reference to a bundled license file. |
| `compatibility` | Optional. Max 500 chars. Only if the skill has real environment requirements. |
| `metadata` | Optional. String→string map. We use `author` and `version`. |
| `allowed-tools` | Optional, experimental. Space-separated pre-approved tools. |

Structural rules:
- File must be exactly `SKILL.md` (case-sensitive). No `README.md` inside a skill folder.
- Keep `SKILL.md` under 500 lines / ~5000 tokens; move depth into `references/`.
- Optional dirs: `scripts/`, `references/`, `assets/`. Keep file references one level deep from `SKILL.md`.
- Reserved: no `claude` or `anthropic` in the skill name.

Before committing a new or changed skill, verify the description length:
```bash
awk '/^description:/{f=1;next} /^license:|^compatibility:|^metadata:/{f=0} f' <skill>/SKILL.md \
  | sed 's/^  //' | tr '\n' ' ' | sed 's/ *$//' | wc -c   # must be <= 1024
```
If `skills-ref` is available, prefer `skills-ref validate ./<skill>`.

## Code Style

### Shell Scripts

- Always include `set -e` to exit on error
- Use `shellcheck` for static analysis
- Output data (JSON) to stdout, messages to stderr
- Validate all inputs before use
- Use `jq` for JSON construction (prevents injection)
- Store credentials with restricted permissions (700/600)

## Security

### Credential Protection

- **Never expose secrets in process list**: Use `curl -K -` to pass auth headers via stdin
  ```bash
  # BAD - visible in ps aux:
  curl -H "Authorization: Bearer $TOKEN" ...
  
  # GOOD - hidden from process list:
  echo "header = \"Authorization: Bearer $TOKEN\"" | curl -K - ...
  ```

- **Hide POST data from process list**: Use `--data-binary @-` for sensitive form data
  ```bash
  # BAD - visible in ps aux:
  curl -d "client_secret=$SECRET" ...
  
  # GOOD - hidden:
  echo "client_secret=$SECRET" | curl --data-binary @- ...
  ```

- **Silent credential input**: Use `read -s` when prompting for secrets
  ```bash
  read -s -p "API Key: " api_key
  echo ""  # newline after silent input
  ```

- **Atomic file permissions**: Use `umask` before creating sensitive files
  ```bash
  # BAD - race condition between create and chmod:
  echo "$secret" > file && chmod 600 file
  
  # GOOD - atomic:
  (umask 077 && echo "$secret" > file)
  ```

- **Credential storage**: `~/.config/<skill>/` with 700 dir, 600 files

- **JSON construction**: Always use `jq` to prevent injection
  ```bash
  # BAD - injection risk:
  echo '{"key":"'"$user_input"'"}'
  
  # GOOD - safe:
  jq -n --arg k "$user_input" '{key:$k}'
  ```

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
