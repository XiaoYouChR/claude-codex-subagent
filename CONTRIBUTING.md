# Contributing

Thanks for considering a contribution. This project is small, focused, and aims to stay that way — improvements are welcome, but scope discipline matters.

## What this project is (and isn't)

**Is**: a Claude Code skill teaching Claude how to hand off **code-writing only** to the local Codex CLI under a structured brief → write → verify contract. Claude plans and reviews; Codex implements; Claude verifies.

**Isn't**: a generalist worker-subagent, a code reviewer, a debugger, an auditor, a researcher, or a refactor-opportunity scanner. All of those involve judgment, and judgment stays on Claude under this fork. (The upstream `dwgx/claude-codex-subagent` v1.x line does the generalist thing — if that's what you want, use upstream.)

## Kinds of contributions we want

- **Prompting improvements to SKILL.md.** If a phrasing, decision rule, or example consistently makes Claude produce better-shaped briefs or run the verify routine more reliably, we want it.
- **Sharpening `personas/code-writer.md`.** Tighter brief schema descriptions, clearer "may / must not" rules, better worked examples in the persona file itself.
- **More brief examples in `examples/sample-dispatches.md`.** New genuinely distinct shapes (e.g., monorepo cross-package change, language-agnostic ones) are welcome. Don't add near-duplicates of existing examples.
- **Platform portability fixes.** This needs to work on Mac, Linux, and Windows (git-bash / WSL / PowerShell where reasonable). Bugs on any of those are fair game.
- **Documentation.** Clearer install steps, better troubleshooting, translations.
- **`doctor.sh` checks.** If you hit a breakage that doctor didn't catch, add a check.
- **CI tightening.** More validation in `.github/workflows/ci.yml` is welcome.

## Kinds we'd rather not

- **Adding back the legacy personas** (reviewer, debugger, auditor, researcher, refactorer). The pivot was deliberate — those roles violate "no judgment on Codex's side". If you need them, fork off upstream v1.x, not this fork.
- **Adding new personas in general.** One persona is a feature, not a limitation. Convince us a new persona expresses a contract that genuinely cannot be expressed as a code-writer brief.
- Adding Node / Python / Rust dependencies. The skill is intentionally zero-dep — markdown plus a thin bash wrapper.
- Adding new top-level directories unless they serve a clear purpose.
- Renaming core files or directories — it breaks every existing install.
- "Also delegates to Gemini / Cursor / local models." Out of scope.
- Stylistic rewrites of SKILL.md or `personas/code-writer.md` without a concrete reason. The current wording is load-bearing for trigger matching and contract enforcement.

## Development workflow

```bash
git clone https://github.com/dwgx/claude-codex-subagent.git
cd claude-codex-subagent

# Install the skill into your own Claude Code for testing:
./scripts/sync-skill.sh to-local

# Edit skills/codex-subagent/SKILL.md or personas/code-writer.md, then re-sync:
./scripts/sync-skill.sh to-local

# Before committing, run the health check:
./scripts/doctor.sh

# When you're ready:
git add .
git commit -m "short descriptive subject"
git push
```

## PR checklist

- [ ] `./scripts/doctor.sh` passes (or warns are explained).
- [ ] SKILL.md still has valid YAML frontmatter (CI validates this).
- [ ] `.claude-plugin/plugin.json` and `marketplace.json` still parse as JSON (CI validates).
- [ ] Shell scripts pass `shellcheck` if you touched them (CI validates).
- [ ] You ran the skill end-to-end on at least one real brief to confirm Claude still triggers, produces a brief, parses the report, and runs the verify routine.
- [ ] If your change adds or changes a brief field: `personas/code-writer.md` (the contract), `SKILL.md` (Claude's instructions), and `examples/sample-dispatches.md` (the worked examples) all stay in sync.
- [ ] If your change adds or changes a report field: same files plus the verify routine in SKILL.md.
- [ ] README / INSTALL updated if user-visible behavior changed.
- [ ] One commit, coherent change. No drive-by reformats.

## Testing changes to SKILL.md or the brief contract

The hardest part of changing SKILL.md or `personas/code-writer.md` is verifying the change doesn't break Claude's trigger matching, brief construction, or verify routine. Recommended loop:

1. Sync your edits to `~/.claude/skills/codex-subagent/` via `./scripts/sync-skill.sh to-local`.
2. Restart Claude Code fully (the skill index loads at startup).
3. Open a fresh conversation in a test repo and try 3 prompts:
   - **Obvious dispatch**: "用 codex 实现 src/utils/foo.ts 的一个 X 函数, 写测试" — Claude should produce a full 8-section brief.
   - **Should-not-trigger**: "解释一下这段代码" — Claude should just explain, not dispatch.
   - **Borderline**: "帮我修一个一行的 bug" — should be `Edit` directly, not dispatch (too small).
4. For each dispatch, verify Claude's verify routine runs (you should see the spot-read of changed files in the transcript).

If you changed sandbox/tier logic, also test with a brief that declares each tier and confirm `codex-dispatch.sh --debug` shows the right flags.

## Code of conduct

Don't be a jerk. Assume good faith. Keep criticism technical and specific.

## License

By contributing, you agree that your contributions will be licensed under the MIT License, same as the rest of the project.
