# Product-based costing (PBC) — spec

## As-built

| | |
| :--- | :--- |
| Spec | `docs/features/product_based_costing/spec.md` + [00-gaps](00-gaps.md) |
| UI | `product_based_costing/`, `costingFile/` |
| SQL | `public.sql` |
| State | Vue Query — `shared/queryKeys/` in module |
| Model | **Pre-order** — [business-models](../../architecture/business-models.md) |

## Where to look

| Need | Path |
| :--- | :--- |
| Tables | Grep `pbc_`, `product_based_costing` in `public.sql` |
| File details UI | `ProductBasedCostingFileDetailsV2Page` |
| Demand handoff | [procurement spec](../procurement_stock/spec.md) US-4 |

## Scope

| | |
| :--- | :--- |
| Surfaces | `app` |
| In | Costing files, line formulas, backlog, demand handoff |
| Out | `global_stocks` until shipment received; shop cart |

See [scopes](../../architecture/scopes.md).

## Personas

| Role | Actions |
| :--- | :--- |
| Sourcing | Create files, FX, surcharges |
| Account lead | Markup, publish (`offered`), lock (`confirmed`) |
| Procurement | Demand desk, PO, shipment assign |
| Auditor | Formula audit, export |

## Rules

- Landed unit cost (GBP) = web £ + cargo + package weight → FX to BDT. Cost fixed per line; offer mode changes sell only.
- `offer_pricing_mode`: `landed_cost_plus` (default) or `gbp_vat_then_profit` (VAT then profit on web £ only).
- Buy/sell currency on file via `global_currencies` (`buy_currency_*`, `sell_currency_*`).

## Stories

### US-1: Dynamic costing formula
- [x] Modes and FX as above; unlocked lines recalc on save.

### US-2: Shared procurement lifecycle
- Confirmed files → Demand desk with catalog preorders (`procuring` … `delivered`).
  - [ ] Stays `procuring` through PO and inbound.
  - [ ] Packed qty on **Delivery paper**; close take/condition/return — no customer bill at `packed`.

### US-3: Demand backlog
- Shortfalls after `delivered` → `product_based_costing_backlog_items`.
  - [ ] Import backlog into new drafts from drawer.

### US-4: Line items UI
- Table (editable) vs card grid (`localStorage` `pbc-file-items-view`). Card = browse-only catalog-style fields from linked `products`.
