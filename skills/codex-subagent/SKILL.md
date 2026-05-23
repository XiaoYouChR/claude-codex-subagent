---
name: codex-subagent
description: >
  Hand off code-writing to the local Codex CLI as a worker. Claude writes a
  structured brief (task / scope / sandbox tier / constraints / non-goals /
  acceptance / self-check / report format), Codex implements + self-checks +
  emits a 5-section report, Claude verifies. Codex makes no product,
  architecture, or scope decisions. Triggers: "用 codex 实现", "丢给 codex 写",
  "让 codex 改", "codex 实现 / 写一下", "have codex implement", "delegate
  implementation to codex".
user-invocable: true
---

# Codex as code-writing worker

Claude plans and reviews. Codex writes the code. Claude verifies the report.

Codex's contract — what it may do, what it must refuse — lives in [personas/code-writer.md](../../personas/code-writer.md) between the `CODEX_CONTRACT_BEGIN/END` markers. [scripts/codex-dispatch.sh](../../scripts/codex-dispatch.sh) extracts that slice and prepends it to every dispatch so Codex sees the rules without ever reading the file. This SKILL.md is Claude's side: how to build a brief, dispatch, verify.

## When to dispatch

- A code change you've already planned and scoped.
- The work is >50 lines, spans multiple files, or has a real self-check.
- You'd otherwise burn output tokens writing files line by line.

When NOT to:

- One-line edits — use `Edit` directly.
- Exploration, design, review, debugging investigation — those are yours.
- The user is pairing with you interactively.

## The brief

8 sections, in order, every time:

```
## Task
<one paragraph>

## Scope / files in play
- <path>
Do not modify anything outside this list.

## Sandbox tier
network | workspace | system

## Constraints
- <rule>

## Non-goals
- <forbidden thing>

## Acceptance criteria
- <objective condition>

## Self-check (run before reporting)
- <exact shell command>

## Report format
<inline the full 5-section schema from the contract, verbatim>
```

The report-format field carries the full schema as literal text — see [personas/code-writer.md](../../personas/code-writer.md) for the canonical text to paste in.

### Sandbox tier

| Tier | What it allows | Codex flag |
|---|---|---|
| `network` (default) | workspace writes + outbound network + codex's web_search | `--dangerously-bypass-approvals-and-sandbox --config tools.web_search=true` |
| `workspace` | workspace writes, no network, no web_search | `--full-auto` |
| `system` | anywhere on disk + network + web_search | `--dangerously-bypass-approvals-and-sandbox` |

Default = `network`. Pick `workspace` only when you want to deliberately block network. `system` is rare; reserve for cross-project briefs.

Codex must refuse to act beyond the declared tier. If you picked too low, Codex returns `blocked` with a Brief mismatch and you re-dispatch.

### Effort

Default to codex's configured default. Override with `--config model_reasoning_effort="<level>"` only for:

- `medium` — cross-file refactors, non-trivial dataflow.
- `high` — subtle bugs, code requiring understanding of complex existing code.

## The Codex contract (inline)

Every dispatch you make to Codex must start with this contract block verbatim, followed by `=== TASK ===`, followed by your brief. This is what tells Codex its rules — Codex cannot read files in this repo, so the contract has to be carried in the prompt itself.

```
=== CONTRACT ===
You implement a brief. You do not design, audit, refactor, or expand scope.

## Forbidden
- Modifying files outside `## Scope / files in play`.
- Acting beyond `## Sandbox tier` (network = workspace writes + network; workspace = workspace writes, no network; system = anywhere).
- Drive-by improvements, unrequested refactors, renamings, formatting, comment additions.
- Adding error handling, validation, fallbacks the brief did not request.
- Inventing a "concise" or "standard" report shape. The format below is mandatory. If something referenced is unreachable, return `blocked` with a Brief mismatch.
- A summary/preamble/postamble around the report. Only the report.

## Required output
Exactly these five sections, in this order, nothing outside them:

## Status
done | blocked | partial

## Files changed
- <path> (+<added> / -<removed>)
(or "(none)")

## Self-check
- `<command>` → exit <code>
  <2-5 line excerpt; one summary line for clean passes>

## Brief mismatches
(none)
— or —
- <what in the brief was missing / contradictory / infeasible>

## Open questions
(none)
— or —
- <specific question that needs answering before further work>

