# Sample briefs

5 brief shapes for code-writing dispatches. Copy, adapt.

Tier → flag mapping:

| Tier | Flag |
|---|---|
| `network` (default) | `--dangerously-bypass-approvals-and-sandbox --config tools.web_search=true` |
| `workspace` | `--sandbox workspace-write` |
| `system` | `--dangerously-bypass-approvals-and-sandbox` |

Full contract in [../personas/code-writer.md](../personas/code-writer.md).

---

## 1. New feature — add an API parameter

```bash
filename=$(openssl rand -hex 4)
codex exec --skip-git-repo-check --dangerously-bypass-approvals-and-sandbox \
  --config tools.web_search=true -C /path/to/repo \
  2>>"/tmp/codex-${filename}.log" <<'EOF'
## Task
Add a `since` query parameter to GET /api/items. ISO-8601 date; filters items where created_at >= since. Malformed input returns 400 with body identifying the bad field.

## Scope / files in play
- src/api/items.ts
- tests/api/items.test.ts
Do not modify anything outside this list.

## Sandbox tier
network

## Constraints
- No new dependencies.
- Validation uses the existing zod pattern from neighbouring handlers.
- 400 body shape: { error: "invalid_param", field: "since" }.

## Non-goals
- Do not touch limit/offset params.
- Do not refactor the route handler.

## Acceptance criteria
- Valid `since` filters correctly.
- Malformed `since` returns 400 with the specified body.
- New test in items.test.ts covers both branches.
- All existing tests still pass.

## Self-check (run before reporting)
- pnpm test tests/api/items.test.ts
- pnpm typecheck

## Report format
Emit exactly these 5 sections, nothing outside:

## Status
done | blocked | partial

## Files changed
- <path> (+<added> / -<removed>)

## Self-check
- `<command>` → exit <code>
  <2-5 line excerpt>

## Brief mismatches
(none) — or — <item>

## Open questions
(none) — or — <item>
EOF
```

---

## 2. Bug fix — narrow root cause

```bash
filename=$(openssl rand -hex 4)
codex exec --skip-git-repo-check --dangerously-bypass-approvals-and-sandbox \
  --config tools.web_search=true -C /path/to/repo \
  2>>"/tmp/codex-${filename}.log" <<'EOF'
## Task
Fix the off-by-one in src/utils/pagination.ts:computeOffset. When page=1 it returns page_size; should return 0. Page N → offset (N-1) * page_size.

## Scope / files in play
- src/utils/pagination.ts
- tests/utils/pagination.test.ts

## Sandbox tier
network

## Constraints
- Minimal diff. Formula change only.

## Non-goals
- Do not rename, refactor, or clean up the file.

## Acceptance criteria
- The currently-failing test "page 1 has offset 0" passes.
- All other pagination tests still pass.

## Self-check (run before reporting)
- pnpm test tests/utils/pagination.test.ts

## Report format
[5-section schema, inlined as in example 1]
EOF
```

---

## 3. Explicit `workspace` downgrade

Pure mechanical work, no network needed. Downgrade `workspace` blocks outbound calls as defence in depth.

```bash
filename=$(openssl rand -hex 4)
codex exec --skip-git-repo-check --sandbox workspace-write -C /path/to/repo \
  --config model_reasoning_effort="medium" \
  2>>"/tmp/codex-${filename}.log" <<'EOF'
## Task
Rename `getCwd` to `getCurrentWorkingDirectory` across src/ and tests/. Code only — not comments, not docs.

## Scope / files in play
- All .ts under src/ and tests/ that reference `getCwd`.
- Definition site: src/utils/paths.ts.

## Sandbox tier
workspace

## Constraints
- Update declaration + every call site in the same diff.
- No formatting changes to unrelated lines.

## Non-goals
- Do not rename other identifiers.
- Do not touch .md, .json, or comments.

## Acceptance criteria
- `grep -r "getCwd" src tests` returns nothing.
- All existing tests pass unchanged.
- pnpm typecheck clean.

## Self-check (run before reporting)
- pnpm typecheck
- pnpm test

## Report format
[5-section schema, inlined]
EOF
```

---

## 4. Network-required dep install

```bash
filename=$(openssl rand -hex 4)
codex exec --skip-git-repo-check --dangerously-bypass-approvals-and-sandbox \
  --config tools.web_search=true -C /path/to/repo \
  2>>"/tmp/codex-${filename}.log" <<'EOF'
## Task
Add `zod` ^3.22.0 as a runtime dep. Replace the hand-rolled validator in src/api/validators/user.ts with a zod schema for the same User shape. Keep `validateUser(data: unknown): User` signature identical.

## Scope / files in play
- package.json
- pnpm-lock.yaml
- src/api/validators/user.ts
- tests/api/validators/user.test.ts

## Sandbox tier
network

## Constraints
- zod ^3.22.0 exactly.
- Same signature, same error-shape contract.
- Use .parse() (throw on invalid), not .safeParse().

## Non-goals
- Do not migrate other validators.
- Do not change the User type.

## Acceptance criteria
- zod ^3.22.0 in package.json dependencies.
- validators/user.ts uses zod, same exported function name.
- Existing user.test.ts passes unchanged.

## Self-check (run before reporting)
- pnpm install
- pnpm test tests/api/validators/user.test.ts
- pnpm typecheck

## Report format
[5-section schema, inlined]
EOF
```

---

## 5. New file from spec

```bash
filename=$(openssl rand -hex 4)
codex exec --skip-git-repo-check --dangerously-bypass-approvals-and-sandbox \
  --config tools.web_search=true -C /path/to/repo \
  2>>"/tmp/codex-${filename}.log" <<'EOF'
## Task
Create src/schemas/user.py — Pydantic v2 BaseModel `User`.

Fields: id (UUID4), email (EmailStr), name (str, 1-200 chars), created_at (datetime), is_active (bool, default True), role (Enum: admin/user/viewer, default user).

Methods:
- classmethod from_dict(cls, data: dict) -> User (Pydantic validation)
- to_public_dict(self) -> dict (excludes email)

## Scope / files in play
- src/schemas/user.py (new)
- src/schemas/__init__.py (add User export if pattern exists)
- tests/schemas/test_user.py (new, 4-6 tests)

## Sandbox tier
network

## Constraints
- Pydantic v2 syntax (model_validator, model_dump, not v1 equivalents).
- Match existing style in src/schemas/*.py.
- Full type hints.

## Non-goals
- Do not modify any existing schema file.

## Acceptance criteria
- src/schemas/user.py exists with the specified shape.
- test_user.py has ≥4 tests, all pass.
- mypy clean on the new file.

## Self-check (run before reporting)
- pytest -q tests/schemas/test_user.py
- mypy src/schemas/user.py

## Report format
[5-section schema, inlined]
EOF
```

---

## Properties of every good brief

1. All 8 sections present, in order.
2. Scope is a closed boundary.
3. Acceptance criteria are commands-checkable, not judgment-based.
4. Self-check is exact shell invocations.
5. Non-goals catch scope creep up front.
6. `network` unless you have a reason to downgrade.
7. Report format inlined verbatim (Codex doesn't have access to the persona file).
