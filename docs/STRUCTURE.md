# How we write docs

Agents: **do not load docs by default** — code + `supabase/schemas/` are truth. Humans use this tree when needed.

## Tree

```text
docs/README.md                 # Human index (optional for agents)
docs/STRUCTURE.md              # This file
docs/architecture/             # scopes, business-models, database, state, …
docs/guides/
  OpsListPage.skeleton.vue     # ops list chrome for agents
  cloudflare-pages-deploy.md
docs/features/<name>/spec.md   # optional as-built notes
docs/features/template/        # Copy for a new module
```

Do not add `00-gaps.md`, product-scenario catalogs, or duplicate UI guides (`quasar-ui.mdc` is UI law).

## New markdown

1. One job. Tables over prose.
2. Feature doc: As-built → Scope → stories. Cap ~180 lines.
3. Do not paste SQL that lives in `schemas/`.
4. Add a row to `docs/README.md` only if humans need the index.

## New module

1. Copy `docs/features/template/` → `docs/features/<snake_name>/`.
2. Fill `spec.md` (optional for agents; useful for humans).
3. Code under `web/src/modules/<snake_name>/`.
