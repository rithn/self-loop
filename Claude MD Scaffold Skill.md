# Claude MD Scaffold Skill — Design

## Overview

Recursively writes `CLAUDE.md` files across a project directory tree in **depth-first (DFS) order** — leaf directories first, then their parents, up to the root. Each `CLAUDE.md` documents exactly what is in its own folder. Parent files reference their children with `@child/CLAUDE.md` instead of duplicating content.

The result is a self-contained, maintainable documentation layer that Claude Code can read to quickly orient itself in any subdirectory without needing to explore the whole tree.

---

## Core Principle

**Each `CLAUDE.md` owns only what is in its own directory.** Children are referenced, not summarised. This avoids drift: when a child changes, only that child's `CLAUDE.md` needs updating.

```
root/CLAUDE.md          ← overview + @app/CLAUDE.md + @tests/CLAUDE.md + ...
app/CLAUDE.md           ← app-level files + @routes/CLAUDE.md + @services/CLAUDE.md
app/routes/CLAUDE.md    ← detailed content about route files (leaf)
app/services/CLAUDE.md  ← detailed content about service files (leaf)
tests/CLAUDE.md         ← test runner info + @unit/CLAUDE.md + @integration/CLAUDE.md
...
```

---

## What to Document (per directory)

### Leaf directories
- What each file does (function signatures, what it returns, key behaviours)
- Any patterns, conventions, or gotchas specific to this folder
- External dependencies (AWS, DB, etc.) if relevant

### Intermediate directories
- What the directory is for (1–2 sentences)
- Any files that live directly in this dir (not in subdirs)
- References to child CLAUDE.md files: `@subdir/CLAUDE.md`

### Root directory
- Project name + one-paragraph description (what it does, who it's for)
- Stack (language, framework, DB, external services)
- How to run the app
- How to run tests
- Key env vars (names only — not values)
- References to all direct child CLAUDE.md files

---

## Directories to Skip

Do not write `CLAUDE.md` in:
- `node_modules/`, `.git/`, `__pycache__/`, `.venv/`, `venv/`, `dist/`, `build/`
- Directories containing only generated/compiled output with no authoring value
- `uploads/` or similar runtime data directories with no fixed structure
- Any directory explicitly listed in `.gitignore` as generated

Do write `CLAUDE.md` in directories that contain source code, tests, configuration, documentation, scripts, or assets that a developer would read or edit.

---

## Child Reference Format

Use the `@path` syntax Claude Code recognises:

```markdown
## Subdirectories
- @routes/CLAUDE.md
- @services/CLAUDE.md
```

Paths are relative to the parent `CLAUDE.md`'s location. Do not use absolute paths.

---

## Execution Order (DFS)

Process directories in post-order (children before parents):

1. Recursively find all directories (skip the exclude list above)
2. Sort by depth descending — deepest directories first
3. Within the same depth, process in alphabetical order
4. Write leaf `CLAUDE.md` files first
5. When writing a parent, check which direct children have `CLAUDE.md` files and reference them

This means by the time a parent `CLAUDE.md` is written, all child `CLAUDE.md` files already exist and can be referenced.

---

## Reading Strategy (per directory)

Before writing a directory's `CLAUDE.md`, read:
- All files directly in that directory (not subdirectories)
- For code files: functions, classes, key logic
- For config files: what they configure
- For log/data files: skip reading them; just note they are generated

Prioritise reading in this order:
1. Entry points / main files (main.py, index.ts, app.go, etc.)
2. API / route definitions
3. Data models
4. Service / business logic
5. Configuration files
6. Everything else

Do not read binary files, images, or files > 500 lines unless they are the primary source of information for that directory.

---

## Content Quality Rules

- **Specific over generic.** Name the actual functions and their signatures. Don't write "handles authentication" — write "`authenticate_user(token) -> User | None` — validates JWT, returns user or raises 401".
- **No duplication.** If a child's `CLAUDE.md` covers a topic, the parent does not repeat it — just references it.
- **No boilerplate.** Skip headers like "This directory contains..." — just say what's in it.
- **Gotchas and non-obvious things** are the most valuable content. Document things that would take a developer time to discover from reading the code.
- **Keep it short.** A leaf CLAUDE.md should fit in a terminal window. A root CLAUDE.md can be longer but should stay scannable.

---

## Update vs Overwrite

If a `CLAUDE.md` already exists in a directory:
- Read the existing file first
- Preserve any manually written notes or sections that are still accurate
- Update sections that are outdated or missing
- Do not delete content without reason

If the user says `--overwrite` or equivalent: write fresh, ignore existing content.

---

## Decisions

| Decision | Choice |
|---|---|
| Processing order | DFS post-order (leaves first, root last) |
| Child reference format | `@child/CLAUDE.md` relative path |
| Parent content | Overview + own files + child references only |
| Skipped directories | node_modules, .git, __pycache__, venv, dist, uploads, gitignored generated dirs |
| Existing CLAUDE.md | Preserve + update (not overwrite by default) |
| Binary/large files | Skip reading; note existence only |
| Root CLAUDE.md | Stack, run commands, env vars, child references |