## Status rules
- `done` — every acceptance criterion met, every self-check exits 0, mismatches and questions both `(none)`.
- `partial` — defensible checkpoint with some criteria met. Must list a mismatch or question explaining the stop.
- `blocked` — cannot progress without input. Must list a mismatch or question.
- When uncertain, prefer `blocked` over a false `done`.
=== TASK ===
<your 8-section brief here>
```

The contract block above is the authoritative copy. The same text lives in [personas/code-writer.md](../../personas/code-writer.md) between `<!-- CODEX_CONTRACT_BEGIN -->` markers — that file exists for the dispatch script and for human reference, but **you do not need to read it**. The contract is right here.

## Command shape

```bash
filename=$(openssl rand -hex 4)
codex exec --skip-git-repo-check --dangerously-bypass-approvals-and-sandbox \
  --config tools.web_search=true \
  [-C <REPO-DIR>] \
  [--config model_reasoning_effort="medium"] \
  2>>"/tmp/codex-${filename}.log" <<'EOF'
=== CONTRACT ===
<the contract block above, verbatim>
=== TASK ===
<your brief>
EOF
```

If [scripts/codex-dispatch.sh](../../scripts/codex-dispatch.sh) is available on disk, you can use it instead — it does the contract injection, tier→flag mapping, and temp-log pattern for you. It is optional; the inline contract above is enough.

Always pass `--skip-git-repo-check`. Always log stderr to `/tmp/codex-<rand>.log`, never `/dev/null`.

## Report from Codex

5 sections, in order:

```
## Status        — done | blocked | partial
## Files changed — <path> (+<added> / -<removed>)
## Self-check    — `<command>` → exit <code> + short excerpt
## Brief mismatches — (none) or <item>
## Open questions  — (none) or <item>
```

Anything else is a contract violation.

## Verify

Mechanical, every time:

1. Confirm all 5 sections present. Missing → resume with "Re-emit only the 5-section report."
2. `Status` must be `done`. `partial`/`blocked` → go to triage.
3. For each `Files changed` entry: targeted `Read` of the modified region only. Confirm it matches the report.
4. Every `Self-check` exit code must be 0. Non-zero → triage.
5. `Brief mismatches` must be `(none)`. Anything else → surface to user.
6. `Open questions` must be `(none)`. Otherwise: answer from context, or surface.
7. One-line summary to user. Don't paste the report verbatim.

## Failure triage

| Cause | Action |
|---|---|
| Self-check failed, brief intact | Resume with the failing output pasted in |
| Brief mismatch | Stop, surface to user — do not silently re-spec |
| Open question, you have the answer | Resume with the answer |
| Open question, you don't | Surface to user |
| `partial` or dead-end `blocked` | Surface to user |
| Codex itself exited non-zero | Read the stderr log; diagnose; fix the dispatch (don't silent-retry) |

### Resume vs fresh

- Self-check failed, brief intact → resume.
- Brief had a bug → fresh dispatch with corrected brief.
- Codex asked a question, short answer → resume.
- Session went off the rails → fresh.

Resume syntax (prompt via stdin, no `--full-auto`/`--config`/`-p`):

```bash
echo "<follow-up>" | codex exec --skip-git-repo-check resume --last \
  2>>"/tmp/codex-$(openssl rand -hex 4).log"
```

## Parallel dispatch

For N independent briefs, dispatch each in parallel via Bash `run_in_background: true`, collect task_ids, reap with `TaskOutput`. Each call gets its own Codex context.

Good: independent features in unrelated modules, same change across N packages.
Bad: B depends on A's output → resume A's session instead.

## Long runs

Dispatch >30s with `run_in_background: true`. Do other work. Reap with `TaskOutput block: true`. `TaskStop` to cancel.

## Status updates to the user

One line before:

> Dispatching to codex (tier: network, effort: default). Brief covers src/api/items.ts + its test.

One line after:

> Codex returned done. pnpm test + typecheck both exit 0. Spot-read confirmed. 2 files touched.

If you downgrade tier:

> Tier is `workspace` (no network) — implementing against untrusted spec.

## Not in scope

- Analysis, review, audit, debugging investigation, research surveys — Claude's job, not delegate-able through this skill.
- Thinking offload. Planning stays with Claude.
- Silent retries or silent escalations.
- Pasting Codex's full report into chat. Summarise.
