# Global reference, Koba & trash — spec

## As-built

| | |
| :--- | :--- |
| Spec | `docs/features/global_reference/spec.md` + [00-gaps](00-gaps.md) |
| UI | `global_reference/`, `global/`, `tag/`, `koba/` |
| SQL | Mostly `public.sql`; stubs `global_reference/`, `tag/` |
| K-beauty | **Koba** — `koba_*` tables. Not `global_stocks`. |
| Access | `platform` catalogs; `app`/`shop` Koba (`koba_retail` / `koba_wholesale`) |

## Where to look

| Need | Path |
| :--- | :--- |
| Reference tables | Grep `global_currencies`, `markets`, `bd_banks` in `public.sql` |
| Koba | `web/src/modules/koba/`, grep `koba_` in schemas |
| Trash | `trash_entries`, soft-delete RPCs — grep in `public.sql` |
| Submodule grants | `global_reference_*` keys in feature catalog |

## Scope

| | |
| :--- | :--- |
| Surfaces | `platform` catalogs; `app` + `shop` Koba; `app` trash |
| In | Currencies, markets, payment methods, **BD banks**, units; `koba_*`; `trash_entries` |
| Out | `global_stocks`, thrift SKUs, wholesale invoices |

See [scopes](../../architecture/scopes.md).

## Sub-domains

| Area | Job |
| :--- | :--- |
| Global reference | Superadmin maintains; tenants read-only in dropdowns |
| Koba | UK catalog scrape → `koba_products`; retail commission in `koba_retail_settings`; staff + shop carts |
| Trash | Soft delete → `trash_entries`; restore/purge at `/:slug/app/trash` |

**Governance:** Trash list indexes `trash_entries` only. No soft-delete for posted invoices / active shipments. Tenant RLS on all tenant ops.

## Personas

| Persona | Scope | Actions |
| :--- | :--- | :--- |
| Platform superadmin | `/platform/*` | Currencies, markets, payment methods, BD banks, UoM |
| Tenant admin | `/app/*` | Koba settings, trash restore |
| Staff | `/app/*` | Koba catalog/cart, read references |
| Shop customer | `/shop/*` | Koba retail cart/orders |

## Stories (Koba & trash — high level)

- UK scrape pipeline → `koba_products`; orders compute commission per settings.
- Customer phone CRM: delivery history, spend, addresses.
- Soft delete writes `deleted_at` + `trash_entries` pointer; restore clears both.
