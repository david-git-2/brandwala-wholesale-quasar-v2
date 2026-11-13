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
  cloudflare-pages-deploy.md   # frontend:prod, Wrangler token + account id
docs/product-scenarios/        # Product-decision catalogs (not staff SOP)
  README.md                    # Index + read order + scenario template
  roles.md                     # System roles (Who names for catalogs)
  money-flow-guide.md          # Money scenarios
  investor-shipment-guide.md   # Investor capital + profit share
  shipment-guide.md            # Goods / warehouse / trips
  shop-and-orders-guide.md     # Three storefront types
  courier-dispatch-guide.md    # Last-mile + COD risk
  money-flow-pnl-product-review.md  # Must/Should/Defer/Out board
docs/features/<name>/
  00-gaps.md
  spec.md                      # As-built, Scope, Where to look, stories
docs/features/money/spec.md    # Cash accounts, lots, pays (single doc)
docs/features/bills/             # Obligation paper — spec.md (+ 00-gaps, backfill SQL)
docs/features/money_bill_bridge/ # spec.md (+ 00-gaps; 00-atlas redirect)
docs/features/bills_pays/     # Desk redirect + tests.md; money-spine-v2/ redirects only
docs/features/template/        # Copy for a new module.
doc/supabase-schema.md         # Split tracker only.
doc/fix/                       # Dated one-off fix notes. Not product truth.
```

Do **not** add `doc/<module>/*.md`. Do **not** add `docs/architecture/*` copies of the same topic.

## Agent load budget (hard)

| Step | Load | Do not load |
| :--- | :--- | :--- |
| 1 | `docs/README.md` | Every module at once; **`web/src/modules/operating_manual/`** unless user asked for staff SOP; **`docs/product-scenarios/`** unless user asked for product scenarios / what-to-build coverage |
| 2 | That module’s `spec.md` + `00-gaps.md` | Other modules |
| 3 | `scopes.md` / `business-models.md` if the task is “where / how they sell” | `doc/brand-theme.md` |
| 4 | Grep `supabase/schemas/` + `web/src/modules/<name>/` for tables, RPCs, wiring | `supabase/migrations/` |
| 5 | Files you will **edit** | |

Live SQL = `supabase/schemas/`. Live UI = `web/src/modules/<name>/`. Specs do not replace those. Never full-read `database.types.ts` or `public.sql` — grep one symbol, then targeted read.

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
