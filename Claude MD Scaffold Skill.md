# Claude MD Scaffold Skill (`/code-claude-md`)

> Type `/code-claude-md [project path]` to recursively write `CLAUDE.md` files across a project tree — leaf directories first, parents last — so Claude Code can orient itself in any directory without reading the whole codebase.

---

## What it does

Scans a project directory tree and writes a `CLAUDE.md` in every relevant directory, processing in **depth-first (DFS) post-order** — leaf directories first, then their parents, root last. Each file documents exactly what is in its own folder. Parent files reference children with the `@child/CLAUDE.md` syntax rather than duplicating content.

The result is a self-contained, maintainable documentation layer. When a subdirectory changes, only that subdirectory's `CLAUDE.md` needs updating.

---

## Core principle

**Each `CLAUDE.md` owns only its own directory.** Children are referenced, not summarised.

```
root/CLAUDE.md          ← overview + @app/CLAUDE.md + @tests/CLAUDE.md
app/CLAUDE.md           ← app-level files + @routes/CLAUDE.md + @services/CLAUDE.md
app/routes/CLAUDE.md    ← detailed content about route files (leaf)
app/services/CLAUDE.md  ← detailed content about service files (leaf)
```

---

## Step 1 — Locate the project

Asks for the project directory path, or uses the path argument if provided directly.

---

## Step 2 — Scan and plan

Scans the full directory tree and lists directories to document, sorted deepest to shallowest. Asks the user to confirm or adjust before writing anything.

**Directories skipped:**
- `node_modules/`, `.git/`, `__pycache__/`, `.venv/`, `venv/`, `dist/`, `build/`
- Runtime data directories (`uploads/`, `tmp/`, `cache/`) with no fixed source structure
- Any directory listed in `.gitignore` as generated output

---

## Step 3 — Write leaf `CLAUDE.md` files

For each leaf directory (no subdirectories getting their own `CLAUDE.md`):
1. Reads all files in the directory
2. Documents: what each file does (function signatures, return values, key behaviours), patterns or conventions specific to this folder, external dependencies (APIs, DBs, env vars), non-obvious gotchas

Files are read in priority order: entry points → route definitions → data models → service/business logic → configuration → everything else. Binary files and files over 500 lines are skipped unless they are the primary source of information.

---

## Step 4 — Write intermediate `CLAUDE.md` files

For each intermediate directory (has at least one child with a `CLAUDE.md`), deepest first:
1. Reads only files directly in this directory (not recursing into subdirs)
2. Documents: what the directory is for (1–2 sentences), any files that live directly here, references to child directories:
   ```
   ## Subdirectories
   - @child-dir/CLAUDE.md
   ```

No content from child `CLAUDE.md` files is repeated.

---

## Step 5 — Write root `CLAUDE.md`

Written last. Must include:
1. Project name and description — what it does, who it's for, key context
2. Stack — language, framework, DB, external services
3. How to run — exact command(s)
4. How to run tests — exact command(s)
5. Key env vars — names and one-line descriptions (no values)
6. Subdirectories — references to all direct children with `CLAUDE.md` files

---

## Step 6 — Handle existing `CLAUDE.md` files

If a `CLAUDE.md` already exists:
- Reads it first
- Preserves manually written notes that are still accurate
- Updates outdated or missing sections
- Does not delete content without a clear reason

Pass `--overwrite` to skip this check and write fresh.

---

## Step 7 — Summary

```
## CLAUDE.md Scaffold Complete

Directories documented: N
Files written:          N
Files updated:          N
Files skipped:          N (already accurate)

Tree:
  CLAUDE.md
  app/
    CLAUDE.md
    routes/CLAUDE.md
    services/CLAUDE.md
  ...
```

---

## Content quality rules

- **Specific over generic** — name actual functions with signatures. "handles authentication" is wrong; "`authenticate_user(token) -> User | None` — validates JWT, returns user or raises 401" is right.
- **No duplication** — if a child covers a topic, the parent references it, not repeats it
- **No boilerplate** — skip openers like "This directory contains..." and just describe the contents
- **Gotchas first** — non-obvious things that would waste a developer time are the most valuable content
- **Keep it short** — a leaf `CLAUDE.md` should fit in a terminal window

---

## Child reference format

Uses the `@path` syntax that Claude Code's context loading recognises:

```markdown
## Subdirectories
- @routes/CLAUDE.md
- @services/CLAUDE.md
```

Paths are relative to the parent `CLAUDE.md`'s location.
