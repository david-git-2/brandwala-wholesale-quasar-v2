# [Feature] — spec

## As-built

| | |
| :--- | :--- |
| Spec | `docs/features/<name>/spec.md` + [00-gaps](00-gaps.md) |
| UI | `web/src/modules/<name>/` |
| SQL | `supabase/schemas/<domain>/` or `public.sql` |
| Model | BW / pre-order / K-beauty / thrift — [business-models](../../architecture/business-models.md) |
| State | Pinia **or** Vue Query — match this folder |
| Access | scope + `effectiveGrants` |

## Where to look

| Need | Path |
| :--- | :--- |
| Tables, RPCs, RLS | `supabase/schemas/<domain>/` or grep `public.sql` |
| Pages / components | `web/src/modules/<name>/` |
| Wiring | Grep module folder for RPC names and query keys |

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

### US-1 …
- …
  - [ ] AC
