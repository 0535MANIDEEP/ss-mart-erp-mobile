# AGENTS.md — Agent Rules for the Entire Project (Vibe Coding)

## 1) Mission

Deliver correct, working software for this repo by following a strict engineering process: spec → docs/constraints → small chunks → tests → review → safe commits → isolation for experiments → repeat until the project is complete.

## 2) Non-negotiables (never break)

- **No guessing:** never invent file names, APIs, types, schema names, command names, or behaviors. If something is missing, ask only for the minimal required info (paths/content).
- **Spec-first:** no coding before you define the goal, inputs/outputs, acceptance criteria, constraints, and error cases.
- **Chunking:** do work only in small iterative increments. Each chunk must be testable.
- **Tests required:** every chunk must include or update tests. A chunk is not "done" until the relevant tests pass.
- **Constraints-first:** changes must be driven by requirements and constraints; avoid unrelated refactors.
- **Never commit code you can't explain:** before committing, you must clearly state what changed, why, and which tests prove it.
- **Isolation for experiments:** risky work happens in branches/worktrees; merge only after gates pass.
- **Windows stability (if applicable in this repo):** do not break already-working Windows offline-first behavior or build success.

## 3) Multi-agent mode (always)

Use sub-agents every chunk to speed up while maintaining quality. Roles:

- **Architect:** validates design, layering, boundaries, and spec compliance.
- **Implementer:** writes the code for the chunk with minimal diffs.
- **Tester:** writes/updates tests and tries to break edge cases.
- **Reviewer:** audits correctness, readability, error handling, maintainability.
- **Security/Robustness:** checks failure behavior, validation, unsafe assumptions.
- **Docs/UX:** ensures usage/config/error messages and any required docs are updated.

If outputs conflict, Spec wins, then Reviewer audit wins.

## 4) Chunk execution loop (always in order)

For each chunk:

1. **Chunk plan + Spec**
   - Restate goal
   - Inputs/outputs
   - Data flow (where read/write happens)
   - Error cases
   - Acceptance criteria (measurable)
   - Constraints (platforms, dependencies, architecture rules)
2. **Docs/Repo verification**
   - Use the repo's markdown knowledge files as source of truth
   - Locate exact file paths/APIs/types referenced in the plan
3. **Plan**
   - Exact files to edit
   - Exact changes required (schema/DAO/migrations/datasources/DI/repo/UI as relevant)
   - Tests to add/update
4. **Implement**
   - Minimal scoped diffs
   - Add/adjust validation and error handling where needed
   - Ensure migrations/upgrade paths are safe when DB schema is involved
5. **Verify**
   - Run: `flutter analyze` (or repo's equivalent)
   - Run: smallest relevant unit/integration tests subset
   - Run: platform smoke build only when needed for confidence/gates
6. **Reviewer audit checklist**
   - Correctness vs spec
   - Edge cases
   - Migration safety (if applicable)
   - Maintainability (no duplicated logic, consistent naming)
   - Robustness/security checks (sanitization, bounds, file path safety, serialization hazards)
7. **Commit proposal**
   - Commit message text
   - Summary of changes
   - Tests proving the change

## 5) Todo list & "project ends" policy

Maintain a single authoritative checklist until the project is finished:

- Each item is a chunk with:
  - `status`: Not started / In progress / Ready for review / Done
  - acceptance criteria
  - tests required
- A chunk becomes **Done** only when:
  - all required tests pass, **and**
  - reviewer audit checklist is satisfied.

## 6) Output format (must match every time)

Every response must include:

- **Chunk plan:** Chunk X, Chunk Y, Chunk Z
- **Chunk N details:**
  - Spec
  - Files to edit
  - Exact code changes (diff-style or file-by-file instructions)
  - Tests to add/update
  - Commands to run
  - Merge gate checklist
- **Next required repo info:** ask only for missing items, limited to the minimal paths/content needed to proceed.

No extra sections beyond this template.

## 7) When blocked / missing information

Ask only for:
- exact file paths
- exact relevant snippets/sections
- the minimum markdown knowledge content needed to proceed

Do not ask the user to "choose" among interpretations. Commit to the most reasonable approach consistent with the docs/markdown and spec.

## 8) Speed rules (allowed optimizations only)

Speed is achieved only by:
- parallelizing sub-agent tasks (docs extraction vs test prep vs review checklist)
- keeping diffs small and scoped
- using branches/worktrees for isolated experiments

Never speed by skipping spec, tests, or review gates.

## 9) Version control rules

- Commit per chunk/milestone.
- Use descriptive commit messages tied to the spec chunk.
- Do not create "mega commits" bundling unrelated changes.
- Prefer reverts or targeted follow-up patches over risky merges.

## 10) Default target behavior (repo-wide)

1. Build correctness first: compilation success.
2. Then behavior correctness: tests passing.
3. Then reliability: reviewer/robustness audit.
4. Then polish: docs/UX updates only when required by the chunk spec.
