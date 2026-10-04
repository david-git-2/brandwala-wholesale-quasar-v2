# How we write docs (copy this)

Goal: a human finds the fact in **one screen**. An agent loads **as few tokens as possible**. New files follow this file.

## Tree

```text
docs/README.md                 # Index. Agent loads this first. Always.
docs/STRUCTURE.md              # This file. How to add docs.
docs/architecture/
  business-models.md
  scopes.md                    # Login surfaces + feature × scope
  database.md
  state.md
docs/guides/
  ui-standards.md
docs/features/<name>/
  00-gaps.md
  spec.md                      # As-built, Scope, Where to look, stories
docs/features/bills_pays/     # Extra: money-story.md (worked numbers)
docs/features/template/        # Copy for a new module.
doc/supabase-schema.md         # Split tracker only.
doc/fix/                       # Dated one-off fix notes. Not product truth.
```

Do **not** add `doc/<module>/*.md`. Do **not** add `docs/architecture/*` copies of the same topic.

## Agent load budget (hard)

| Step | Load | Do not load |
| :--- | :--- | :--- |
| 1 | `docs/README.md` | Every module at once |
| 2 | That module’s `spec.md` + `00-gaps.md` | Other modules |
| 3 | `scopes.md` / `business-models.md` if the task is “where / how they sell” | `doc/brand-theme.md` |
| 4 | Grep `supabase/schemas/` + `web/src/modules/<name>/` for tables, RPCs, wiring | `supabase/migrations/` |
| 5 | Files you will **edit** | |

Live SQL = `supabase/schemas/`. Live UI = `web/src/modules/<name>/`. Specs do not replace those.

## DOC_GAP

If a needed product fact is missing: stop. No code. See `.cursor/rules/docs-first.mdc`. Human edits the **one** named file, then continue.

## Rules for a new markdown file

1. One job. Title is the job.
2. Tables over prose. No `file://` links. Relative links only.
3. First block on a feature doc is **As-built**, then **Scope (in/out / surfaces)**.
4. Do not paste `CREATE TABLE` / full RPC bodies that already live in `schemas/`. Link the path.
5. Do not repeat locked rules from `docs/README.md`.
6. Cap: architecture/guide ≤80 lines; `spec.md` ≤120 lines when possible (complex domains may exceed). If longer, you are duplicating code.
7. Emoji, mermaid, and “executive summary” padding are optional. Prefer none.

## New module

1. Copy `docs/features/template/` → `docs/features/<snake_name>/`.
2. Fill `spec.md` and `00-gaps.md`.
3. Add a row to `docs/README.md` module map.
4. Code follows `spec.md` + existing files in `web/src/modules/<snake_name>/`.

**Example pack:** [procurement_stock/spec.md](features/procurement_stock/spec.md).
