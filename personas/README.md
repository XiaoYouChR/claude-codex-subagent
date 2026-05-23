# Personas

One persona: [code-writer.md](code-writer.md).

The file has two parts separated by `<!-- CODEX_CONTRACT_BEGIN -->` / `<!-- CODEX_CONTRACT_END -->`:

- **Inside the markers** — what Codex sees. Extracted by [../scripts/codex-dispatch.sh](../scripts/codex-dispatch.sh) and prepended to every dispatch. Keep it ≤2KB; everything in here costs Codex tokens.
- **Outside the markers** — what Claude / humans read. Brief schema, worked examples, status interpretation table.

## What this fork removed

Upstream shipped 5 personas (reviewer / debugger / auditor / researcher / refactorer). All five asked Codex to make judgment calls. Under this fork's contract those roles stay on Claude. Removed.

## Adding more personas

Don't, by default. If you genuinely need one, copy `code-writer.md` (keep both marker blocks intact, both halves filled) and rename. The dispatch script picks it up via `--persona <name>`.
