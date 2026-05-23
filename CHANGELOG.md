# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning: [SemVer](https://semver.org/).

## [2.0.0-fork] — 2026-05-23

### Changed (breaking)

- **Code-writer-only contract.** Claude plans + reviews; Codex implements; Claude verifies. Codex no longer makes product, architecture, or scope decisions.
- **8-section brief schema** (Claude → Codex): Task / Scope / Sandbox tier / Constraints / Non-goals / Acceptance criteria / Self-check / Report format. Documented in `personas/code-writer.md` (Claude-facing half).
- **5-section structured report** (Codex → Claude): Status / Files changed / Self-check / Brief mismatches / Open questions. Status is `done` / `blocked` / `partial`.
- **Brief-declared sandbox tier.** Replaces "Claude auto-escalates per task". Three tiers:
  - `network` — **default.** workspace writes + outbound network + codex's native web_search tool. Maps to `--dangerously-bypass-approvals-and-sandbox --config tools.web_search=true`.
  - `workspace` — explicit downgrade. workspace writes only, no network, no web_search. Maps to `--sandbox workspace-write`.
  - `system` — anywhere on disk + network + web_search.
- **Codex contract is split** into a Codex-facing slice (~1.5KB, between `CODEX_CONTRACT_BEGIN/END` markers) and a Claude-facing body. `scripts/codex-dispatch.sh` extracts only the contract slice and prepends it to every dispatch. Codex never sees the Claude-facing material.
- **Mandatory verify routine.** Parse 5 report sections, spot-read changed regions, confirm self-check exit codes, surface mismatches/questions.
- **Triage-by-cause failure loop.** Self-check failed → resume. Brief mismatch → surface. Open question → answer if obvious, else surface.
- **`scripts/codex-dispatch.sh`** retooled: `--sandbox full-auto|bypass|read-only` replaced by `--tier network|workspace|system` (default `network`). Auto-wraps a bare task into the code-writer template if stdin doesn't start with `## Task`.
- **`SKILL.md`** rewritten end-to-end.

### Removed

- `personas/reviewer.md`, `debugger.md`, `auditor.md`, `researcher.md`, `refactorer.md`. All five required judgment from Codex, which is forbidden under this contract.

### Added

- `personas/code-writer.md` — the only sanctioned persona; carries both the Codex contract and the Claude-facing schema.

### Migration

v1 dispatches won't produce the new 5-section report. Re-author as briefs against the new 8-section schema. To stay on the generalist worker model, use upstream `dwgx/claude-codex-subagent` v1.0.0.

## [1.0.0] — 2026-04-14

Initial release of upstream `claude-codex-subagent`. Generalist worker. Five personas (reviewer / debugger / auditor / researcher / refactorer). Adaptive sandbox heuristic.
