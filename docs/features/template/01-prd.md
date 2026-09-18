# [Feature] — PRD

> Status: Draft | In review | Approved

## As-built

| | |
| :--- | :--- |
| Spec | `docs/features/<name>/` |
| UI | `web/src/modules/<name>/` |
| SQL | `supabase/schemas/<domain>/` or `public.sql` |
| Model | BW / pre-order / K-beauty / thrift — [business-models](../../architecture/business-models.md) |
| State | Pinia **or** Vue Query — match this folder |
| Access | scope + `effectiveGrants` |

## Scope

| | |
| :--- | :--- |
| Surfaces | `platform` / `app` / `shop` / `investor` — only those that apply |
| In | What this pack owns |
| Out | What other packs own; do not build here |

See [scopes](../../architecture/scopes.md).

## What / who

One short paragraph. Table of roles and what they may do.

## Rules (only what is not in `docs/README.md`)

- …

## Stories

- As a … I want … so that …
  - [ ] AC
