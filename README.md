# claude-codex-subagent

[![CI](https://github.com/dwgx/claude-codex-subagent/actions/workflows/ci.yml/badge.svg)](https://github.com/dwgx/claude-codex-subagent/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Claude plans and reviews. Codex writes the code. Claude verifies.

A Claude Code skill that turns `codex exec` into a code-writing worker. Claude packages an 8-section brief; Codex implements, self-checks, returns a 5-section structured report; Claude verifies mechanically. Codex makes no product, architecture, or scope decisions.

Works on macOS, Linux, Windows (git-bash / WSL). No runtime deps beyond `codex` on PATH.

## How it works

```
   ┌────────────┐    brief (8 sections)     ┌────────────┐
   │   Claude   │ ────────────────────▶     │   Codex    │
   │  planner + │                            │   writer   │
   │  reviewer  │ ◀────────────────────      │            │
   └────────────┘    report (5 sections)     └────────────┘
```

The brief schema: Task / Scope / Sandbox tier / Constraints / Non-goals / Acceptance criteria / Self-check / Report format.

The report schema: Status / Files changed / Self-check / Brief mismatches / Open questions.

Codex's contract is extracted from [personas/code-writer.md](personas/code-writer.md) (between the `CODEX_CONTRACT_BEGIN/END` markers) and prepended to every dispatch by [scripts/codex-dispatch.sh](scripts/codex-dispatch.sh). Codex never reads files outside the user's project.

## Sandbox tier

| Tier | Allows | Flag |
|---|---|---|
| `network` (default) | workspace writes + network + codex web_search | `--dangerously-bypass-approvals-and-sandbox --config tools.web_search=true` |
| `workspace` | workspace writes, no network | `--full-auto` |
| `system` | anywhere + network + web_search | `--dangerously-bypass-approvals-and-sandbox` |

Default is `network`. Downgrade to `workspace` only when you want to deliberately block network access.

## Install

```bash
git clone https://github.com/dwgx/claude-codex-subagent.git
cp -r claude-codex-subagent/skills/codex-subagent ~/.claude/skills/
```

Or via plugin:

```
/plugin install https://github.com/dwgx/claude-codex-subagent
```

Detailed instructions in [INSTALL.md](INSTALL.md).

## Use

Once installed, talk to Claude:

- "用 codex 实现 src/api/items.ts 的 since 参数"
- "丢给 codex 写 src/schemas/user.py"
- "delegate the implementation to codex"

Claude announces the dispatch in one line (tier + effort), builds the brief, runs `codex exec`, verifies the report, summarises.

### Direct CLI

```bash
./scripts/codex-dispatch.sh --cd /path/to/repo <<'EOF'
## Task
...
## Scope / files in play
- src/foo.ts
## Sandbox tier
network
## Constraints
- ...
## Non-goals
- ...
## Acceptance criteria
- ...
## Self-check (run before reporting)
- pnpm test
## Report format
<the 5-section schema, inlined>
EOF
```

Or pass a bare task and let the script wrap it:

```bash
./scripts/codex-dispatch.sh --cd /path/to/repo "Add since param to GET /api/items."
```

5 worked briefs in [examples/sample-dispatches.md](examples/sample-dispatches.md).

### Health check

```bash
./scripts/doctor.sh
```

## Design

- **Codex-facing contract is ~1.5KB**, extracted from `personas/code-writer.md` via markers. Everything else in the persona file is Claude-facing and never touches Codex.
- **Brief-declared sandbox tier**, no auto-escalation. Codex refuses to act beyond it.
- **Stderr to `/tmp/codex-<rand>.log`**, not `/dev/null`. Clean happy path, full debug on failure.
- **Structured report contract**, mechanically verifiable.
- **Resume-first on recoverable failures**, fresh dispatch when the brief itself was wrong.

## Not this

- Generalist worker (research, audit, review, debug, refactor surveys) — Claude's job.
- Thinking offload.
- Silent fallback or silent escalation.

## Credits

Patterns inherited from:

- [openai/codex-plugin-cc](https://github.com/openai/codex-plugin-cc) — thin-forwarder, background lifecycle
- [skills-directory/skill-codex](https://github.com/skills-directory/skill-codex) — resume-first
- [shinpr/sub-agents-skills](https://github.com/shinpr/sub-agents-skills) — structured outcome classification
- [@timurkhakhalev/codex-cli-setup](https://github.com/timurkhakhalev/codex-cli-setup) — temp-log pattern
- [dwgx/claude-codex-subagent](https://github.com/dwgx/claude-codex-subagent) v1.x — the generalist baseline this fork narrowed from

## License

MIT — see [LICENSE](LICENSE).
