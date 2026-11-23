# How we write docs (copy this)

Goal: a human finds the fact in **one screen**. An agent loads **as few tokens as possible**.

## Tree

```text
docs/README.md                 # Index. Agent loads this first when product work.
docs/STRUCTURE.md              # This file.
docs/architecture/             # scopes, business-models, database, state, …
docs/guides/
  ui-standards.md              # dense tables / token detail (grep; chrome uses quasar-ui)
  OpsListPage.skeleton.vue     # ops list chrome for agents
  cloudflare-pages-deploy.md
docs/product-scenarios/        # only when user asks
docs/features/<name>/
  spec.md                      # As-built, Scope, Where to look, stories
docs/features/template/        # Copy for a new module
doc/supabase-schema.md         # Split tracker only
doc/fix/                       # Dated one-off notes — not product truth
```

Do **not** add `doc/<module>/*.md`. Do **not** duplicate topics across architecture files. Do **not** add `spec.md`.

## Agent load budget

| Step | Load | Do not load |
| :--- | :--- | :--- |
| 1 | `docs/README.md` | Every module; `operating_manual/`; `product-scenarios/` unless asked |
| 2 | That module’s `spec.md` | Other modules |
| 3 | `scopes.md` / `business-models.md` if “where / how they sell” | `doc/brand-theme.md` |
| 4 | Grep `supabase/schemas/` + `web/src/modules/<name>/` | Bulk `supabase/migrations/` |
| 5 | Files you will **edit** | |

Live SQL = `supabase/schemas/`. Live UI = `web/src/modules/<name>/`. Never full-read `database.types.ts` or `public.sql`.

Unclear product fact → ask one question. Do not invent statuses/RPCs.

## Rules for a new markdown file

1. One job. Title is the job.
2. Tables over prose. Relative links only.
3. Feature doc: **As-built**, then **Scope**, then stories.
4. Do not paste full SQL that lives in `schemas/`.
5. Cap: architecture/guide ≤80 lines; `spec.md` ≤180 when possible.

## New module

1. Copy `docs/features/template/` → `docs/features/<snake_name>/`.
2. Fill `spec.md` only.
3. Add a row to `docs/README.md` module map.
4. Code follows `spec.md` + `web/src/modules/<snake_name>/`.
